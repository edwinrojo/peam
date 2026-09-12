import 'package:flutter/material.dart';

import 'app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/attendance_stores.dart';
import 'services/auth_session_store.dart';
import 'services/biometric_auth_service.dart';
import 'services/connectivity_controller.dart';
import 'services/employee_auth_api.dart';
import 'services/push_notification_service.dart';
import 'services/sqlite_attendance_database.dart';
import 'services/supabase_config.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final pushNotifications = PushNotificationService();
  await pushNotifications.init();

  final connectivity = ConnectivityController(listenToDevice: true);
  await connectivity.start();

  await SupabaseConfig.load();

  EmployeeAuthApi? remoteAuth;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    remoteAuth = EmployeeAuthApi();
  }

  late final AttendanceLocalStore localStore;
  late final AttendanceRemoteStore remoteStore;
  try {
    final database = await PeamAttendanceDatabase.open();
    await database.seedDemoIfEmpty();
    localStore = SqliteAttendanceLocalStore(database);
    remoteStore = SqliteAttendanceRemoteStore(database);
  } catch (_) {
    localStore = MemoryAttendanceLocalStore.withDemoSeed();
    remoteStore = MemoryAttendanceRemoteStore.withDemoSeed();
  }

  runApp(
    PeamApp(
      pushNotifications: pushNotifications,
      biometricAuth: DeviceBiometricAuthService(),
      session: SessionController(
        pushNotifications: pushNotifications,
        localStore: localStore,
        remoteStore: remoteStore,
        connectivity: connectivity,
        authStore: FileAuthSessionStore(),
        liveAuth: remoteAuth,
      ),
    ),
  );
}
