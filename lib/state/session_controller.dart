import 'package:flutter/foundation.dart';

import '../data/sample_data.dart';
import '../data/sample_notifications.dart';
import '../models/app_notification.dart';
import '../models/models.dart';
import '../services/attendance_stores.dart';
import '../services/attendance_sync_service.dart';
import '../services/auth_session_store.dart';
import '../services/client_ids.dart';
import '../services/connectivity_controller.dart';
import '../services/email_mask.dart';
import '../services/employee_auth_api.dart';
import '../services/push_notification_service.dart';

export 'session_scope.dart';

class LoginChallenge {
  const LoginChallenge({
    required this.employeeNumber,
    required this.maskedEmail,
  });

  final String employeeNumber;
  final String maskedEmail;
}

class SessionController extends ChangeNotifier {
  SessionController({
    PushNotificationService? pushNotifications,
    AttendanceLocalStore? localStore,
    AttendanceRemoteStore? remoteStore,
    ConnectivityController? connectivity,
    AttendanceSyncService syncService = const AttendanceSyncService(),
    AuthSessionStore? authStore,
    EmployeeAuthApi? liveAuth,
    this._prototypeEmailCode = SampleData.prototypeEmailCode,
  }) : _remoteAuth = liveAuth,
       _push =
           pushNotifications ??
           PushNotificationService(enableSystemBanners: false),
       _local = localStore ?? MemoryAttendanceLocalStore.withDemoSeed(),
       _remote = remoteStore ?? MemoryAttendanceRemoteStore.withDemoSeed(),
       _connectivity = connectivity ?? ConnectivityController(),
       _ownsConnectivity = connectivity == null,
       _sync = syncService,
       _authStore = authStore ?? MemoryAuthSessionStore() {
    _accounts = [SampleData.demoEmployee];
    _notifications = List.of(SampleNotifications.seed);
    _connectivity.addListener(_onConnectivityChanged);
  }

  final PushNotificationService _push;
  final AttendanceLocalStore _local;
  final AttendanceRemoteStore _remote;
  final ConnectivityController _connectivity;
  final AttendanceSyncService _sync;
  final AuthSessionStore _authStore;
  final EmployeeAuthApi? _remoteAuth;
  final String _prototypeEmailCode;
  final bool _ownsConnectivity;

  late List<Employee> _accounts;
  LoginChallenge? pendingChallenge;
  bool deviceChangeRequired = false;
  String? _deviceChangeTicket;
  bool get isLiveAuth => _remoteAuth != null;
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

  Employee? _accountFor(String employeeNumber) {
    final needle = employeeNumber.trim().toLowerCase();
    for (final account in _accounts) {
      if (account.employeeNumber.toLowerCase() == needle) {
        return account;
      }
    }
    return null;
  }

  void _replaceAccount(Employee updated) {
    _accounts = [
      for (final account in _accounts)
        if (account.employeeNumber.toLowerCase() ==
            updated.employeeNumber.toLowerCase())
          updated
        else
          account,
    ];
  }

  void _refreshDirectoryFromSample() {
    final fresh = SampleData.demoEmployee;
    final existing = _accountFor(fresh.employeeNumber);
    if (existing == null) {
      _accounts = [fresh, ..._accounts];
      return;
    }
    _replaceAccount(
      fresh.copyWith(
        deviceUid: existing.deviceUid,
        deviceName: existing.deviceName,
        phone: existing.phone,
      ),
    );
  }

  Future<void> restoreSession() async {
    _refreshDirectoryFromSample();
    await _applyStoredBindings();
    final deviceUid = await _authStore.deviceUid();
    if (_remoteAuth != null) {
      final restored = await _remoteAuth.restore(deviceUid: deviceUid);
      if (restored == null) {
        await _authStore.clearSession();
        return;
      }
      employee = restored;
      await _authStore.saveBinding(
        employeeNumber: restored.employeeNumber,
        deviceUid: deviceUid,
      );
      await _authStore.saveSession(
        employeeNumber: restored.employeeNumber,
        deviceUid: deviceUid,
      );
      await _reloadHistory();
      return;
    }
    final session = await _authStore.readSession();
    if (session == null) {
      return;
    }
    if (session.deviceUid != deviceUid) {
      await _authStore.clearSession();
      return;
    }
    final account = _accountFor(session.employeeNumber);
    final boundUid = await _authStore.bindingFor(session.employeeNumber);
    if (account == null || boundUid != deviceUid) {
      await _authStore.clearSession();
      return;
    }
    employee = account.copyWith(deviceUid: deviceUid);
    await _reloadHistory();
  }

  Future<void> _applyStoredBindings() async {
    final next = <Employee>[];
    for (final account in _accounts) {
      final boundUid = await _authStore.bindingFor(account.employeeNumber);
      if (boundUid == null) {
        next.add(account);
        continue;
      }
      next.add(
        account.copyWith(
          deviceUid: boundUid,
          deviceName: boundUid == await _authStore.deviceUid()
              ? _describeThisPhone()
              : 'Bound to another phone',
        ),
      );
    }
    _accounts = next;
  }

  Future<String?> requestLoginCode(String employeeNumber) async {
    pendingChallenge = null;
    deviceChangeRequired = false;
    _deviceChangeTicket = null;
    if (_remoteAuth != null) {
      final result = await _remoteAuth.requestCode(employeeNumber);
      if (result.error != null) {
        notifyListeners();
        return result.error;
      }
      pendingChallenge = LoginChallenge(
        employeeNumber: result.challenge!.employeeNumber,
        maskedEmail: result.challenge!.maskedEmail,
      );
      notifyListeners();
      return null;
    }
    _refreshDirectoryFromSample();
    final account = _accountFor(employeeNumber);
    if (account == null) {
      notifyListeners();
      return 'This Employee ID is not on file. Ask HRMDO to create your account.';
    }
    final email = account.workEmail;
    if (!account.hasWorkEmail) {
      notifyListeners();
      return 'This account has no work email on file. Ask HRMDO to add one.';
    }
    pendingChallenge = LoginChallenge(
      employeeNumber: account.employeeNumber,
      maskedEmail: maskEmail(email),
    );
    notifyListeners();
    return null;
  }

  Future<String?> verifyLoginCode(String code) async {
    final challenge = pendingChallenge;
    if (challenge == null) {
      return 'Enter your Employee ID first so a code can be sent.';
    }
    if (_remoteAuth != null) {
      final deviceUid = await _authStore.deviceUid();
      final result = await _remoteAuth.verifyCode(
        employeeNumber: challenge.employeeNumber,
        token: code,
        deviceUid: deviceUid,
        deviceName: _describeThisPhone(),
        platform: _platformName(),
      );
      if (result.deviceChangeRequired) {
        deviceChangeRequired = true;
        _deviceChangeTicket = result.changeTicket;
        notifyListeners();
        return result.error;
      }
      if (result.error != null || result.employee == null) {
        return result.error ??
            'That code is incorrect or has expired. Try again.';
      }
      return _acceptEmployee(result.employee!);
    }
    if (code.trim() != _prototypeEmailCode) {
      return 'That code is incorrect or has expired. Try again.';
    }

    final account = _accountFor(challenge.employeeNumber);
    if (account == null) {
      return 'This Employee ID is not on file. Ask HRMDO to create your account.';
    }

    final deviceUid = await _authStore.deviceUid();
    final boundUid = await _authStore.bindingFor(account.employeeNumber);
    if (boundUid != null && boundUid != deviceUid) {
      deviceChangeRequired = true;
      notifyListeners();
      return 'This account is already bound to another phone. Submit a device-change request for HR approval.';
    }

    final bound = account.copyWith(
      deviceUid: deviceUid,
      deviceName: _describeThisPhone(),
    );
    return _acceptEmployee(bound);
  }

  Future<String?> _acceptEmployee(Employee bound) async {
    final deviceUid = bound.deviceUid ?? await _authStore.deviceUid();
    _replaceAccount(bound);
    employee = bound;
    pendingChallenge = null;
    deviceChangeRequired = false;
    _deviceChangeTicket = null;
    await _authStore.saveBinding(
      employeeNumber: bound.employeeNumber,
      deviceUid: deviceUid,
    );
    await _authStore.saveSession(
      employeeNumber: bound.employeeNumber,
      deviceUid: deviceUid,
    );
    await _reloadHistory();
    return null;
  }

  /// Test and evaluation helper: Employee ID + prototype email code.
  Future<String?> completePrototypeLogin(String employeeNumber) async {
    final requestError = await requestLoginCode(employeeNumber);
    if (requestError != null) {
      return requestError;
    }
    return verifyLoginCode(_prototypeEmailCode);
  }

  void clearLoginChallenge() {
    pendingChallenge = null;
    deviceChangeRequired = false;
    _deviceChangeTicket = null;
    notifyListeners();
  }

  Future<String?> requestDeviceChange({
    String reason = 'I need to use a new phone for attendance.',
  }) async {
    if (_remoteAuth != null) {
      final ticket = _deviceChangeTicket;
      if (ticket == null) {
        return 'Verify the email code first, then submit the device-change request.';
      }
      final error = await _remoteAuth.submitDeviceChange(
        ticket: ticket,
        reason: reason,
      );
      if (error != null) {
        return error;
      }
      deviceChangeRequired = false;
      pendingChallenge = null;
      _deviceChangeTicket = null;
      await addNotification(
        title: 'Device-change request sent',
        body:
            'HRMDO will review the request to bind this phone. You can use PEAM on this device after approval.',
        kind: NotificationKind.deviceChangeUpdate,
      );
      return null;
    }
    final challenge = pendingChallenge;
    if (challenge == null) {
      return 'Enter your Employee ID and email code first.';
    }
    final deviceUid = await _authStore.deviceUid();
    await _authStore.savePendingDeviceChange(
      PendingDeviceChange(
        employeeNumber: challenge.employeeNumber,
        newDeviceUid: deviceUid,
        reason: reason,
      ),
    );
    deviceChangeRequired = false;
    pendingChallenge = null;
    await addNotification(
      title: 'Device-change request sent',
      body:
          'HRMDO will review the request to bind this phone. You can use PEAM on this device after approval.',
      kind: NotificationKind.deviceChangeUpdate,
    );
    return null;
  }

  Future<void> logout() async {
    await _remoteAuth?.signOut();
    await _authStore.clearSession();
    employee = null;
    pendingChallenge = null;
    deviceChangeRequired = false;
    _deviceChangeTicket = null;
    selectedEvent = null;
    lastAttendance = null;
    _history = const [];
    remoteRecordCount = 0;
    searchQuery = '';
    statusFilter = null;
    notifyListeners();
  }

  String _describeThisPhone() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.android => 'Android phone',
      _ => 'This device',
    };
  }

  String _platformName() {
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
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
