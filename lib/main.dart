import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/attendance_stores.dart';
import 'services/auth_session_store.dart';
import 'services/background_attendance_sync.dart';
import 'services/biometric_auth_service.dart';
import 'services/connectivity_controller.dart';
import 'services/employee_auth_api.dart';
import 'services/events_catalog.dart';
import 'services/fcm_push_service.dart';
import 'services/live_notification_source.dart';
import 'services/location_service.dart';
import 'services/notification_inbox.dart';
import 'services/push_notification_service.dart';
import 'services/sqlite_attendance_database.dart';
import 'services/supabase_attendance_store.dart';
import 'services/supabase_config.dart';
import 'state/session_controller.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return runBackgroundAttendanceSync();
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  await BackgroundAttendanceSync.initialize(callbackDispatcher);

  final pushNotifications = PushNotificationService();
  await pushNotifications.init();

  final connectivity = ConnectivityController(listenToDevice: true);
  await connectivity.start();

  await SupabaseConfig.load();

  EmployeeAuthApi? remoteAuth;
  EventsCatalog? eventsCatalog;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    remoteAuth = EmployeeAuthApi();
    eventsCatalog = CachedEventsCatalog(
      remote: SupabaseEventsCatalog(),
      cache: FileEventsCache(),
    );
  }

  late final AttendanceLocalStore localStore;
  late final AttendanceRemoteStore remoteStore;
  try {
    final database = await PeamAttendanceDatabase.open();
    if (!SupabaseConfig.isConfigured) {
      await database.seedDemoIfEmpty();
    }
    localStore = SqliteAttendanceLocalStore(database);
    remoteStore = SupabaseConfig.isConfigured
        ? SupabaseAttendanceRemoteStore()
        : SqliteAttendanceRemoteStore(database);
  } catch (_) {
    localStore = MemoryAttendanceLocalStore.withDemoSeed();
    remoteStore = SupabaseConfig.isConfigured
        ? SupabaseAttendanceRemoteStore()
        : MemoryAttendanceRemoteStore.withDemoSeed();
  }

  runApp(
    PeamApp(
      pushNotifications: pushNotifications,
      biometricAuth: DeviceBiometricAuthService(),
      locationService: const DeviceLocationService(),
      session: SessionController(
        pushNotifications: pushNotifications,
        fcmPush: FcmPushService(),
        localStore: localStore,
        remoteStore: remoteStore,
        connectivity: connectivity,
        authStore: FileAuthSessionStore(),
        liveAuth: remoteAuth,
        eventsCatalog: eventsCatalog,
        notificationInbox: FileNotificationInbox(),
        liveNotifications: SupabaseConfig.isConfigured
            ? LiveNotificationSource()
            : null,
      ),
    ),
  );
}

Future<void> _initializeFirebase() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error) {
    debugPrint('PEAM Firebase init skipped: $error');
  }
}
