import 'package:flutter/material.dart';

import 'screens/biometric_screen.dart';
import 'screens/check_in_screen.dart';
import 'screens/confirmation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifications_screen.dart';
import 'services/biometric_auth_service.dart';
import 'services/push_notification_service.dart';
import 'state/biometric_scope.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/peam_logo.dart';

class PeamApp extends StatefulWidget {
  const PeamApp({
    super.key,
    this.session,
    this.pushNotifications,
    this.biometricAuth,
  });

  final SessionController? session;
  final PushNotificationService? pushNotifications;
  final BiometricAuthService? biometricAuth;

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

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await _session.restoreSession();
    if (mounted) {
      setState(() => _ready = true);
    }
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
        child: MaterialApp(
          title: 'PEAM-Registry',
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
