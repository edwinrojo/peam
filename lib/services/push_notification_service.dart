import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Prototype stand-in for FCM push delivery using local system notifications.
/// Real production delivery will use Firebase Cloud Messaging + Supabase.
class PushNotificationService {
  PushNotificationService({this.enableSystemBanners = true});

  final bool enableSystemBanners;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  int _nextId = 1000;

  bool get isReady => _ready;

  Future<void> init() async {
    if (!enableSystemBanners || kIsWeb) {
      return;
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      await _plugin.initialize(settings: settings);

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();

      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> showBanner({required String title, required String body}) async {
    if (!_ready) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'peam_attendance',
      'PEAM Attendance',
      channelDescription: 'Prototype push notifications for PEAM-Registry',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
