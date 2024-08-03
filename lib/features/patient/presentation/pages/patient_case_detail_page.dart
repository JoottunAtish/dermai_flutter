import 'package:dermai/features/core/cubits/app_user/app_user_cubit.dart';
import 'package:dermai/features/core/entities/diagnosed_disease.dart';
import 'package:dermai/features/core/entities/disease.dart';
import 'package:dermai/features/core/entities/doctor.dart';
import 'package:dermai/features/core/entities/patient.dart';
import 'package:dermai/features/core/presentation/picture_page.dart';
import 'package:dermai/features/patient/presentation/bloc/patient_bloc.dart';
import 'package:dermai/features/patient/presentation/pages/appointment_history.dart';
import 'package:dermai/features/patient/presentation/pages/chat_page.dart';
import 'package:dermai/features/patient/presentation/pages/temp_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:intl/intl.dart';

class PatientCaseDetailPage extends StatefulWidget {
  final DiagnosedDisease diagnosedDisease;
  final Disease disease;
  final Doctor? doctor;
  const PatientCaseDetailPage(
      {super.key,
      required this.diagnosedDisease,
      required this.disease,
      this.doctor});

  @override
  State<PatientCaseDetailPage> createState() => _PatientCaseDetailPageState();
}

class _PatientCaseDetailPageState extends State<PatientCaseDetailPage> {
  late DiagnosedDisease diagnosedDisease;
  late Disease disease;
  late Doctor? doctor;
  late Patient patient;

  @override
  void initState() {
    patient = (context.read<AppUserCubit>().state as AppUserAuthenticated)
        .user
        .patient();
    diagnosedDisease = widget.diagnosedDisease;
    disease = widget.disease;
    doctor = widget.doctor;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Navigator.push(
            //     context,
            //     MaterialPageRoute(
            //         builder: (context) => const ChatPagePatient()));

            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TempChatPage(diagnosedID: diagnosedDisease.diagnosedID!, diseaseName: diagnosedDisease.diagnosedDiseaseName.isEmpty ? disease.name : diagnosedDisease.diagnosedDiseaseName, initialMessage: diagnosedDisease.details),
                ));
          },
          child: const Icon(Icons.chat),
        ),
        body: SafeArea(
          child: NestedScrollView(
            scrollDirection: Axis.vertical,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
                title: const Text('Case Detail'),
              ),
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PicturePage(
                                  picture: diagnosedDisease.picture,
                                )));
                  },
                  child: FadeInImage.memoryNetwork(
                    placeholder: kTransparentImage,
                    image: diagnosedDisease.picture,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SliverPinnedHeader(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const TabBar(
                    tabs: <Widget>[
                      Tab(text: 'Details'),
                      Tab(text: 'Comments'),
                      Tab(text: 'Prescription'),
                    ],
                  ),
                ),
              )
            ],
            body: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DetailsSection(
                    diagnosedDisease: diagnosedDisease,
                    disease: disease,
                    doctor: doctor,
                    patient: patient,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: CommentSection(diagnosedDisease: diagnosedDisease),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child:
                      PrescriptionSection(diagnosedDisease: diagnosedDisease),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DetailsSection extends StatelessWidget {
  const DetailsSection(
      {super.key,
      required this.diagnosedDisease,
      required this.doctor,
      required this.disease,
      required this.patient});

  final DiagnosedDisease diagnosedDisease;
  final Doctor? doctor;
  final Disease disease;
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  doctor == null ? 'AI Diagnosis' : doctor!.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  diagnosedDisease.editedByDoctor
                      ? 'Patient is diagnosed with ${diagnosedDisease.diagnosedDiseaseName.toLowerCase()}.'
                      : 'AI Analysis classified the disease as ${disease.name.toLowerCase()}.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (doctor == null)
                  Text("No doctor has been assigned to this case yet.",
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Text(
                  DateFormat.yMMMMEEEEd().format(diagnosedDisease.dateCreated),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  diagnosedDisease.editedByDoctor
                      ? 'Preventive Measures'
                      : 'AI Preventive Measures',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(diagnosedDisease.details.isEmpty
                    ? 'No preventive measures given'
                    : diagnosedDisease.details),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'My Comment',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(diagnosedDisease.patientsComment),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AppointmentHistory(
                                diagnosedID: diagnosedDisease.diagnosedID!,
                              ))).then((value) {
                    context.read<PatientBloc>().add(
                          PatientAppointments(patientID: patient.id),
                        );
                  });
                },
                child: const Text('Appointment History'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class CommentSection extends StatelessWidget {
  const CommentSection({super.key, required this.diagnosedDisease});

  final DiagnosedDisease diagnosedDisease;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Doctor\'s Comment',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(diagnosedDisease.doctorsComment.isEmpty
                    ? 'No comments added'
                    : diagnosedDisease.doctorsComment),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class PrescriptionSection extends StatelessWidget {
  const PrescriptionSection({super.key, required this.diagnosedDisease});

  final DiagnosedDisease diagnosedDisease;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Prescription',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(diagnosedDisease.prescription.isEmpty
                    ? 'No prescription given'
                    : diagnosedDisease.prescription),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
