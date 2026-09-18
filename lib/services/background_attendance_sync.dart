import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../models/models.dart';
import 'attendance_sync_service.dart';
import 'auth_session_store.dart';
import 'sqlite_attendance_database.dart';
import 'supabase_attendance_store.dart';
import 'supabase_config.dart';

/// OS background worker that uploads pending local attendance after the app
/// is closed. Android WorkManager waits for connectivity; iOS runs when the
/// system grants a background processing / fetch window.
class BackgroundAttendanceSync {
  static const oneOffTask = 'com.example.peam.attendanceSync';
  static const periodicTask = 'com.example.peam.attendanceSyncPeriodic';

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize(void Function() callbackDispatcher) async {
    if (!_supported) {
      return;
    }
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (error) {
      debugPrint('PEAM background sync init failed: $error');
    }
  }

  static Future<void> schedulePendingUpload() async {
    if (!_supported) {
      return;
    }
    try {
      await Workmanager().registerOneOffTask(
        oneOffTask,
        oneOffTask,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );
      await Workmanager().registerPeriodicTask(
        periodicTask,
        periodicTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (error) {
      debugPrint('PEAM background sync schedule failed: $error');
    }
  }

  static Future<void> cancel() async {
    if (!_supported) {
      return;
    }
    try {
      await Workmanager().cancelByUniqueName(oneOffTask);
      await Workmanager().cancelByUniqueName(periodicTask);
    } catch (error) {
      debugPrint('PEAM background sync cancel failed: $error');
    }
  }
}

/// Uploads pending SQLite attendance rows to Supabase from a background isolate.
Future<bool> runBackgroundAttendanceSync() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    await SupabaseConfig.load();
    if (!SupabaseConfig.isConfigured) {
      return true;
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
    } catch (_) {
      // Already initialized in this isolate.
    }
    if (Supabase.instance.client.auth.currentSession == null) {
      return true;
    }

    final persisted = await FileAuthSessionStore().readSession();
    if (persisted == null) {
      return true;
    }

    final database = await PeamAttendanceDatabase.open();
    final employee = Employee(
      employeeNumber: persisted.employeeNumber,
      fullName: 'Employee',
      department: const Department(name: '—', code: '—'),
      deviceUid: persisted.deviceUid,
    );
    await const AttendanceSyncService().syncPending(
      local: SqliteAttendanceLocalStore(database),
      remote: SupabaseAttendanceRemoteStore(),
      employee: employee,
    );
    return true;
  } catch (error) {
    debugPrint('PEAM background attendance sync failed: $error');
    return false;
  }
}
