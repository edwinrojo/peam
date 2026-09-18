import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/soft_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final records = session.history;
        return RefreshIndicator(
          onRefresh: session.refreshAttendance,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                _subtitle(session, records),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              _SyncStatusCard(session: session),
              const SizedBox(height: 18),
              if (records.isEmpty)
                const _EmptyHistory()
              else
                ...records.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoryCard(record: record),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(SessionController session, List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return 'Check-ins for this employee appear here after you record attendance.';
    }
    if (session.pendingCount == 0) {
      return records.length == 1
          ? '1 record · uploaded'
          : '${records.length} records · all uploaded';
    }
    final pending = session.pendingCount == 1
        ? '1 waiting to upload'
        : '${session.pendingCount} waiting to upload';
    return '${records.length} records · $pending';
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final online = session.isOnline;
    final pending = session.pendingCount;
    final syncing = session.isSyncing;
    return SoftCard(
      color: online
          ? (pending > 0 ? AppColors.sky : AppColors.mint)
          : AppColors.peach,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: online
                    ? (pending > 0 ? AppColors.skyDeep : AppColors.mintDeep)
                    : AppColors.peachDeep,
              ),
              const SizedBox(width: 8),
              Text(
                syncing
                    ? 'Uploading…'
                    : online
                    ? 'Online'
                    : 'Offline',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _message(online: online, pending: pending, syncing: syncing),
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (online && pending > 0) ...[
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('retry-sync-button'),
              onPressed: syncing
                  ? null
                  : () async {
                      final uploaded = await session.syncPending();
                      if (!context.mounted) {
                        return;
                      }
                      _showSyncResult(context, uploaded);
                    },
              child: Text(syncing ? 'Uploading…' : 'Retry upload'),
            ),
          ],
        ],
      ),
    );
  }

  String _message({
    required bool online,
    required int pending,
    required bool syncing,
  }) {
    if (syncing) {
      return 'Sending saved check-ins to PEAM.';
    }
    if (!online) {
      return 'No network on this phone. New check-ins stay here and upload when connectivity returns.';
    }
    if (pending > 0) {
      return pending == 1
          ? '1 check-in is still on this phone. It will upload automatically, or retry now.'
          : '$pending check-ins are still on this phone. They will upload automatically, or retry now.';
    }
    return 'This phone is connected. Saved attendance is uploaded to PEAM.';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const SoftCard(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          AppVector(AppVectors.ticketPass, width: 64, height: 64),
          SizedBox(height: 12),
          Text(
            'No attendance yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'When you check in at an event, the record is saved on this phone and listed here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      key: Key('history-${record.event.id}'),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppVector(AppVectors.ticketPass, width: 48, height: 48),
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
                  'Check-in  ${_format(record.checkInAt)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                ),
                if (record.checkOutAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Check-out  ${_format(record.checkOutAt!)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      fontSize: 13,
                    ),
                  ),
                ],
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
                      label: record.isPending ? 'Pending' : 'Synced',
                      color: record.isPending
                          ? AppColors.peachDeep
                          : AppColors.mintDeep,
                      fill: record.isPending ? AppColors.peach : AppColors.mint,
                    ),
                    if (record.recordedOffline)
                      _Chip(
                        label: 'Recorded offline',
                        color: AppColors.skyDeep,
                        fill: AppColors.sky,
                      ),
                    if (record.geofenceVerified && record.biometricVerified)
                      _Chip(
                        label: 'Verified',
                        color: AppColors.mintDeep,
                        fill: AppColors.mint,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${months[time.month - 1]} ${time.day}, ${time.year} · $hour:$minute $period';
  }
}

void _showSyncResult(BuildContext context, int uploaded) {
  final message = uploaded == 0
      ? 'No pending records to upload.'
      : uploaded == 1
      ? '1 attendance record uploaded to PEAM.'
      : '$uploaded attendance records uploaded to PEAM.';
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
