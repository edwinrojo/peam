import '../models/models.dart';
import 'attendance_stores.dart';
import 'client_ids.dart';

/// Uploads pending local rows to Supabase (or the prototype remote store).
class AttendanceSyncService {
  const AttendanceSyncService();

  Future<int> syncPending({
    required AttendanceLocalStore local,
    required AttendanceRemoteStore remote,
    required Employee employee,
  }) async {
    final pending = await local.pendingFor(employee);
    var uploaded = 0;
    for (final record in pending) {
      final syncedAt = DateTime.now().toUtc();
      try {
        final remoteRow = await remote.upsert(
          record.copyWith(
            serverId: record.serverId ?? newClientRecordId(),
            syncStatus: SyncStatus.synced,
            syncedAt: syncedAt,
          ),
        );
        await local.markSynced(
          clientRecordId: record.clientRecordId,
          serverId: remoteRow.serverId ?? record.clientRecordId,
          syncedAt: remoteRow.syncedAt ?? syncedAt,
        );
        uploaded += 1;
      } catch (_) {
        // Leave the row pending so a later connectivity change can retry.
      }
    }
    return uploaded;
  }
}
