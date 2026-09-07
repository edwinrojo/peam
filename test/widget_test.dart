import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peam/app.dart';
import 'package:peam/data/sample_data.dart';

void main() {
  testWidgets('login screen shows the sign-in journey controls', (
    tester,
  ) async {
    await tester.pumpWidget(const PeamApp());

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Employee ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
    expect(find.byKey(const Key('register-link')), findsOneWidget);
  });

  testWidgets('login validates empty fields', (tester) async {
    await tester.pumpWidget(const PeamApp());

    await tester.ensureVisible(find.byKey(const Key('login-button')));
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(find.text('Enter your Employee ID'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('login rejects unknown credentials', (tester) async {
    await tester.pumpWidget(const PeamApp());

    await tester.enterText(
      find.byKey(const Key('login-employee-id')),
      'DS-0000',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'wrongpass',
    );
    await tester.ensureVisible(find.byKey(const Key('login-button')));
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(find.text('Employee ID or password is incorrect.'), findsOneWidget);
  });

  testWidgets('demo login opens the events home screen', (tester) async {
    await tester.pumpWidget(const PeamApp());
    await _loginAsDemo(tester);

    expect(find.text('Official events'), findsOneWidget);
    expect(find.text('Provincial Employees Assembly 2026'), findsOneWidget);
    expect(find.text('Good day, Maria'), findsOneWidget);
  });

  testWidgets('register screen can create an account and reach home', (
    tester,
  ) async {
    await tester.pumpWidget(const PeamApp());

    await tester.tap(find.byKey(const Key('register-link')));
    await tester.pumpAndSettle();

    expect(find.text('Create your PEAM account'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register-name')),
      'Juan Dela Cruz',
    );
    await tester.enterText(
      find.byKey(const Key('register-employee-id')),
      'DS-2088',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'capitol1',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirm-password')),
      'capitol1',
    );
    await tester.tap(find.byKey(const Key('register-button')));
    await tester.pumpAndSettle();

    expect(find.text('Good day, Juan'), findsOneWidget);
    expect(find.text('Official events'), findsOneWidget);
  });

  testWidgets('main attendance journey reaches confirmation', (tester) async {
    await tester.pumpWidget(const PeamApp());
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Attendance confirmed'), findsOneWidget);
    expect(find.text('Maria Elena Santos'), findsOneWidget);
    expect(find.text('Geofence and biometric verified'), findsOneWidget);
    expect(find.textContaining('Pending'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmation-done')));
    await tester.pumpAndSettle();

    expect(find.text('Official events'), findsOneWidget);
  });

  testWidgets('offline check-in is stored locally and syncs when online', (
    tester,
  ) async {
    await tester.pumpWidget(const PeamApp());
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
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
    await tester.pumpWidget(const PeamApp());
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
    await tester.pumpWidget(const PeamApp());
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

Future<void> _loginAsDemo(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login-employee-id')),
    SampleData.demoEmployee.employeeNumber,
  );
  await tester.enterText(
    find.byKey(const Key('login-password')),
    SampleData.demoEmployee.password,
  );
  await tester.ensureVisible(find.byKey(const Key('login-button')));
  await tester.tap(find.byKey(const Key('login-button')));
  await tester.pumpAndSettle();
}
