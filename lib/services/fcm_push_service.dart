import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/app_notification.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty &&
      defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  }
}

class FcmPushService {
  FcmPushService({this.enable = true});

  final bool enable;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  Future<void> start({
    required Future<void> Function(String token) onToken,
    required void Function(String payload) onOpened,
    void Function(String title, String body, String? payload)? onForeground,
  }) async {
    if (!enable ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        Firebase.apps.isEmpty) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      debugPrint('PEAM FCM token ready');
      await onToken(token);
    } else {
      debugPrint('PEAM FCM token missing');
    }
    await _tokenSub?.cancel();
    _tokenSub = messaging.onTokenRefresh.listen(onToken);

    final initial = await messaging.getInitialMessage();
    final initialPayload = payloadFor(initial);
    if (initialPayload != null) {
      onOpened(initialPayload);
    }
    await _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = payloadFor(message);
      if (payload != null) {
        onOpened(payload);
      }
    });
    await _foregroundSub?.cancel();
    if (onForeground != null) {
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        final title = notification?.title?.trim();
        if (title == null || title.isEmpty) {
          return;
        }
        onForeground(title, notification?.body ?? '', payloadFor(message));
      });
    }
  }

  Future<void> stop() async {
    await _tokenSub?.cancel();
    await _openedSub?.cancel();
    await _foregroundSub?.cancel();
    _tokenSub = null;
    _openedSub = null;
    _foregroundSub = null;
  }

  static String? payloadFor(RemoteMessage? message) {
    if (message == null || message.data.isEmpty) {
      return null;
    }
    return NotificationPayload.fromRemoteData(message.data)?.encode();
  }
}
