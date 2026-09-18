import 'package:flutter_test/flutter_test.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/models/models.dart';
import 'package:peam/services/attendance_stores.dart';
import 'package:peam/services/attendance_sync_service.dart';
import 'package:peam/services/connectivity_controller.dart';
import 'package:peam/services/push_notification_service.dart';
import 'package:peam/services/sqlite_attendance_database.dart';
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

  test('local codec hydrates a live event snapshot without sample data', () {
    final employee = SampleData.demoEmployee;
    final event = ProvincialEvent(
      id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      name: 'Capitol Flag Ceremony',
      description: 'Monday flag ceremony',
      eventDate: DateTime(2026, 9, 21),
      startTime: '8:00 AM',
      endTime: '9:00 AM',
      venue: 'Provincial Capitol Grounds, Digos City',
      location: SampleData.capitol,
      status: EventStatus.ongoing,
    );
    final record = AttendanceRecord(
      clientRecordId: 'c0a80100-0000-4000-8000-00000000ae07',
      event: event,
      employee: employee,
      checkInAt: DateTime(2026, 9, 21, 8, 5),
      checkInLatitude: event.location.latitude,
      checkInLongitude: event.location.longitude,
      recordedOffline: true,
      syncStatus: SyncStatus.pending,
      clientRecordedAt: DateTime(2026, 9, 21, 8, 5),
    );

    final restored = AttendanceRowCodec.fromMap(
      AttendanceRowCodec.toMap(record),
      employee,
    );

    expect(restored, isNotNull);
    expect(restored!.event.id, event.id);
    expect(restored.event.name, 'Capitol Flag Ceremony');
    expect(restored.event.requiresCheckOut, isFalse);
    expect(restored.recordedOffline, isTrue);
  });

  test('codec keeps a live attendance row even without an event snapshot', () {
    final employee = SampleData.demoEmployee;
    final restored = AttendanceRowCodec.fromMap({
      'client_record_id': 'c0a80100-0000-4000-8000-00000000ae08',
      'event_id': '7c9e6679-7425-40de-944b-e07fc1f90ae8',
      'employee_number': employee.employeeNumber,
      'check_in_at': '2026-09-18T08:05:00.000',
      'geofence_verified': 1,
      'biometric_verified': 1,
      'verification_status': 'verified',
      'attendance_status': 'incomplete',
      'recorded_offline': 0,
      'sync_status': 'pending',
    }, employee);

    expect(restored, isNotNull);
    expect(restored!.event.id, '7c9e6679-7425-40de-944b-e07fc1f90ae8');
    expect(restored.syncStatus, SyncStatus.pending);
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
    'failed upload leaves the local row pending for a later retry',
    () async {
      final local = MemoryAttendanceLocalStore();
      final employee = SampleData.demoEmployee;
      await local.upsert(
        checkInRecord(clientRecordId: 'client-retry', employee: employee),
      );

      final uploaded = await const AttendanceSyncService().syncPending(
        local: local,
        remote: _ThrowingRemoteStore(),
        employee: employee,
      );
      final localRows = await local.listForEmployee(employee);

      expect(uploaded, 0);
      expect(localRows.single.syncStatus, SyncStatus.pending);
    },
  );

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

  test(
    'coming back online uploads pending attendance without tapping Sync',
    () async {
      final remote = MemoryAttendanceRemoteStore();
      final connectivity = ConnectivityController();
      final session = SessionController(
        localStore: MemoryAttendanceLocalStore(),
        remoteStore: remote,
        connectivity: connectivity,
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
      expect(await remote.listForEmployee(SampleData.demoEmployee), isEmpty);

      connectivity.simulateOnline();
      await _waitUntil(() => session.pendingCount == 0);

      expect(session.pendingCount, 0);
      expect(session.history.single.syncStatus, SyncStatus.synced);
      expect(
        await remote.listForEmployee(SampleData.demoEmployee),
        hasLength(1),
      );
    },
  );

  test('session rejects check-in after the event end time', () async {
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

    final outreach = SampleData.events.firstWhere(
      (event) => event.id == 'evt-health',
    );
    session.selectEvent(outreach);
    await session.confirmAttendance(checkInAt: DateTime(2026, 9, 17, 16, 0));

    expect(
      session.history.where((record) => record.event.id == 'evt-health'),
      isEmpty,
    );
    expect(session.lastAttendance?.event.id, isNot('evt-health'));
  });

  test('check-in is present when the event does not require check-out', () async {
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

    final now = DateTime.now();
    session.selectEvent(
      ProvincialEvent(
        id: 'evt-no-checkout',
        name: 'Flag ceremony',
        description: '',
        eventDate: DateTime(now.year, now.month, now.day),
        startTime: '8:00 AM',
        endTime: '11:59 PM',
        venue: 'Capitol',
        location: SampleData.capitol,
        status: EventStatus.ongoing,
      ),
    );
    await session.confirmAttendance(checkInAt: DateTime(now.year, now.month, now.day, 9));

    expect(session.history, hasLength(1));
    expect(session.history.single.attendanceStatus, AttendanceStatus.present);
    expect(session.history.single.checkOutAt, isNull);
  });

  test('check-out updates the same attendance row to present', () async {
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
    expect(session.history.single.attendanceStatus, AttendanceStatus.incomplete);

    await session.confirmCheckOut(checkOutAt: DateTime(2026, 8, 25, 11, 30));

    expect(session.history, hasLength(1));
    expect(session.history.single.checkOutAt, DateTime(2026, 8, 25, 11, 30));
    expect(session.history.single.attendanceStatus, AttendanceStatus.present);
    expect(session.history.single.isPending, isTrue);

    await session.simulateOnlineAndSync();
    expect(session.history.single.syncStatus, SyncStatus.synced);
    expect(session.remoteRecordCount, 1);
  });

  test('check-out is rejected when the employee has not checked in', () async {
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
    await session.confirmCheckOut(checkOutAt: DateTime(2026, 8, 25, 11, 30));

    expect(session.history, isEmpty);
    expect(session.lastAttendance, isNull);
  });

  test('local store merges check-out onto the existing event row', () async {
    final local = MemoryAttendanceLocalStore();
    final employee = SampleData.demoEmployee;
    final first = checkInRecord(clientRecordId: 'client-a', employee: employee);
    await local.upsert(first);

    final stored = await local.upsert(
      first.copyWith(
        checkOutAt: DateTime(2026, 8, 25, 11, 45),
        checkOutLatitude: first.event.location.latitude,
        checkOutLongitude: first.event.location.longitude,
        attendanceStatus: AttendanceStatus.present,
      ),
    );
    final rows = await local.listForEmployee(employee);

    expect(rows, hasLength(1));
    expect(stored.clientRecordId, 'client-a');
    expect(stored.checkOutAt, DateTime(2026, 8, 25, 11, 45));
    expect(stored.attendanceStatus, AttendanceStatus.present);
  });
}

Future<void> _waitUntil(bool Function() test) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (test()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for auto-sync.');
}

class _ThrowingRemoteStore implements AttendanceRemoteStore {
  @override
  Future<AttendanceRecord> upsert(AttendanceRecord record) {
    throw StateError('Supabase unreachable');
  }

  @override
  Future<List<AttendanceRecord>> listForEmployee(Employee employee) async {
    return const [];
  }
}
