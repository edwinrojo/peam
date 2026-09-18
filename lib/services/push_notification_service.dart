import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// System banners and scheduled event reminders on this device.
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
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }

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
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  Future<void> scheduleBanner({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!_ready || !when.isAfter(DateTime.now())) {
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    if (!_ready) {
      return;
    }
    await _plugin.cancel(id: id);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'peam_attendance',
      'PEAM Attendance',
      channelDescription: 'Event, reminder, and attendance notices for PEAM.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}
