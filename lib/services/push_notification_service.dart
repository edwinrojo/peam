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
  String? _pendingPayload;
  void Function(String payload)? onTap;

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

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          _deliver(response.payload);
        },
      );

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

      try {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          _deliver(launch?.notificationResponse?.payload);
        }
      } catch (_) {}

      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> showBanner({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) {
      return;
    }
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  Future<void> scheduleBanner({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
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
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    if (!_ready) {
      return;
    }
    await _plugin.cancel(id: id);
  }

  String? takePendingPayload() {
    final value = _pendingPayload;
    _pendingPayload = null;
    return value;
  }

  void deliverTap(String payload) {
    _deliver(payload);
  }

  void _deliver(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    final handler = onTap;
    if (handler != null) {
      handler(payload);
      return;
    }
    _pendingPayload = payload;
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
