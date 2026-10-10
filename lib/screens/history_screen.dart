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
                    padding: const EdgeInsets.only(bottom: 8),
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
      return 'Your check-ins appear here after you record attendance.';
    }
    if (session.pendingCount == 0) {
      return records.length == 1
          ? '1 record · sent to PHRMO'
          : '${records.length} records · all sent to PHRMO';
    }
    final pending = session.pendingCount == 1
        ? '1 still on this phone'
        : '${session.pendingCount} still on this phone';
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
                    ? 'Sending…'
                    : online
                    ? 'Online'
                    : 'No internet',
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
          const SizedBox(height: 8),
          const Text(
            'Pending means the attendance is saved on this phone. PHRMO will see it after the phone is online. Synced means it was already sent, so PHRMO can see it.',
            style: TextStyle(color: AppColors.ink, fontSize: 13, height: 1.4),
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
              child: Text(syncing ? 'Sending…' : 'Send now'),
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
      return 'Sending saved attendance to PHRMO.';
    }
    if (!online) {
      return 'No internet on this phone. New attendance stays here and is sent when you are back online, even if PEAM is closed.';
    }
    if (pending > 0) {
      return pending == 1
          ? '1 attendance record is still only on this phone. It will be sent on its own, or tap Send now.'
          : '$pending attendance records are still only on this phone. They will be sent on their own, or tap Send now.';
    }
    return 'This phone is online. PHRMO has the attendance saved here.';
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppVector(AppVectors.ticketPass, width: 36, height: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.event.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.event.venue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Check-in  ${_format(record.checkInAt)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    fontSize: 12,
                  ),
                ),
                if (record.checkOutAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Check-out  ${_format(record.checkOutAt!)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      fontSize: 12,
                    ),
                  ),
                ] else if (record.event.requiresCheckOut &&
                    !record.needsReview) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Check-out still needed',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.peachDeep,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (record.needsReview) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'PHRMO needs to review this attendance',
                    key: Key('history-review-note'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.peachDeep,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
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
                        label: 'Saved without internet',
                        color: AppColors.skyDeep,
                        fill: AppColors.sky,
                      ),
                    if (record.geofenceVerified &&
                        record.biometricVerified &&
                        !record.needsReview)
                      _Chip(
                        label: 'Checked',
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
    if (record.needsReview) {
      return 'PHRMO review';
    }
    return switch (record.attendanceStatus) {
      AttendanceStatus.present => 'Present',
      AttendanceStatus.incomplete => 'Needs check-out',
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
      ? 'Nothing left to send.'
      : uploaded == 1
      ? '1 attendance record was sent to PHRMO.'
      : '$uploaded attendance records were sent to PHRMO.';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
