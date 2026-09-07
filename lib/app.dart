import 'package:flutter/material.dart';

import 'screens/biometric_screen.dart';
import 'screens/check_in_screen.dart';
import 'screens/confirmation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifications_screen.dart';
import 'screens/register_screen.dart';
import 'services/push_notification_service.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';

class PeamApp extends StatefulWidget {
  const PeamApp({super.key, this.session, this.pushNotifications});

  final SessionController? session;
  final PushNotificationService? pushNotifications;

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
      child: MaterialApp(
        title: 'PEAM-Registry',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: '/',
        routes: {
          '/': (_) => const LoginScreen(),
          RegisterScreen.routeName: (_) => const RegisterScreen(),
          MainShell.routeName: (_) => const MainShell(),
          CheckInScreen.routeName: (_) => const CheckInScreen(),
          BiometricScreen.routeName: (_) => const BiometricScreen(),
          ConfirmationScreen.routeName: (_) => const ConfirmationScreen(),
          NotificationsScreen.routeName: (_) => const NotificationsScreen(),
        },
      ),
    );
  }
}
