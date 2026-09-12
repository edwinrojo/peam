import 'package:flutter_test/flutter_test.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/models/models.dart';
import 'package:peam/services/attendance_stores.dart';
import 'package:peam/services/attendance_sync_service.dart';
import 'package:peam/services/connectivity_controller.dart';
import 'package:peam/services/push_notification_service.dart';
import 'package:peam/state/session_controller.dart';

void main() {
  AttendanceRecord checkInRecord({
    required String clientRecordId,
    required Employee employee,
    ProvincialEvent? event,
  }) {
    final selected = event ?? SampleData.events.first;
    return AttendanceRecord(
      clientRecordId: clientRecordId,
      event: selected,
      employee: employee,
      checkInAt: DateTime(2026, 8, 25, 8, 12),
      checkInLatitude: selected.location.latitude,
      checkInLongitude: selected.location.longitude,
      recordedOffline: true,
      syncStatus: SyncStatus.pending,
      clientRecordedAt: DateTime(2026, 8, 25, 8, 12),
    );
  }

  test('local store keeps one attendance row per employee per event', () async {
    final local = MemoryAttendanceLocalStore();
    final employee = SampleData.demoEmployee;
    final first = checkInRecord(clientRecordId: 'client-a', employee: employee);
    final duplicate = checkInRecord(
      clientRecordId: 'client-b',
      employee: employee,
    );

    await local.upsert(first);
    final stored = await local.upsert(duplicate);
    final rows = await local.listForEmployee(employee);

    expect(stored.clientRecordId, 'client-a');
    expect(rows, hasLength(1));
  });

  test('sync uploads pending local rows and marks them synced', () async {
    final local = MemoryAttendanceLocalStore();
    final remote = MemoryAttendanceRemoteStore();
    final employee = SampleData.demoEmployee;
    await local.upsert(
      checkInRecord(clientRecordId: 'client-offline', employee: employee),
    );

    final uploaded = await const AttendanceSyncService().syncPending(
      local: local,
      remote: remote,
      employee: employee,
    );
    final localRows = await local.listForEmployee(employee);
    final remoteRows = await remote.listForEmployee(employee);

    expect(uploaded, 1);
    expect(localRows.single.syncStatus, SyncStatus.synced);
    expect(localRows.single.serverId, isNotNull);
    expect(remoteRows, hasLength(1));
    expect(remoteRows.single.clientRecordId, 'client-offline');
  });

  test(
    'session keeps check-in pending offline then syncs when online',
    () async {
      final session = SessionController(
        localStore: MemoryAttendanceLocalStore(),
        remoteStore: MemoryAttendanceRemoteStore(),
        connectivity: ConnectivityController(),
        pushNotifications: PushNotificationService(enableSystemBanners: false),
      );
      addTearDown(session.dispose);

      final error = await session.completePrototypeLogin(
        SampleData.demoEmployee.employeeNumber,
      );
      expect(error, isNull);

      session.selectEvent(SampleData.events.first);
      await session.confirmAttendance(checkInAt: DateTime(2026, 8, 25, 8, 15));

      expect(session.pendingCount, 1);
      expect(session.history.single.isPending, isTrue);
      expect(session.remoteRecordCount, 0);

      await session.simulateOnlineAndSync();

      expect(session.isOnline, isTrue);
      expect(session.pendingCount, 0);
      expect(session.history.single.syncStatus, SyncStatus.synced);
      expect(session.remoteRecordCount, 1);
    },
  );
}
