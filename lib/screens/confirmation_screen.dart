import 'package:flutter/material.dart';

import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/primary_button.dart';
import '../widgets/soft_card.dart';
import 'main_shell.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  static const routeName = '/confirmation';

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SessionScope.of(context).confirmAttendance(checkInAt: DateTime.now());
    });
  }

  String _timeLabel(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final record = session.lastAttendance;
        final event = record?.event ?? session.selectedEvent;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    children: [
                      const Center(
                        child: AppVector(
                          AppVectors.confirmed,
                          width: 160,
                          height: 160,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Attendance confirmed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event == null
                            ? 'Your attendance has been recorded.'
                            : 'Your check-in for ${event.name} is saved on this device and will sync when connectivity is available.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (record != null)
                        SoftCard(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                          child: Column(
                            children: [
                              _Info(
                                label: 'Employee',
                                value: record.employee.fullName,
                              ),
                              _Info(
                                label: 'Employee ID',
                                value: record.employee.employeeNumber,
                              ),
                              _Info(label: 'Event', value: record.event.name),
                              _Info(
                                label: 'Check-in',
                                value: _timeLabel(record.checkInAt),
                              ),
                              _Info(label: 'Venue', value: record.event.venue),
                              const _Info(
                                label: 'Verification',
                                value: 'Geofence and biometric verified',
                              ),
                              _Info(
                                label: 'Sync status',
                                value: record.recordedOffline
                                    ? 'Pending · recorded offline'
                                    : 'Synced',
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: PrimaryButton(
                    key: const Key('confirmation-done'),
                    label: 'Back to events',
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        MainShell.routeName,
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLast ? 10 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
