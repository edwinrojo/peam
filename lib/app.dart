import 'dart:async';

import 'package:flutter/material.dart';

import 'navigation/notification_tap.dart';
import 'screens/biometric_screen.dart';
import 'screens/check_in_screen.dart';
import 'screens/confirmation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifications_screen.dart';
import 'services/biometric_auth_service.dart';
import 'services/location_service.dart';
import 'services/push_notification_service.dart';
import 'state/biometric_scope.dart';
import 'state/location_scope.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/peam_logo.dart';

class PeamApp extends StatefulWidget {
  const PeamApp({
    super.key,
    this.session,
    this.pushNotifications,
    this.biometricAuth,
    this.locationService,
  });

  final SessionController? session;
  final PushNotificationService? pushNotifications;
  final BiometricAuthService? biometricAuth;
  final LocationService? locationService;

  @override
  State<PeamApp> createState() => _PeamAppState();
}

class _PeamAppState extends State<PeamApp> {
  late final SessionController _session =
      widget.session ??
      SessionController(
        pushNotifications:
            widget.pushNotifications ??
            PushNotificationService(enableSystemBanners: false),
      );

  late final BiometricAuthService _biometricAuth =
      widget.biometricAuth ?? const StubBiometricAuthService();

  late final LocationService _locationService =
      widget.locationService ?? const StubLocationService();

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _session.listenForOsNotificationTaps(_onOsNotificationTap);
    _restore();
  }

  void _onOsNotificationTap(String payload) {
    unawaited(openNotificationPayload(session: _session, payload: payload));
  }

  Future<void> _restore() async {
    await _session.restoreSession();
    if (!mounted) {
      return;
    }
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(flushPendingNotificationTap(_session));
    });
  }

  @override
  void dispose() {
    if (widget.session == null) {
      _session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _session,
      child: BiometricAuthScope(
        service: _biometricAuth,
        child: LocationScope(
          service: _locationService,
          child: MaterialApp(
            title: 'PEAM-Registry',
            navigatorKey: _session.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: !_ready
                ? const _SessionRestoreScreen()
                : _session.employee != null
                ? const MainShell()
                : const LoginScreen(),
            routes: {
              MainShell.routeName: (_) => const MainShell(),
              CheckInScreen.routeName: (_) => const CheckInScreen(),
              BiometricScreen.routeName: (_) => const BiometricScreen(),
              ConfirmationScreen.routeName: (_) => const ConfirmationScreen(),
              NotificationsScreen.routeName: (_) => const NotificationsScreen(),
            },
          ),
        ),
      ),
    );
  }
}

class _SessionRestoreScreen extends StatelessWidget {
  const _SessionRestoreScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PeamLogo(showWordmark: true, size: 56),
            SizedBox(height: 16),
            Text('Opening PEAM…'),
          ],
        ),
      ),
    );
  }
}
