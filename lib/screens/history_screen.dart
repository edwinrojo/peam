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
                  : '${records.length} local records · ${session.pendingCount} pending sync · ${session.remoteRecordCount} in mock Supabase',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _SyncPrototypeCard(session: session),
            const SizedBox(height: 18),
            if (records.isNotEmpty)
              ...records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftCard(
                    key: Key('history-${record.event.id}'),
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
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _Chip(
                                    label: _status(record),
                                    color: _statusColor(record),
                                    fill: _statusFill(record),
                                  ),
                                  _Chip(
                                    key: Key('sync-chip-${record.event.id}'),
                                    label: record.isPending
                                        ? 'Pending'
                                        : 'Synced',
                                    color: record.isPending
                                        ? AppColors.peachDeep
                                        : AppColors.mintDeep,
                                    fill: record.isPending
                                        ? AppColors.peach
                                        : AppColors.mint,
                                  ),
                                ],
                              ),
                            ],
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

class _SyncPrototypeCard extends StatelessWidget {
  const _SyncPrototypeCard({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final online = session.isOnline;
    return SoftCard(
      color: online ? AppColors.mint : AppColors.peach,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            online
                ? 'Prototype connectivity: online'
                : 'Prototype connectivity: offline',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            online
                ? 'Pending local rows upload to a mock Supabase table, then are marked synced. Device network: ${session.deviceHasNetwork ? 'available' : 'none'}.'
                : 'Check-ins are stored in the on-device SQLite database (Room / Core Data stand-in). They stay pending until connectivity is restored. Device network: ${session.deviceHasNetwork ? 'available' : 'none'}.',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!online)
                FilledButton(
                  key: const Key('simulate-online-button'),
                  onPressed: session.isSyncing
                      ? null
                      : () async {
                          final uploaded = await session.simulateOnlineAndSync();
                          if (!context.mounted) {
                            return;
                          }
                          _showSyncResult(context, uploaded);
                        },
                  child: Text(
                    session.isSyncing ? 'Syncing…' : 'Simulate connectivity',
                  ),
                )
              else ...[
                FilledButton(
                  key: const Key('sync-now-button'),
                  onPressed: session.pendingCount == 0 || session.isSyncing
                      ? null
                      : () async {
                          final uploaded = await session.syncPending();
                          if (!context.mounted) {
                            return;
                          }
                          _showSyncResult(context, uploaded);
                        },
                  child: Text(session.isSyncing ? 'Syncing…' : 'Sync now'),
                ),
                OutlinedButton(
                  key: const Key('simulate-offline-button'),
                  onPressed: session.simulateOffline,
                  child: const Text('Simulate offline'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

void _showSyncResult(BuildContext context, int uploaded) {
  final message = uploaded == 0
      ? 'No pending records to upload.'
      : uploaded == 1
      ? '1 attendance record uploaded to mock Supabase.'
      : '$uploaded attendance records uploaded to mock Supabase.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.color,
    required this.fill,
  });

  final String label;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
