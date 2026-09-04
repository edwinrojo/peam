import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/soft_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _status(AttendanceRecord record) {
    return switch (record.attendanceStatus) {
      AttendanceStatus.present => 'Present',
      AttendanceStatus.incomplete => 'Incomplete',
      AttendanceStatus.absent => 'Absent',
    };
  }

  Color _statusColor(AttendanceRecord record) {
    return switch (record.attendanceStatus) {
      AttendanceStatus.present => AppColors.mintDeep,
      AttendanceStatus.incomplete => AppColors.peachDeep,
      AttendanceStatus.absent => AppColors.muted,
    };
  }

  Color _statusFill(AttendanceRecord record) {
    return switch (record.attendanceStatus) {
      AttendanceStatus.present => AppColors.mint,
      AttendanceStatus.incomplete => AppColors.peach,
      AttendanceStatus.absent => AppColors.line,
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final records = session.history;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Text(
              'Attendance history',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              records.isEmpty
                  ? 'No attendance records yet.'
                  : 'There are ${records.length} synced or local records.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            if (records.isNotEmpty)
              ...records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const AppVector(
                          AppVectors.ticketPass,
                          width: 48,
                          height: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.event.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.event.venue,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _format(record.checkInAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusFill(record),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            _status(record),
                            style: TextStyle(
                              color: _statusColor(record),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _format(DateTime time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}, ${time.year}';
  }
}
