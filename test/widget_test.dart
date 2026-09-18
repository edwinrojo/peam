import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peam/app.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/models/app_notification.dart';
import 'package:peam/navigation/notification_tap.dart';
import 'package:peam/services/attendance_stores.dart';
import 'package:peam/services/auth_session_store.dart';
import 'package:peam/services/biometric_auth_service.dart';
import 'package:peam/services/connectivity_controller.dart';
import 'package:peam/services/location_service.dart';
import 'package:peam/services/push_notification_service.dart';
import 'package:peam/state/session_controller.dart';

void main() {
  testWidgets('login screen shows the sign-in journey controls', (
    tester,
  ) async {
    await _openApp(tester);

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Employee ID'), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
    expect(find.byKey(const Key('register-link')), findsNothing);
    expect(find.text('Password'), findsNothing);
  });

  testWidgets('login validates empty employee id', (tester) async {
    await _openApp(tester);

    await tester.ensureVisible(find.byKey(const Key('login-button')));
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(find.text('Enter your Employee ID'), findsOneWidget);
  });

  testWidgets('login rejects an unknown employee id', (tester) async {
    await _openApp(tester);

    await tester.enterText(
      find.byKey(const Key('login-employee-id')),
      'DS-0000',
    );
    await tester.ensureVisible(find.byKey(const Key('login-button')));
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    await tester.pumpAndSettle();
    expect(
      find.text(
        'This Employee ID is not on file. Ask HRMDO to create your account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('demo email-code login opens the events home screen', (
    tester,
  ) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    expect(find.text('Official events'), findsOneWidget);
    expect(find.text('Provincial Employees Assembly 2026'), findsOneWidget);
    expect(find.text('Check-out required'), findsWidgets);
    expect(find.text('Check-in'), findsWidgets);
    expect(
      find.text('Good day, ${SampleData.demoEmployee.firstName}'),
      findsOneWidget,
    );
  });

  testWidgets('a bound session skips the login screen on launch', (
    tester,
  ) async {
    final store = MemoryAuthSessionStore(deviceUid: 'phone-a');
    final session = SessionController(authStore: store);
    addTearDown(session.dispose);
    final error = await session.completePrototypeLogin(
      SampleData.demoEmployee.employeeNumber,
    );
    expect(error, isNull);

    await tester.pumpWidget(PeamApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('Official events'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('main attendance journey reaches confirmation', (tester) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    await tester.ensureVisible(
      find.byKey(const Key('event-card-evt-assembly')),
    );
    await tester.tap(find.byKey(const Key('event-card-evt-assembly')));
    await tester.pumpAndSettle();

    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Provincial Capitol Grounds, Digos City'), findsWidgets);
    expect(find.byKey(const Key('check-in-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pumpAndSettle();

    expect(find.text('Verify it is you'), findsOneWidget);
    expect(find.text('Fingerprint'), findsOneWidget);
    expect(find.text('Face'), findsOneWidget);

    await tester.tap(find.byKey(const Key('biometric-button')));
    await tester.pumpAndSettle();

    expect(find.text('Attendance confirmed'), findsOneWidget);
    expect(find.text(SampleData.demoEmployee.fullName), findsOneWidget);
    expect(find.text('Geofence and biometric verified'), findsOneWidget);
    expect(find.textContaining('Pending'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmation-done')));
    await tester.pumpAndSettle();

    expect(find.text('Official events'), findsOneWidget);
    expect(find.text('Check out'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('event-card-evt-assembly')),
    );
    await tester.tap(find.byKey(const Key('event-card-evt-assembly')));
    await tester.pumpAndSettle();

    expect(find.text('Check out'), findsWidgets);
    expect(find.text('Check-out'), findsOneWidget);

    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('biometric-button')));
    await tester.pumpAndSettle();

    expect(find.text('Checked out'), findsOneWidget);
    expect(find.text('Check-out'), findsWidgets);

    await tester.tap(find.byKey(const Key('confirmation-done')));
    await tester.pumpAndSettle();
    expect(find.text('Recorded'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('event-card-evt-assembly')),
    );
    await tester.tap(find.byKey(const Key('event-card-evt-assembly')));
    await tester.pumpAndSettle();
    expect(find.text('Official events'), findsOneWidget);
    expect(find.byKey(const Key('check-in-button')), findsNothing);
  });

  testWidgets('check-in stays on the event when GPS is outside the geofence', (
    tester,
  ) async {
    await tester.pumpWidget(
      const PeamApp(
        locationService: StubLocationService(
          position: DevicePosition(latitude: 7.1, longitude: 125.6),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _loginAsDemo(tester);

    await tester.ensureVisible(
      find.byKey(const Key('event-card-evt-assembly')),
    );
    await tester.tap(find.byKey(const Key('event-card-evt-assembly')));
    await tester.pumpAndSettle();

    expect(find.text('Outside the event area'), findsOneWidget);
    expect(find.text('Recheck location'), findsOneWidget);
    expect(find.text('Verify it is you'), findsNothing);

    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pumpAndSettle();

    expect(find.text('Verify it is you'), findsNothing);
    expect(find.text('Check in'), findsOneWidget);
  });

  testWidgets('check-in is blocked after the event end time', (tester) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    await tester.ensureVisible(find.byKey(const Key('event-card-evt-health')));
    await tester.tap(find.byKey(const Key('event-card-evt-health')));
    await tester.pumpAndSettle();

    expect(find.text('Barangay Health Outreach'), findsOneWidget);
    expect(find.text('Check-in closed'), findsOneWidget);
    expect(find.text('Event ended'), findsOneWidget);
    expect(find.textContaining('This event has ended'), findsOneWidget);
    expect(find.text('Verify it is you'), findsNothing);

    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pumpAndSettle();

    expect(find.text('Verify it is you'), findsNothing);
    expect(find.text('Check in'), findsOneWidget);
  });

  testWidgets('failed biometric stays on the authenticate screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const PeamApp(biometricAuth: _RejectingBiometricAuth()),
    );
    await tester.pumpAndSettle();
    await _loginAsDemo(tester);

    await tester.ensureVisible(
      find.byKey(const Key('event-card-evt-assembly')),
    );
    await tester.tap(find.byKey(const Key('event-card-evt-assembly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('biometric-button')));
    await tester.pumpAndSettle();

    expect(find.text('Verify it is you'), findsOneWidget);
    expect(find.text('Not recognized. Try again.'), findsOneWidget);
    expect(find.text('Attendance confirmed'), findsNothing);
  });

  testWidgets('offline check-in is stored locally and syncs when online', (
    tester,
  ) async {
    final connectivity = ConnectivityController();
    final session = SessionController(
      localStore: MemoryAttendanceLocalStore.withDemoSeed(),
      remoteStore: MemoryAttendanceRemoteStore(),
      connectivity: connectivity,
      pushNotifications: PushNotificationService(enableSystemBanners: false),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(PeamApp(session: session));
    await tester.pumpAndSettle();
    await _loginAsDemo(tester);

    expect(
      find.text('Offline · new check-ins stay on this device'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('event-card-evt-assembly')),
    );
    await tester.tap(find.byKey(const Key('event-card-evt-assembly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('biometric-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pending'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmation-done')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();

    expect(find.text('Provincial Employees Assembly 2026'), findsOneWidget);
    expect(find.text('Midyear Financial Briefing'), findsOneWidget);
    expect(find.byKey(const Key('sync-chip-evt-assembly')), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Simulate connectivity'), findsNothing);
    expect(find.text('Simulate offline'), findsNothing);
    expect(find.byKey(const Key('simulate-online-button')), findsNothing);

    connectivity.simulateOnline();
    await session.syncPending();
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsNothing);
    expect(find.text('Synced'), findsWidgets);
  });

  testWidgets('home search and history navigation work', (tester) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    await tester.tap(find.byKey(const Key('filter-ongoing')));
    await tester.pump();
    expect(find.text('Barangay Health Outreach'), findsNothing);

    await tester.tap(find.byKey(const Key('home-search')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('home-search')), 'Malalag');
    await tester.pumpAndSettle();

    expect(find.text('Barangay Health Outreach'), findsOneWidget);
    expect(find.text('Provincial Employees Assembly 2026'), findsNothing);
    expect(find.byKey(const Key('filter-ongoing')), findsNothing);
    expect(find.text('Attendance Made Simple'), findsNothing);
    expect(find.byKey(const Key('home-search-clear')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-search-clear')));
    await tester.pump();

    expect(find.byKey(const Key('home-search')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('home-search')))
          .controller
          ?.text,
      isEmpty,
    );

    await tester.tap(find.byKey(const Key('home-search-back')));
    await tester.pump();

    expect(find.text('Attendance Made Simple'), findsOneWidget);
    expect(find.byKey(const Key('filter-ongoing')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();

    expect(find.text('Midyear Financial Briefing'), findsOneWidget);
    expect(find.text('Simulate connectivity'), findsNothing);
    expect(find.text('Simulate offline'), findsNothing);
    expect(find.textContaining('simulate a drop'), findsNothing);
  });

  testWidgets('root back asks before closing the app', (tester) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Close PEAM?'), findsOneWidget);
    expect(find.text('Official events'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-app-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Close PEAM?'), findsNothing);
    expect(find.text('Official events'), findsOneWidget);
  });

  testWidgets('system back closes home search before asking to exit', (
    tester,
  ) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    await tester.tap(find.byKey(const Key('home-search')));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Close PEAM?'), findsNothing);
    expect(find.text('Attendance Made Simple'), findsOneWidget);
  });

  testWidgets('notifications list real notices and has no simulate control', (
    tester,
  ) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    await tester.tap(find.byKey(const Key('notifications-button')));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.byKey(const Key('simulate-push-button')), findsNothing);
    expect(find.text('Simulate push'), findsNothing);
  });

  testWidgets('tapping an event notice opens check-in', (tester) async {
    final session = SessionController(
      pushNotifications: PushNotificationService(enableSystemBanners: false),
    );
    addTearDown(session.dispose);
    final error = await session.completePrototypeLogin(
      SampleData.demoEmployee.employeeNumber,
    );
    expect(error, isNull);
    await session.addNotification(
      title: 'New event published',
      body: 'Provincial Employees Assembly 2026 is scheduled at the Capitol.',
      kind: NotificationKind.eventPublished,
      eventId: 'evt-assembly',
    );

    await tester.pumpWidget(PeamApp(session: session));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notifications-button')));
    await tester.pumpAndSettle();

    expect(find.text('New event published'), findsOneWidget);
    await tester.tap(find.text('New event published'));
    await tester.pumpAndSettle();

    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Provincial Employees Assembly 2026'), findsOneWidget);
    expect(session.unreadNotificationCount, 0);
  });

  testWidgets('tapping an attendance notice opens history', (tester) async {
    final session = SessionController(
      pushNotifications: PushNotificationService(enableSystemBanners: false),
    );
    addTearDown(session.dispose);
    final error = await session.completePrototypeLogin(
      SampleData.demoEmployee.employeeNumber,
    );
    expect(error, isNull);
    await session.addNotification(
      title: 'Attendance synced',
      body: '1 pending attendance record was uploaded to PEAM.',
      kind: NotificationKind.attendanceSync,
      eventId: 'evt-assembly',
    );

    await tester.pumpWidget(PeamApp(session: session));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notifications-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attendance synced'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance history'), findsOneWidget);
    expect(session.shellTab, 1);
  });

  testWidgets('tapping a device-change notice opens profile', (tester) async {
    final session = SessionController(
      pushNotifications: PushNotificationService(enableSystemBanners: false),
    );
    addTearDown(session.dispose);
    final error = await session.completePrototypeLogin(
      SampleData.demoEmployee.employeeNumber,
    );
    expect(error, isNull);
    await session.addNotification(
      title: 'Device-change request approved',
      body: 'HRMDO approved your request. You can use the new phone.',
      kind: NotificationKind.deviceChangeUpdate,
    );

    await tester.pumpWidget(PeamApp(session: session));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notifications-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device-change request approved'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
    expect(find.text(SampleData.demoEmployee.fullName), findsOneWidget);
    expect(find.text('Binding'), findsOneWidget);
    expect(session.shellTab, 2);
  });

  testWidgets('an OS notification payload opens the event check-in', (
    tester,
  ) async {
    final session = SessionController(
      pushNotifications: PushNotificationService(enableSystemBanners: false),
    );
    addTearDown(session.dispose);
    final error = await session.completePrototypeLogin(
      SampleData.demoEmployee.employeeNumber,
    );
    expect(error, isNull);

    await tester.pumpWidget(PeamApp(session: session));
    await tester.pumpAndSettle();

    await openNotificationPayload(
      session: session,
      payload: NotificationPayload(
        kind: NotificationKind.eventReminder,
        eventId: 'evt-assembly',
        notificationId: 'event-reminder-evt-assembly',
      ).encode(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Provincial Employees Assembly 2026'), findsOneWidget);
  });
}

Future<void> _openApp(WidgetTester tester) async {
  await tester.pumpWidget(const PeamApp());
  await tester.pumpAndSettle();
}

Future<void> _loginAsDemo(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login-employee-id')),
    SampleData.demoEmployee.employeeNumber,
  );
  await tester.ensureVisible(find.byKey(const Key('login-button')));
  await tester.tap(find.byKey(const Key('login-button')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('login-code')),
    SampleData.prototypeEmailCode,
  );
  await tester.ensureVisible(find.byKey(const Key('login-button')));
  await tester.tap(find.byKey(const Key('login-button')));
  await tester.pumpAndSettle();
}

class _RejectingBiometricAuth implements BiometricAuthService {
  const _RejectingBiometricAuth();

  @override
  Future<BiometricAvailability> probe() async {
    return BiometricAvailability.stubEnrolled;
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required BiometricMethod method,
  }) async {
    return const BiometricAuthResult.failure('Not recognized. Try again.');
  }
}
