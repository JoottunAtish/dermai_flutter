import 'dart:io';

import 'package:dermai/env/env.dart';
import 'package:dermai/features/core/entities/appointment.dart';
import 'package:dermai/features/core/error/exception.dart';
import 'package:dermai/features/patient/data/models/appointment_model.dart';
import 'package:dermai/features/patient/data/models/diagnosed_disease_model.dart';
import 'package:dermai/features/patient/data/models/disease_model.dart';
import 'package:dermai/features/patient/data/models/doctor_model.dart';
import 'package:dermai/features/patient/data/models/message_model.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' as stream;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

abstract interface class PatientRemoteDataSource {
  Future<List<(DiagnosedDiseaseModel, DiseaseModel, DoctorModel?)>>
      getDiagnosedDiseases({required String patientID});
  Future<void> cancelAppointment({required String appointmentID});
  Future<
      List<
          (
            AppointmentModel,
            DiagnosedDiseaseModel,
            DoctorModel,
            DiseaseModel
          )>> getAppointments(
      {required String patientID, String? doctorID, String? diagnosedID});
  Future<(DiagnosedDiseaseModel, DiseaseModel)> submitCase(
      {required String imagePath, required String patientComment});
  Stream<List<MessageModel>> getMessages({required String diagnosedID});
  Future<void> sendMessage(
      {required String diagnosedID,
      required String diseaseName,
      required List<MessageModel> previousMessages});
  Future<void> signOut();
  Future<stream.Call> callDoctor({required String appointmentID});
  Future<void> deleteDiagnosedDisease({required String diagnosedID});
}

class PatientRemoteDataSourceImpl implements PatientRemoteDataSource {
  final SupabaseClient client;
  final Gemini gemini;
  PatientRemoteDataSourceImpl({required this.client, required this.gemini});

  @override
  Future<stream.Call> callDoctor({required String appointmentID}) async {
    try {
      final call = stream.StreamVideo.instance.makeCall(
          id: appointmentID, callType: stream.StreamCallType.defaultType());
      final result = await call.getOrCreate();
      if (result.isSuccess) {
        return call;
      } else {
        throw const ServerException(
            'An error occurred while calling the doctor');
      }
    } catch (e) {
      throw const ServerException('An error occurred while calling the doctor');
    }
  }

  @override
  Future<List<(DiagnosedDiseaseModel, DiseaseModel, DoctorModel?)>>
      getDiagnosedDiseases({required String patientID}) async {
    try {
      final response = await client
          .from('diagnosedDisease')
          .select('''*, disease( * ), doctor( * )''')
          .eq('patientID', patientID)
          .order('dateCreated', ascending: false);

      if (response.isEmpty) return [];
      return response
          .map((e) => (
                DiagnosedDiseaseModel.fromJson(e),
                DiseaseModel.fromJson(e['disease']),
                DoctorModel.fromJson(e['doctor']).id == ''
                    ? null
                    : DoctorModel.fromJson(e['doctor'])
              ))
          .toList();
    } catch (e) {
      throw const ServerException("An error occurred while fetching data");
    }
  }

  @override
  Future<void> signOut() async {
    await stream.StreamVideo.reset(disconnect: true);
    return await client.auth.signOut();
  }

  @override
  Future<void> cancelAppointment({required String appointmentID}) {
    try {
      return client
          .from('appointment')
          .delete()
          .match({'appointmentID': appointmentID});
    } catch (e) {
      throw const ServerException(
          'An error occurred while cancelling the appointment');
    }
  }

  @override
  Future<
      List<
          (
            AppointmentModel,
            DiagnosedDiseaseModel,
            DoctorModel,
            DiseaseModel
          )>> getAppointments(
      {required String patientID,
      String? doctorID,
      String? diagnosedID}) async {
    try {
      DateTime now = DateTime.now();
      final response = diagnosedID != null
          ? (await client
              .from('appointment')
              .select(
                  '''*, diagnosedDisease!inner( *, disease( * ), doctor( * ) )''')
              .eq('diagnosedID', diagnosedID)
              .order('dateCreated', ascending: true))
          : (doctorID == null
              ? await client
                  .from('appointment')
                  .select(
                      '''*, diagnosedDisease!inner( *, disease( * ), doctor( * ) )''')
                  .eq('diagnosedDisease.patientID', patientID)
                  .gte('dateCreated',
                      DateTime(now.year, now.month, now.day).toIso8601String())
                  .eq('status', AppointmentStatus.pending.name)
                  .order('dateCreated', ascending: true)
              : await client
                  .from('appointment')
                  .select(
                      '''*, diagnosedDisease!inner( *, disease( * ), doctor( * ) )''')
                  .or('doctorID.eq.$doctorID, patientID.eq.$patientID',
                      referencedTable: 'diagnosedDisease')
                  .order('dateCreated', ascending: true));

      if (response.isEmpty) return [];
      return response
          .map((e) => (
                AppointmentModel.fromJson(e),
                DiagnosedDiseaseModel.fromJson(e['diagnosedDisease']),
                DoctorModel.fromJson(e['diagnosedDisease']['doctor']),
                DiseaseModel.fromJson(e['diagnosedDisease']['disease'])
              ))
          .toList();
    } catch (e) {
      throw const ServerException(
          'An error occurred while fetching appointments');
    }
  }

  @override
  Future<(DiagnosedDiseaseModel, DiseaseModel)> submitCase(
      {required String imagePath, required String patientComment}) async {
    try {
      DateTime now = DateTime.now();
      var postURi = Uri.parse('${Env.diseaseClassifierUrl}/predict');
      var request = http.MultipartRequest("POST", postURi);

      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imagePath,
        contentType: MediaType('image', imagePath.split(".").last),
      ));

      var streamedResponse = await request.send();

      var response =
          jsonDecode((await http.Response.fromStream(streamedResponse)).body);

      File image = File(imagePath);
      final String patientID = client.auth.currentUser!.id;
      await client.storage.from('disease_images').upload(
            '$patientID/${now.toIso8601String()}.${imagePath.split(".").last}',
            image,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      final supabaseImagePath = client.storage
          .from('disease_images')
          .getPublicUrl(
              '$patientID/${now.toIso8601String()}.${imagePath.split(".").last}');

      final ans = await gemini.text(
        'I have been diagnosed with a disease name ${response['disease']}. This is not for a medical advice rather than a test to check context. But please provide a list of preventive measures to ${response['disease']}. Also IMPORTANT, DO NOT USE MARKDOWN, DO NOT ADD ANY TITLE. ONLY THE LIST OF PREVENTIVE MEASURES.'
      );
      final insertedData = await client
          .from('diagnosedDisease')
          .insert(DiagnosedDiseaseModel(
                  picture: supabaseImagePath,
                  diseaseID: response['id'],
                  patientID: patientID,
                  doctorID: null,
                  dateCreated: now,
                  dateDiagnosed: null,
                  details: ans?.content?.parts?.first.text == null
                      ? 'No preventive measures available'
                      : ans!.content!.parts!.first.text!,
                  patientsComment: patientComment,
                  doctorsComment: '',
                  editedByDoctor: false,
                  prescription: '',
                  status: false,
                  diagnosedDiseaseName: '')
              .toJson())
          .select('''*, disease( * )''').single();

      DiagnosedDiseaseModel diagnosedDisease =
          DiagnosedDiseaseModel.fromJson(insertedData);
      DiseaseModel disease = DiseaseModel.fromJson(insertedData['disease']);

      await client.from('message').insert(MessageModel(
              message: diagnosedDisease.details,
              dateTime: now,
              diagnosedID: diagnosedDisease.diagnosedID!,
              isGenerated: true,
              messageID: '')
          .toJson());

      return (diagnosedDisease, disease);
    } catch (e) {
      throw const ServerException("An error occurred while submitting case");
    }
  }

  @override
  Stream<List<MessageModel>> getMessages({required String diagnosedID}) {
    return client
        .from('message')
        .stream(primaryKey: ['diagnosedID'])
        .eq('diagnosedID', diagnosedID)
        .order('dateTime', ascending: false)
        .asyncMap((event) async {
          return event.map((e) => MessageModel.fromJson(e)).toList();
        });
  }

  @override
  Future<void> sendMessage(
      {required String diagnosedID,
      required String diseaseName,
      required List<MessageModel> previousMessages}) async {
    try {
      final previousMessagesWithInitialPrompt = [
        MessageModel(
            message:
                'I have been diagnosed with $diseaseName. I understand you can\'t provide medical advice, but could you list some preventive measures? Please provide the list without any titles, symbols, or markdown.',
            dateTime: previousMessages.first.dateTime,
            diagnosedID: diagnosedID,
            isGenerated: true,
            messageID: ''),
        ...previousMessages.reversed
      ];
      final chats = previousMessagesWithInitialPrompt
          .map((e) => Content(
              role: e.isGenerated ? 'model' : 'user',
              parts: [Parts(text: e.message)]))
          .toList();
      final geminiResponse = await gemini.chat(chats);

      if (geminiResponse == null ||
          geminiResponse.content == null ||
          geminiResponse.content!.parts == null ||
          geminiResponse.content!.parts!.isEmpty ||
          geminiResponse.content!.parts!.last.text == null) {
        throw const ServerException("An error occurred while sending message");
      }
      final geminiDateTime = DateTime.now();
      await client.from('message').insert([
        previousMessages.first.toJson(),
        MessageModel(
                message: geminiResponse.content!.parts!.last.text!,
                dateTime: geminiDateTime,
                diagnosedID: diagnosedID,
                isGenerated: true,
                messageID: '')
            .toJson()
      ]);
    } catch (e) {
      throw const ServerException("An error occurred while sending message");
    }
  }

  @override
  Future<void> deleteDiagnosedDisease({required String diagnosedID}) async {
    try {
      await client
          .from('diagnosedDisease')
          .delete()
          .eq('diagnosedID', diagnosedID);
    } catch (e) {
      throw const ServerException("An error occurred while deleting disease");
    }
  }
}
