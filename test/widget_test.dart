import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peam/app.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/services/auth_session_store.dart';
import 'package:peam/services/biometric_auth_service.dart';
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
    await _openApp(tester);
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
    expect(find.byKey(const Key('simulate-online-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('simulate-online-button')));
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsNothing);
    expect(find.text('Synced'), findsWidgets);
    expect(find.textContaining('uploaded to mock Supabase'), findsOneWidget);
  });

  testWidgets('home search and history navigation work', (tester) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    await tester.enterText(find.byKey(const Key('home-search')), 'Malalag');
    await tester.pump();

    expect(find.text('Barangay Health Outreach'), findsOneWidget);
    expect(find.text('Provincial Employees Assembly 2026'), findsNothing);

    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();

    expect(find.text('Midyear Financial Briefing'), findsOneWidget);
  });

  testWidgets('notifications prototype opens and can simulate a push', (
    tester,
  ) async {
    await _openApp(tester);
    await _loginAsDemo(tester);

    await tester.tap(find.byKey(const Key('notifications-button')));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('New event published'), findsOneWidget);
    expect(find.byKey(const Key('simulate-push-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('simulate-push-button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Disaster Preparedness Training'),
      findsOneWidget,
    );
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
