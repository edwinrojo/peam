import '../models/models.dart';
import 'attendance_stores.dart';
import 'client_ids.dart';

/// Uploads pending local rows to the mock Supabase store, then marks them synced.
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
    }
    return uploaded;
  }
}
