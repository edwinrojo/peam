import 'package:flutter/foundation.dart';

import '../data/sample_data.dart';
import '../data/sample_notifications.dart';
import '../models/app_notification.dart';
import '../models/models.dart';
import '../services/attendance_stores.dart';
import '../services/attendance_sync_service.dart';
import '../services/client_ids.dart';
import '../services/connectivity_controller.dart';
import '../services/push_notification_service.dart';

export 'session_scope.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    PushNotificationService? pushNotifications,
    AttendanceLocalStore? localStore,
    AttendanceRemoteStore? remoteStore,
    ConnectivityController? connectivity,
    AttendanceSyncService syncService = const AttendanceSyncService(),
  }) : _push =
           pushNotifications ??
           PushNotificationService(enableSystemBanners: false),
       _local = localStore ?? MemoryAttendanceLocalStore.withDemoSeed(),
       _remote = remoteStore ?? MemoryAttendanceRemoteStore.withDemoSeed(),
       _connectivity = connectivity ?? ConnectivityController(),
       _ownsConnectivity = connectivity == null,
       _sync = syncService {
    _accounts = [SampleData.demoEmployee];
    _notifications = List.of(SampleNotifications.seed);
    _connectivity.addListener(_onConnectivityChanged);
  }

  final PushNotificationService _push;
  final AttendanceLocalStore _local;
  final AttendanceRemoteStore _remote;
  final ConnectivityController _connectivity;
  final AttendanceSyncService _sync;
  final bool _ownsConnectivity;

  late List<Employee> _accounts;
  Employee? employee;
  ProvincialEvent? selectedEvent;
  AttendanceRecord? lastAttendance;
  List<AttendanceRecord> _history = const [];
  late List<AppNotification> _notifications;
  String searchQuery = '';
  EventStatus? statusFilter;
  int remoteRecordCount = 0;
  bool isSyncing = false;

  List<Employee> get accounts => List.unmodifiable(_accounts);
  List<AttendanceRecord> get history => List.unmodifiable(_history);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationCount =>
      _notifications.where((item) => !item.isRead).length;
  bool get isOnline => _connectivity.isOnline;
  bool get deviceHasNetwork => _connectivity.deviceHasNetwork;
  int get pendingCount => _history.where((record) => record.isPending).length;

  AttendanceRecord? recordFor(String eventId) {
    for (final record in _history) {
      if (record.event.id == eventId) {
        return record;
      }
    }
    return null;
  }

  List<ProvincialEvent> get visibleEvents {
    final query = searchQuery.trim().toLowerCase();
    return SampleData.events.where((event) {
      final matchesStatus =
          statusFilter == null || event.status == statusFilter;
      final matchesQuery =
          query.isEmpty ||
          event.name.toLowerCase().contains(query) ||
          event.venue.toLowerCase().contains(query);
      return matchesStatus &&
          matchesQuery &&
          event.status != EventStatus.draft &&
          event.status != EventStatus.cancelled;
    }).toList();
  }

  Future<String?> login({
    required String employeeNumber,
    required String password,
  }) async {
    final match = _accounts.cast<Employee?>().firstWhere(
      (account) =>
          account!.employeeNumber.toLowerCase() ==
              employeeNumber.trim().toLowerCase() &&
          account.password == password,
      orElse: () => null,
    );
    if (match == null) {
      return 'Employee ID or password is incorrect.';
    }
    employee = match;
    await _reloadHistory();
    return null;
  }

  Future<String?> register({
    required String fullName,
    required String employeeNumber,
    required String password,
    required Department department,
    String? phone,
  }) async {
    if (_accounts.any(
      (account) =>
          account.employeeNumber.toLowerCase() ==
          employeeNumber.trim().toLowerCase(),
    )) {
      return 'This Employee ID is already registered.';
    }

    final created = Employee(
      employeeNumber: employeeNumber.trim().toUpperCase(),
      fullName: fullName.trim(),
      password: password,
      department: department,
      phone: phone,
      deviceName: 'Registered prototype device',
    );
    _accounts = [..._accounts, created];
    employee = created;
    await _reloadHistory();
    return null;
  }

  void logout() {
    employee = null;
    selectedEvent = null;
    lastAttendance = null;
    _history = const [];
    remoteRecordCount = 0;
    searchQuery = '';
    statusFilter = null;
    notifyListeners();
  }

  void updateSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void updateStatusFilter(EventStatus? value) {
    statusFilter = value;
    notifyListeners();
  }

  void selectEvent(ProvincialEvent event) {
    selectedEvent = event;
    notifyListeners();
  }

  void simulateOffline() {
    _connectivity.simulateOffline();
  }

  Future<int> simulateOnlineAndSync() async {
    _connectivity.simulateOnline();
    return syncPending();
  }

  Future<void> confirmAttendance({required DateTime checkInAt}) async {
    final currentEmployee = employee;
    final event = selectedEvent;
    if (currentEmployee == null || event == null) {
      return;
    }

    final existing = await _local.find(
      eventId: event.id,
      employee: currentEmployee,
    );
    if (existing != null) {
      lastAttendance = existing;
      await _reloadHistory();
      return;
    }

    final recordedOffline = !_connectivity.isOnline;
    final record = AttendanceRecord(
      clientRecordId: newClientRecordId(),
      event: event,
      employee: currentEmployee,
      checkInAt: checkInAt,
      checkInLatitude: event.location.latitude,
      checkInLongitude: event.location.longitude,
      recordedOffline: recordedOffline,
      geofenceVerified: true,
      biometricVerified: true,
      verificationStatus: VerificationStatus.verified,
      attendanceStatus: AttendanceStatus.incomplete,
      syncStatus: SyncStatus.pending,
      clientRecordedAt: checkInAt,
    );
    await _local.upsert(record);
    lastAttendance = record;
    await _reloadHistory();
    await addNotification(
      title: recordedOffline
          ? 'Attendance recorded offline'
          : 'Attendance saved on device',
      body: recordedOffline
          ? 'Your check-in for ${event.name} is saved on this device and will sync when connectivity returns.'
          : 'Your check-in for ${event.name} is stored locally and will upload to Supabase.',
      kind: NotificationKind.attendanceSync,
      showSystemBanner: true,
    );
    if (_connectivity.isOnline) {
      await syncPending();
    }
  }

  Future<int> syncPending() async {
    final currentEmployee = employee;
    if (currentEmployee == null || !_connectivity.isOnline || isSyncing) {
      return 0;
    }

    isSyncing = true;
    notifyListeners();
    try {
      final uploaded = await _sync.syncPending(
        local: _local,
        remote: _remote,
        employee: currentEmployee,
      );
      await _reloadHistory();
      if (lastAttendance != null) {
        lastAttendance = recordFor(lastAttendance!.event.id) ?? lastAttendance;
      }
      if (uploaded > 0) {
        await addNotification(
          title: 'Attendance synced',
          body: uploaded == 1
              ? '1 pending attendance record was uploaded to Supabase.'
              : '$uploaded pending attendance records were uploaded to Supabase.',
          kind: NotificationKind.attendanceSync,
          showSystemBanner: true,
        );
      }
      return uploaded;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  void markNotificationRead(String id) {
    _notifications = [
      for (final item in _notifications)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
    notifyListeners();
  }

  void markAllNotificationsRead() {
    _notifications = [
      for (final item in _notifications) item.copyWith(isRead: true),
    ];
    notifyListeners();
  }

  Future<void> simulateIncomingPush({
    NotificationKind kind = NotificationKind.eventPublished,
  }) async {
    final payload = switch (kind) {
      NotificationKind.eventPublished => (
        title: 'New event published',
        body:
            'Disaster Preparedness Training is now published for September 12 at Magsaysay Covered Court.',
      ),
      NotificationKind.eventReminder => (
        title: 'Event reminder',
        body:
            'Midyear Financial Briefing starts in 30 minutes at the PGO Conference Hall.',
      ),
      NotificationKind.deviceChangeUpdate => (
        title: 'Device-change request update',
        body: 'HR reviewed your device-change request. Open PEAM for details.',
      ),
      NotificationKind.attendanceSync => (
        title: 'Attendance synced',
        body: 'Pending offline attendance records were uploaded to Supabase.',
      ),
      NotificationKind.adminNotice => (
        title: 'PEAM notice',
        body: 'Please keep your registered device nearby for event check-in.',
      ),
    };

    await addNotification(
      title: payload.title,
      body: payload.body,
      kind: kind,
      showSystemBanner: true,
    );
  }

  Future<void> addNotification({
    required String title,
    required String body,
    required NotificationKind kind,
    bool showSystemBanner = false,
  }) async {
    final item = AppNotification(
      id: 'n-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      kind: kind,
      createdAt: DateTime.now(),
    );
    _notifications = [item, ..._notifications];
    notifyListeners();

    if (showSystemBanner) {
      await _push.showBanner(title: title, body: body);
    }
  }

  Future<void> _reloadHistory() async {
    final currentEmployee = employee;
    if (currentEmployee == null) {
      _history = const [];
      remoteRecordCount = 0;
      notifyListeners();
      return;
    }
    _history = await _local.listForEmployee(currentEmployee);
    remoteRecordCount = (await _remote.listForEmployee(currentEmployee)).length;
    notifyListeners();
  }

  void _onConnectivityChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    if (_ownsConnectivity) {
      _connectivity.dispose();
    }
    super.dispose();
  }
}
