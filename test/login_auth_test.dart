import 'package:flutter_test/flutter_test.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/models/models.dart';
import 'package:peam/services/auth_session_store.dart';
import 'package:peam/services/email_mask.dart';
import 'package:peam/services/employee_auth_api.dart';
import 'package:peam/services/events_catalog.dart';
import 'package:peam/state/session_controller.dart';

void main() {
  test('maps a verified employee payload from Supabase', () {
    final employee = employeeFromAuthPayload({
      'employee_number': '1234',
      'full_name': 'Edwin Rojo',
      'email': 'edwin.rojo@davaodelsur.gov.ph',
      'department_name': 'Human Resource Management and Development Office',
      'department_code': 'PHRMO',
      'device_uid': 'phone-a',
      'device_name': 'Android phone',
    });

    expect(employee.employeeNumber, '1234');
    expect(employee.hasWorkEmail, isTrue);
    expect(employee.deviceUid, 'phone-a');
  });

  test('masks the HR-stored email instead of showing it in full', () {
    expect(
      maskEmail('edwin.rojo@davaodelsur.gov.ph'),
      'e••••••••o@davaodelsur.gov.ph',
    );
  });

  test('employee id plus prototype code binds this phone', () async {
    final store = MemoryAuthSessionStore(deviceUid: 'phone-a');
    final session = SessionController(authStore: store);
    addTearDown(session.dispose);

    expect(
      await session.requestLoginCode(SampleData.demoEmployee.employeeNumber),
      isNull,
    );
    expect(session.pendingChallenge?.maskedEmail, contains('@'));
    expect(
      session.pendingChallenge?.maskedEmail,
      isNot(contains('edwin.rojo')),
    );

    expect(
      await session.verifyLoginCode(SampleData.prototypeEmailCode),
      isNull,
    );
    expect(session.employee?.deviceBound, isTrue);
    expect(session.employee?.deviceUid, 'phone-a');
    expect(await store.bindingFor('1234'), 'phone-a');
    expect((await store.readSession())?.employeeNumber, '1234');
  });

  test('restores a bound session on the same phone', () async {
    final store = MemoryAuthSessionStore(deviceUid: 'phone-a');
    final first = SessionController(authStore: store);
    addTearDown(first.dispose);
    await first.completePrototypeLogin(SampleData.demoEmployee.employeeNumber);

    final second = SessionController(authStore: store);
    addTearDown(second.dispose);
    await second.restoreSession();

    expect(second.employee?.employeeNumber, '1234');
    expect(second.employee?.deviceUid, 'phone-a');
  });

  test(
    'opens a saved employee and cached events while the network is down',
    () async {
      final store = MemoryAuthSessionStore(deviceUid: 'phone-a');
      const employee = Employee(
        employeeNumber: '1234',
        fullName: 'Edwin Rojo',
        department: Department(name: 'PHRMO', code: 'PHRMO'),
        deviceUid: 'phone-a',
        deviceName: 'Android phone',
      );
      await store.saveSession(employeeNumber: '1234', deviceUid: 'phone-a');
      await store.saveBinding(employeeNumber: '1234', deviceUid: 'phone-a');
      await store.saveEmployee(employee);
      final session = SessionController(
        authStore: store,
        liveAuth: _OfflineAuth(),
        eventsCatalog: CachedEventsCatalog(
          remote: _OfflineCatalog(),
          cache: MemoryEventsCache()
            ..save([
              ProvincialEvent(
                id: 'evt-assembly',
                name: 'Provincial Employees Assembly 2026',
                description: '',
                eventDate: DateTime(2026, 10, 3),
                startTime: '8:00 AM',
                endTime: '5:00 PM',
                venue: 'Capitol',
                location: SampleData.capitol,
                status: EventStatus.ongoing,
              ),
            ]),
          remoteTimeout: const Duration(milliseconds: 20),
        ),
      );
      addTearDown(session.dispose);

      final started = DateTime.now();
      await session.restoreSession();

      expect(DateTime.now().difference(started).inMilliseconds, lessThan(1000));
      expect(session.employee?.fullName, 'Edwin Rojo');
      expect(
        session.visibleEvents.single.name,
        'Provincial Employees Assembly 2026',
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'does not bind a second phone without a device-change request',
    () async {
      final firstStore = MemoryAuthSessionStore(deviceUid: 'phone-a');
      final first = SessionController(authStore: firstStore);
      addTearDown(first.dispose);
      await first.completePrototypeLogin(
        SampleData.demoEmployee.employeeNumber,
      );

      final secondStore = MemoryAuthSessionStore(deviceUid: 'phone-b');
      await secondStore.saveBinding(
        employeeNumber: '1234',
        deviceUid: 'phone-a',
      );
      final second = SessionController(authStore: secondStore);
      addTearDown(second.dispose);

      await second.requestLoginCode('1234');
      final error = await second.verifyLoginCode(SampleData.prototypeEmailCode);

      expect(error, contains('another phone'));
      expect(second.employee, isNull);
      expect(second.deviceChangeRequired, isTrue);

      expect(await second.requestDeviceChange(), isNull);
      expect(await secondStore.pendingDeviceChangeFor('1234'), isNotNull);
    },
  );

  test(
    'logout clears the local session but keeps the device binding',
    () async {
      final store = MemoryAuthSessionStore(deviceUid: 'phone-a');
      final session = SessionController(authStore: store);
      addTearDown(session.dispose);
      await session.completePrototypeLogin(
        SampleData.demoEmployee.employeeNumber,
      );
      await session.logout();

      expect(session.employee, isNull);
      expect(await store.readSession(), isNull);
      expect(await store.bindingFor('1234'), 'phone-a');
    },
  );
}

class _OfflineAuth extends EmployeeAuthApi {
  @override
  Future<Employee?> restore({required String deviceUid}) async {
    throw Exception('offline');
  }
}

class _OfflineCatalog implements EventsCatalog {
  @override
  Future<List<ProvincialEvent>> listVisible() async {
    throw Exception('offline');
  }
}
