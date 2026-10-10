import 'package:flutter_test/flutter_test.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/models/models.dart';
import 'package:peam/services/attendance_integrity.dart';
import 'package:peam/services/attendance_stores.dart';
import 'package:peam/services/connectivity_controller.dart';
import 'package:peam/services/device_guard.dart';
import 'package:peam/services/geofence.dart';
import 'package:peam/services/location_service.dart';
import 'package:peam/services/push_notification_service.dart';
import 'package:peam/services/supabase_attendance_store.dart';
import 'package:peam/services/trusted_clock.dart';
import 'package:peam/state/session_controller.dart';

void main() {
  const fence = EventLocation(
    latitude: 6.7492,
    longitude: 125.3571,
    geofenceRadiusMeters: 100,
  );

  group('location samples', () {
    test('any mocked sample marks the combined fix as mocked', () {
      final combined = combineSamples(const [
        DevicePosition(latitude: 6.7492, longitude: 125.3571),
        DevicePosition(latitude: 6.7493, longitude: 125.3571, isMocked: true),
      ]);
      expect(combined.isMocked, isTrue);
    });

    test('three identical samples are flagged as static', () {
      const sample = DevicePosition(
        latitude: 6.7492,
        longitude: 125.3571,
        accuracyMeters: 5,
      );
      expect(combineSamples(const [sample, sample, sample]).isStatic, isTrue);
      expect(combineSamples(const [sample, sample]).isStatic, isFalse);
    });

    test('the most accurate sample is used', () {
      final combined = combineSamples(const [
        DevicePosition(latitude: 1, longitude: 1, accuracyMeters: 40),
        DevicePosition(latitude: 2, longitude: 2, accuracyMeters: 8),
        DevicePosition(latitude: 3, longitude: 3, accuracyMeters: 20),
      ]);
      expect(combined.latitude, 2);
      expect(combined.accuracyMeters, 8);
    });
  });

  group('geofence issues', () {
    test('a fake location blocks attendance even inside the area', () {
      final check = checkGeofence(
        fence: fence,
        position: const DevicePosition(
          latitude: 6.7492,
          longitude: 125.3571,
          isMocked: true,
        ),
      );
      expect(check.isInside, isTrue);
      expect(check.issue, GeofenceIssue.mockLocation);
      expect(check.allowsAttendance, isFalse);
    });

    test('accuracy wider than the event area blocks attendance', () {
      final check = checkGeofence(
        fence: fence,
        position: const DevicePosition(
          latitude: 6.7492,
          longitude: 125.3571,
          accuracyMeters: 150,
        ),
      );
      expect(check.issue, GeofenceIssue.lowAccuracy);
    });

    test('an accurate fix inside the area is allowed', () {
      final check = checkGeofence(
        fence: fence,
        position: const DevicePosition(
          latitude: 6.7492,
          longitude: 125.3571,
          accuracyMeters: 12,
        ),
      );
      expect(check.issue, isNull);
      expect(check.allowsAttendance, isTrue);
    });
  });

  group('trusted clock', () {
    test('uses server time plus monotonic elapsed time', () async {
      final guard = StubDeviceGuard(
        reading: const ClockReading(elapsedMs: 10000, bootCount: 4),
      );
      final clock = TrustedClock(
        guard: guard,
        deviceNow: () => DateTime(2030, 1, 1),
      );
      final server = DateTime.utc(2026, 8, 25, 0, 15);
      await clock.anchor(server);
      guard.reading = const ClockReading(elapsedMs: 70000, bootCount: 4);

      final time = await clock.now();
      expect(time.source, TimeSource.serverAnchor);
      expect(time.at.toUtc(), server.add(const Duration(minutes: 1)));
    });

    test('falls back to the phone clock after a reboot', () async {
      final guard = StubDeviceGuard(
        reading: const ClockReading(elapsedMs: 10000, bootCount: 4),
      );
      final deviceNow = DateTime(2026, 8, 25, 8, 30);
      final clock = TrustedClock(guard: guard, deviceNow: () => deviceNow);
      await clock.anchor(DateTime.utc(2026, 8, 25));
      guard.reading = const ClockReading(elapsedMs: 500, bootCount: 5);

      final time = await clock.now();
      expect(time.source, TimeSource.deviceClock);
      expect(time.at, deviceNow);
    });

    test('anchors survive a round trip through JSON', () {
      const anchor = ClockAnchor(serverMs: 1, elapsedMs: 2, bootCount: 3);
      final restored = ClockAnchor.fromJson(anchor.toJson())!;
      expect(restored.serverMs, 1);
      expect(restored.elapsedMs, 2);
      expect(restored.bootCount, 3);
    });
  });

  test('payload sends location quality and time source', () {
    final record = AttendanceRecord(
      clientRecordId: 'client-1',
      event: SampleData.events.first,
      employee: SampleData.demoEmployee,
      checkInAt: DateTime.utc(2026, 8, 25),
      clientRecordedAt: DateTime.utc(2026, 8, 25),
      checkInAccuracyMeters: 9.5,
      checkInStatic: true,
      checkInTimeSource: TimeSource.serverAnchor,
    );
    final payload = attendanceInsertPayload(
      profileId: 'profile-1',
      deviceId: null,
      record: record,
    );
    expect(payload['check_in_accuracy_m'], 9.5);
    expect(payload['check_in_mocked'], isFalse);
    expect(payload['check_in_static'], isTrue);
    expect(payload['check_in_time_source'], 'server_anchor');
    expect(payload.containsKey('integrity_status'), isFalse);
  });

  test('integrity status round-trips its database name', () {
    expect(IntegrityStatus.appUnrecognized.dbName, 'app_unrecognized');
    expect(
      IntegrityStatusDb.parse('app_unrecognized'),
      IntegrityStatus.appUnrecognized,
    );
    expect(IntegrityStatusDb.parse(null), IntegrityStatus.unchecked);
  });

  test('integrity nonce is URL-safe base64 of the record id', () {
    expect(integrityNonce('abc'), 'cGVhbS1hdHRlbmRhbmNlOmFiYw==');
  });

  group('session', () {
    SessionController buildSession({
      required StubDeviceGuard guard,
      TrustedClock? clock,
      AttendanceIntegrityApi? integrity,
      ConnectivityController? connectivity,
    }) {
      final session = SessionController(
        localStore: MemoryAttendanceLocalStore(),
        remoteStore: MemoryAttendanceRemoteStore(),
        connectivity: connectivity ?? ConnectivityController(),
        pushNotifications: PushNotificationService(enableSystemBanners: false),
        deviceGuard: guard,
        trustedClock: clock,
        integrityApi: integrity,
      );
      addTearDown(session.dispose);
      return session;
    }

    test('sign-in resets the biometric guard so it can be re-armed', () async {
      final guard = StubDeviceGuard(state: BioGuardState.changed);
      final session = buildSession(guard: guard);

      await session.completePrototypeLogin(
        SampleData.demoEmployee.employeeNumber,
      );
      expect(await session.biometricGuardState(), BioGuardState.missing);

      await session.armBiometricGuardIfMissing();
      expect(await session.biometricGuardState(), BioGuardState.ok);
    });

    test('a fake location is not saved as attendance', () async {
      final session = buildSession(guard: StubDeviceGuard());
      await session.completePrototypeLogin(
        SampleData.demoEmployee.employeeNumber,
      );
      final event = SampleData.events.first;
      session.selectEvent(event);
      session.stageGeofence(
        checkGeofence(
          fence: event.location,
          position: DevicePosition(
            latitude: event.location.latitude,
            longitude: event.location.longitude,
            isMocked: true,
          ),
        ),
      );

      await session.confirmAttendance(checkInAt: _onAssemblyDay(8, 15));
      expect(session.history, isEmpty);
    });

    test(
      'check-in uses the server-anchored time, not the phone clock',
      () async {
        final guard = StubDeviceGuard(
          reading: const ClockReading(elapsedMs: 1000, bootCount: 1),
        );
        final clock = TrustedClock(
          guard: guard,
          deviceNow: () => DateTime(2030, 1, 1),
        );
        await clock.anchor(_onAssemblyDay(8, 15));
        guard.reading = const ClockReading(elapsedMs: 61000, bootCount: 1);
        final session = buildSession(guard: guard, clock: clock);
        await session.completePrototypeLogin(
          SampleData.demoEmployee.employeeNumber,
        );
        session.selectEvent(SampleData.events.first);

        await session.confirmAttendance();

        final record = session.history.single;
        expect(record.checkInAt, _onAssemblyDay(8, 16));
        expect(record.checkInTimeSource, TimeSource.serverAnchor);
      },
    );

    test('synced records are sent for a Play Integrity check', () async {
      final guard = StubDeviceGuard(token: 'token-1');
      final integrity = _FakeIntegrityApi();
      final session = buildSession(guard: guard, integrity: integrity);
      await session.completePrototypeLogin(
        SampleData.demoEmployee.employeeNumber,
      );
      session.selectEvent(SampleData.events.first);
      await session.confirmAttendance(checkInAt: _onAssemblyDay(8, 15));

      await session.simulateOnlineAndSync();

      final record = session.history.single;
      expect(integrity.verified, [record.clientRecordId]);
      expect(guard.requestedNonces, [integrityNonce(record.clientRecordId)]);
      expect(record.integrityStatus, IntegrityStatus.passed);
    });
  });
}

class _FakeIntegrityApi implements AttendanceIntegrityApi {
  final List<String> verified = [];

  @override
  Future<DateTime?> serverNow() async => null;

  @override
  Future<IntegrityStatus?> verify({
    required String clientRecordId,
    required String token,
  }) async {
    verified.add(clientRecordId);
    return IntegrityStatus.passed;
  }
}

DateTime _onAssemblyDay(int hour, int minute) {
  final day = SampleData.events.first.eventDate;
  return DateTime(day.year, day.month, day.day, hour, minute);
}
