import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/sample_data.dart';
import '../models/app_notification.dart';
import '../models/models.dart';
import '../services/attendance_integrity.dart';
import '../services/attendance_stores.dart';
import '../services/attendance_sync_service.dart';
import '../services/auth_session_store.dart';
import '../services/background_attendance_sync.dart';
import '../services/client_ids.dart';
import '../services/connectivity_controller.dart';
import '../services/device_guard.dart';
import '../services/email_mask.dart';
import '../services/employee_auth_api.dart';
import '../services/events_catalog.dart';
import '../services/fcm_push_service.dart';
import '../services/geofence.dart';
import '../services/live_notification_source.dart';
import '../services/notification_feed.dart';
import '../services/notification_inbox.dart';
import '../services/push_notification_service.dart';
import '../services/trusted_clock.dart';

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
    EventsCatalog? eventsCatalog,
    NotificationInbox? notificationInbox,
    FcmPushService? fcmPush,
    GlobalKey<NavigatorState>? navigatorKey,
    DeviceGuard? deviceGuard,
    TrustedClock? trustedClock,
    AttendanceIntegrityApi? integrityApi,
    this._liveNotifications,
    this._prototypeEmailCode = SampleData.prototypeEmailCode,
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
       _guard = deviceGuard ?? StubDeviceGuard(),
       _clock = trustedClock,
       _integrity = integrityApi,
       _remoteAuth = liveAuth,
       _eventsCatalog = eventsCatalog,
       _events = eventsCatalog == null ? List.of(SampleData.events) : const [],
       _push =
           pushNotifications ??
           PushNotificationService(enableSystemBanners: false),
       _local = localStore ?? MemoryAttendanceLocalStore.withDemoSeed(),
       _remote = remoteStore ?? MemoryAttendanceRemoteStore.withDemoSeed(),
       _connectivity = connectivity ?? ConnectivityController(),
       _ownsConnectivity = connectivity == null,
       _sync = syncService,
       _authStore = authStore ?? MemoryAuthSessionStore(),
       _inbox = notificationInbox ?? MemoryNotificationInbox(),
       _fcm = fcmPush {
    _accounts = [SampleData.demoEmployee];
    _notifications = const [];
    _connectivity.addListener(_onConnectivityChanged);
  }

  final PushNotificationService _push;
  final AttendanceLocalStore _local;
  final AttendanceRemoteStore _remote;
  final ConnectivityController _connectivity;
  final AttendanceSyncService _sync;
  final AuthSessionStore _authStore;
  final EmployeeAuthApi? _remoteAuth;
  final EventsCatalog? _eventsCatalog;
  final NotificationInbox _inbox;
  final FcmPushService? _fcm;
  final LiveNotificationSource? _liveNotifications;
  final DeviceGuard _guard;
  final TrustedClock? _clock;
  final AttendanceIntegrityApi? _integrity;
  final Set<String> _integrityAttempted = {};
  final String _prototypeEmailCode;
  final bool _ownsConnectivity;
  final GlobalKey<NavigatorState> navigatorKey;

  late List<Employee> _accounts;
  List<ProvincialEvent> _events;
  LoginChallenge? pendingChallenge;
  bool deviceChangeRequired = false;
  String? _deviceChangeTicket;
  bool get isLiveAuth => _remoteAuth != null;
  Employee? employee;
  ProvincialEvent? selectedEvent;
  AttendanceRecord? lastAttendance;
  List<AttendanceRecord> _history = const [];
  late List<AppNotification> _notifications;
  NotificationSnapshot _noticeSnapshot = const NotificationSnapshot();
  String searchQuery = '';
  EventStatus? statusFilter;
  int remoteRecordCount = 0;
  bool isSyncing = false;
  bool isLoadingEvents = false;
  String? eventsError;
  GeofenceCheck? stagedGeofence;
  AttendanceAction pendingAttendanceAction = AttendanceAction.checkIn;
  int shellTab = 0;
  bool _disposed = false;
  Future<int>? _syncInFlight;
  String? _heldNotificationPayload;

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

  ProvincialEvent? eventById(String id) {
    for (final event in _events) {
      if (event.id == id) {
        return event;
      }
    }
    return null;
  }

  void selectShellTab(int index) {
    final next = index.clamp(0, 2);
    if (shellTab == next) {
      return;
    }
    shellTab = next;
    notifyListeners();
  }

  void holdNotificationPayload(String payload) {
    _heldNotificationPayload = payload;
  }

  String? consumePendingOsPayload() {
    final held = _heldNotificationPayload;
    _heldNotificationPayload = null;
    return held ?? _push.takePendingPayload();
  }

  void listenForOsNotificationTaps(void Function(String payload) onTap) {
    _push.onTap = onTap;
  }

  /// Home registers this so a root back can close search before exit.
  bool Function()? onHomeBack;

  List<ProvincialEvent> get visibleEvents => eventsMatching();

  List<ProvincialEvent> eventsMatching({bool ignoreStatusFilter = false}) {
    final query = searchQuery.trim().toLowerCase();
    final skipStatus = ignoreStatusFilter || query.isNotEmpty;
    return _events.where((event) {
      final matchesStatus =
          skipStatus ||
          statusFilter == null ||
          event.effectiveStatus() == statusFilter;
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
      final cached = await _cachedEmployee(deviceUid);
      if (cached != null) {
        await _enterOfflineSession(cached);
        unawaited(_refreshRemoteSession(deviceUid));
        return;
      }
      try {
        final restored = await _remoteAuth
            .restore(deviceUid: deviceUid)
            .timeout(const Duration(seconds: 8));
        if (restored == null) {
          return;
        }
        await _rememberEmployee(restored, deviceUid);
        await _enterOfflineSession(restored);
        unawaited(_refreshRemoteSession(deviceUid, skipRestore: true));
      } on AuthBindingException {
        await _authStore.clearSession();
      } catch (error) {
        debugPrint('PEAM session restore skipped: $error');
      }
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
    await _loadInbox();
    await _reloadHistory();
    await refreshEvents();
    await _syncWhenOnline();
    await _scheduleBackgroundSyncIfNeeded();
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
      return 'This Employee ID is not on file. Ask PHRMO to create your account.';
    }
    final email = account.workEmail;
    if (!account.hasWorkEmail) {
      notifyListeners();
      return 'This account has no work email on file. Ask PHRMO to add one.';
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
      return 'This Employee ID is not on file. Ask PHRMO to create your account.';
    }

    final deviceUid = await _authStore.deviceUid();
    final boundUid = await _authStore.bindingFor(account.employeeNumber);
    if (boundUid != null && boundUid != deviceUid) {
      deviceChangeRequired = true;
      notifyListeners();
      return 'This account is already registered on another phone. Ask PHRMO to approve this phone.';
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
    await _guard.resetBioGuard();
    await _authStore.saveBinding(
      employeeNumber: bound.employeeNumber,
      deviceUid: deviceUid,
    );
    await _authStore.saveSession(
      employeeNumber: bound.employeeNumber,
      deviceUid: deviceUid,
    );
    await _authStore.saveEmployee(bound);
    await _loadInbox();
    await _reloadHistory();
    await refreshEvents();
    await _syncWhenOnline();
    await _scheduleBackgroundSyncIfNeeded();
    await _startLiveNotices();
    await _startFcm();
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
        return 'Enter the email code first, then ask PHRMO to approve this phone.';
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
            'PHRMO will review your request to use this phone. You can sign in here after they approve it.',
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
          'PHRMO will review your request to use this phone. You can sign in here after they approve it.',
      kind: NotificationKind.deviceChangeUpdate,
    );
    return null;
  }

  Future<void> logout() async {
    await _fcm?.stop();
    await _liveNotifications?.stop();
    await _persistInbox();
    await _remoteAuth?.signOut();
    await BackgroundAttendanceSync.cancel();
    await _authStore.clearSession();
    employee = null;
    pendingChallenge = null;
    deviceChangeRequired = false;
    _deviceChangeTicket = null;
    selectedEvent = null;
    lastAttendance = null;
    _history = const [];
    _notifications = const [];
    _noticeSnapshot = const NotificationSnapshot();
    remoteRecordCount = 0;
    searchQuery = '';
    statusFilter = null;
    eventsError = null;
    stagedGeofence = null;
    shellTab = 0;
    _heldNotificationPayload = null;
    onHomeBack = null;
    if (_eventsCatalog != null) {
      _events = const [];
    }
    notifyListeners();
  }

  String _describeThisPhone() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.android => 'Android phone',
      _ => 'This phone',
    };
  }

  String _platformName() {
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  Future<void> refreshEvents() async {
    final catalog = _eventsCatalog;
    if (catalog == null) {
      _events = List.of(SampleData.events);
      eventsError = null;
      isLoadingEvents = false;
      notifyListeners();
      await _ingestEventNotices();
      return;
    }

    isLoadingEvents = true;
    notifyListeners();
    var ingest = true;
    try {
      _events = await catalog.listVisible();
      eventsError = null;
    } catch (_) {
      if (_events.isEmpty) {
        eventsError = 'Could not load events. Pull down to try again.';
        ingest = false;
      } else {
        eventsError = 'Could not refresh events. Showing the last list.';
      }
    } finally {
      isLoadingEvents = false;
      notifyListeners();
    }
    if (ingest) {
      await _ingestEventNotices();
    }
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

  void stageGeofence(GeofenceCheck? check) {
    stagedGeofence = check;
  }

  void stageAttendanceAction(AttendanceAction action) {
    pendingAttendanceAction = action;
  }

  void simulateOffline() {
    _connectivity.simulateOffline();
  }

  Future<int> simulateOnlineAndSync() async {
    _connectivity.simulateOnline();
    return syncPending();
  }

  Future<void> refreshAttendance() async {
    if (_connectivity.isOnline) {
      await syncPending();
    }
    await _reloadHistory();
  }

  /// Whether the biometric guard key still exists. `changed` means a new
  /// fingerprint was enrolled since the employee last signed in.
  Future<BioGuardState> biometricGuardState() => _guard.bioGuardState();

  Future<void> armBiometricGuardIfMissing() async {
    if (await _guard.bioGuardState() == BioGuardState.missing) {
      await _guard.armBioGuard();
    }
  }

  /// [at] overrides the clock (tests); its source is reported as the phone clock.
  Future<TrustedTime> _attendanceTime(DateTime? at) async {
    if (at != null) {
      return TrustedTime(at, TimeSource.deviceClock);
    }
    return await _clock?.now() ??
        TrustedTime(DateTime.now(), TimeSource.deviceClock);
  }

  Future<void> confirmAttendance({DateTime? checkInAt}) async {
    final currentEmployee = employee;
    final event = selectedEvent;
    if (currentEmployee == null || event == null) {
      return;
    }

    final time = await _attendanceTime(checkInAt);
    final checkedInAt = time.at;
    if (!event.allowsCheckIn(checkedInAt)) {
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

    final staged = stagedGeofence;
    if (staged != null && !staged.allowsAttendance) {
      return;
    }

    final recordedOffline = !_connectivity.isOnline;
    final record = AttendanceRecord(
      clientRecordId: newClientRecordId(),
      event: event,
      employee: currentEmployee,
      checkInAt: checkedInAt,
      checkInLatitude: staged?.position.latitude ?? event.location.latitude,
      checkInLongitude: staged?.position.longitude ?? event.location.longitude,
      checkInAccuracyMeters: staged?.position.accuracyMeters,
      checkInMocked: staged?.position.isMocked ?? false,
      checkInStatic: staged?.position.isStatic ?? false,
      checkInTimeSource: time.source,
      recordedOffline: recordedOffline,
      geofenceVerified: staged?.isInside ?? true,
      biometricVerified: true,
      verificationStatus: VerificationStatus.verified,
      attendanceStatus: event.requiresCheckOut
          ? AttendanceStatus.incomplete
          : AttendanceStatus.present,
      syncStatus: SyncStatus.pending,
      clientRecordedAt: checkedInAt,
    );
    try {
      await _local.upsert(record);
    } catch (error) {
      debugPrint('PEAM local attendance save failed: $error');
      return;
    }
    lastAttendance = record;
    stagedGeofence = null;
    _history = [
      record,
      for (final item in _history)
        if (item.event.id != record.event.id) item,
    ];
    _notify();
    await addNotification(
      title: recordedOffline
          ? 'Check-in saved on this phone'
          : 'Check-in saved',
      body: recordedOffline
          ? 'Your check-in for ${event.name} is on this phone. PHRMO will see it when you have internet.'
          : 'Your check-in for ${event.name} will be sent to PHRMO.',
      kind: NotificationKind.attendanceSync,
      eventId: event.id,
      showSystemBanner: true,
    );
    try {
      await _syncWhenOnline();
    } catch (error) {
      debugPrint('PEAM attendance upload failed: $error');
    }
    await _scheduleBackgroundSyncIfNeeded();
    await _reloadHistory();
  }

  Future<void> confirmCheckOut({DateTime? checkOutAt}) async {
    final currentEmployee = employee;
    final event = selectedEvent;
    if (currentEmployee == null || event == null) {
      return;
    }
    if (!event.allowsCheckOut()) {
      return;
    }
    final time = await _attendanceTime(checkOutAt);
    final checkedOutAt = time.at;

    final existing = await _local.find(
      eventId: event.id,
      employee: currentEmployee,
    );
    if (existing == null || existing.checkOutAt != null) {
      lastAttendance = existing;
      await _reloadHistory();
      return;
    }
    if (checkedOutAt.isBefore(existing.checkInAt)) {
      return;
    }

    final staged = stagedGeofence;
    if (staged != null && !staged.allowsAttendance) {
      return;
    }

    final recordedOffline = existing.recordedOffline || !_connectivity.isOnline;
    final record = existing.copyWith(
      event: event,
      checkOutAt: checkedOutAt,
      checkOutLatitude: staged?.position.latitude ?? event.location.latitude,
      checkOutLongitude: staged?.position.longitude ?? event.location.longitude,
      checkOutAccuracyMeters: staged?.position.accuracyMeters,
      checkOutMocked: staged?.position.isMocked ?? false,
      checkOutStatic: staged?.position.isStatic ?? false,
      checkOutTimeSource: time.source,
      recordedOffline: recordedOffline,
      attendanceStatus: AttendanceStatus.present,
      syncStatus: SyncStatus.pending,
    );
    try {
      await _local.upsert(record);
    } catch (error) {
      debugPrint('PEAM local check-out save failed: $error');
      return;
    }
    lastAttendance = record;
    stagedGeofence = null;
    pendingAttendanceAction = AttendanceAction.checkIn;
    _history = [
      record,
      for (final item in _history)
        if (item.event.id != record.event.id) item,
    ];
    _notify();
    await addNotification(
      title: recordedOffline
          ? 'Check-out saved on this phone'
          : 'Check-out saved',
      body: recordedOffline
          ? 'Your check-out for ${event.name} is on this phone. PHRMO will see it when you have internet.'
          : 'Your check-out for ${event.name} will be sent to PHRMO.',
      kind: NotificationKind.attendanceSync,
      eventId: event.id,
      showSystemBanner: true,
    );
    try {
      await _syncWhenOnline();
    } catch (error) {
      debugPrint('PEAM check-out upload failed: $error');
    }
    await _scheduleBackgroundSyncIfNeeded();
    await _reloadHistory();
  }

  Future<int> syncPending() {
    final existing = _syncInFlight;
    if (existing != null) {
      return existing;
    }
    late final Future<int> pending;
    pending = _performSync().whenComplete(() {
      if (identical(_syncInFlight, pending)) {
        _syncInFlight = null;
      }
    });
    _syncInFlight = pending;
    return pending;
  }

  Future<int> _performSync() async {
    final currentEmployee = employee;
    if (currentEmployee == null || !_connectivity.isOnline || _disposed) {
      return 0;
    }

    isSyncing = true;
    _notify();
    try {
      await _refreshClockAnchor();
      final uploaded = await _sync.syncPending(
        local: _local,
        remote: _remote,
        employee: currentEmployee,
      );
      await _mergeRemoteHistory();
      await _reloadHistory();
      if (await _verifyDeviceIntegrity()) {
        await _mergeRemoteHistory();
        await _reloadHistory();
      }
      if (lastAttendance != null) {
        lastAttendance = recordFor(lastAttendance!.event.id) ?? lastAttendance;
      }
      if (uploaded > 0 && !_disposed) {
        await addNotification(
          title: 'Attendance sent',
          body: uploaded == 1
              ? '1 attendance record was sent to PHRMO.'
              : '$uploaded attendance records were sent to PHRMO.',
          kind: NotificationKind.attendanceSync,
          showSystemBanner: true,
        );
      }
      return uploaded;
    } finally {
      isSyncing = false;
      _notify();
      unawaited(_scheduleBackgroundSyncIfNeeded());
    }
  }

  Future<void> _refreshClockAnchor() async {
    final clock = _clock;
    final integrity = _integrity;
    if (clock == null || integrity == null) {
      return;
    }
    final serverNow = await integrity.serverNow();
    if (serverNow != null) {
      await clock.anchor(serverNow);
    }
  }

  /// Asks Play Integrity about this phone for recently uploaded records.
  /// Runs in the foreground only: the native channel is not available to
  /// the background sync isolate. Returns true when a verdict was stored.
  Future<bool> _verifyDeviceIntegrity() async {
    final integrity = _integrity;
    if (integrity == null || _disposed) {
      return false;
    }
    final candidates = _history
        .where(
          (record) =>
              record.syncStatus == SyncStatus.synced &&
              record.integrityStatus == IntegrityStatus.unchecked &&
              !_integrityAttempted.contains(record.clientRecordId),
        )
        .take(5)
        .toList();
    var stored = false;
    for (final record in candidates) {
      _integrityAttempted.add(record.clientRecordId);
      final token = await _guard.integrityToken(
        integrityNonce(record.clientRecordId),
      );
      if (token == null) {
        continue;
      }
      final status = await integrity.verify(
        clientRecordId: record.clientRecordId,
        token: token,
      );
      if (status != null) {
        stored = true;
        await _local.upsert(record.copyWith(integrityStatus: status));
      }
    }
    return stored;
  }

  Future<void> _syncWhenOnline() async {
    if (!_connectivity.isOnline || employee == null || _disposed) {
      return;
    }
    await syncPending();
  }

  Future<void> _scheduleBackgroundSyncIfNeeded() async {
    if (_disposed || employee == null) {
      return;
    }
    final hasPending = _history.any((record) => record.isPending);
    if (!hasPending) {
      return;
    }
    await BackgroundAttendanceSync.schedulePendingUpload();
  }

  Future<void> _mergeRemoteHistory() async {
    final currentEmployee = employee;
    if (currentEmployee == null || !_connectivity.isOnline) {
      return;
    }
    try {
      final remoteRows = await _remote.listForEmployee(currentEmployee);
      for (final row in remoteRows) {
        await _local.upsert(
          row.copyWith(
            serverId: row.serverId ?? row.clientRecordId,
            syncStatus: SyncStatus.synced,
            syncedAt: row.syncedAt ?? DateTime.now().toUtc(),
          ),
        );
      }
    } catch (_) {}
  }

  void markNotificationRead(String id) {
    _notifications = [
      for (final item in _notifications)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
    unawaited(_persistInbox());
    notifyListeners();
  }

  void markAllNotificationsRead() {
    _notifications = [
      for (final item in _notifications) item.copyWith(isRead: true),
    ];
    unawaited(_persistInbox());
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    await refreshEvents();
    await _ingestDeviceRequests();
  }

  Future<void> addNotification({
    required String title,
    required String body,
    required NotificationKind kind,
    String? eventId,
    bool showSystemBanner = false,
  }) async {
    final item = AppNotification(
      id: 'n-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      kind: kind,
      createdAt: DateTime.now(),
      eventId: eventId,
    );
    await _prependNotices([item], showBanner: showSystemBanner);
  }

  Future<void> _loadInbox() async {
    final current = employee;
    if (current == null) {
      _notifications = const [];
      _noticeSnapshot = const NotificationSnapshot();
      return;
    }
    _noticeSnapshot = await _inbox.load(current.employeeNumber);
    _notifications = List.of(_noticeSnapshot.items);
    _notify();
  }

  Future<void> _persistInbox() async {
    final current = employee;
    if (current == null) {
      return;
    }
    _noticeSnapshot = _noticeSnapshot.copyWith(items: _notifications);
    await _inbox.save(current.employeeNumber, _noticeSnapshot);
  }

  Future<void> _startLiveNotices() async {
    final live = _liveNotifications;
    if (live == null || employee == null) {
      return;
    }
    await live.start(
      onEventsChanged: () {
        if (!_disposed) {
          unawaited(refreshEvents());
        }
      },
      onDeviceRequestsChanged: () {
        if (!_disposed) {
          unawaited(_ingestDeviceRequests());
        }
      },
    );
    await _ingestDeviceRequests();
  }

  Future<void> _startFcm() async {
    final fcm = _fcm;
    final auth = _remoteAuth;
    if (fcm == null || auth == null || employee == null || _disposed) {
      return;
    }
    await fcm.start(
      onToken: auth.registerFcmToken,
      onOpened: _push.deliverTap,
      onForeground: (title, body, payload) {
        unawaited(_push.showBanner(title: title, body: body, payload: payload));
      },
    );
  }

  Future<void> _ingestEventNotices() async {
    if (employee == null || _disposed) {
      return;
    }
    final result = reconcileEventNotices(
      previousFingerprints: _noticeSnapshot.eventFingerprints,
      remindedEventIds: _noticeSnapshot.remindedEventIds,
      events: _events,
    );
    _noticeSnapshot = _noticeSnapshot.copyWith(
      eventFingerprints: result.fingerprints,
      remindedEventIds: result.remindedEventIds,
    );
    for (final reminder in result.remindersToSchedule) {
      final notice = reminderNoticeFor(reminder.event, reminder.when);
      await _push.scheduleBanner(
        id: _reminderId(reminder.event.id),
        title: notice.title,
        body: notice.body,
        when: reminder.when,
        payload: notice.tapPayload.encode(),
      );
    }
    await _prependNotices(result.notices);
    await _persistInbox();
  }

  Future<void> _ingestDeviceRequests() async {
    final live = _liveNotifications;
    if (live == null || employee == null || _disposed) {
      return;
    }
    final rows = await live.listDeviceRequests();
    final result = reconcileDeviceRequests(
      previousStatuses: _noticeSnapshot.deviceRequestStatuses,
      rows: rows,
    );
    _noticeSnapshot = _noticeSnapshot.copyWith(
      deviceRequestStatuses: result.statuses,
    );
    await _prependNotices(result.notices);
    await _persistInbox();
  }

  Future<void> _prependNotices(
    List<AppNotification> notices, {
    bool showBanner = true,
  }) async {
    if (notices.isEmpty || _disposed) {
      return;
    }
    final existing = {for (final item in _notifications) item.id};
    final fresh = [
      for (final item in notices)
        if (!existing.contains(item.id)) item,
    ];
    if (fresh.isEmpty) {
      return;
    }
    _notifications = [...fresh, ..._notifications];
    await _persistInbox();
    _notify();
    if (!showBanner) {
      return;
    }
    for (final item in fresh) {
      await _push.showBanner(
        title: item.title,
        body: item.body,
        payload: item.tapPayload.encode(),
      );
    }
  }

  int _reminderId(String eventId) {
    return 500000 + (eventId.hashCode.abs() % 400000);
  }

  int _checkoutReminderId(String eventId) {
    return 900000 + (eventId.hashCode.abs() % 50000);
  }

  Future<void> _syncCheckoutReminders() async {
    if (_disposed) {
      return;
    }
    final now = DateTime.now();
    final due = <AppNotification>[];
    final activeIds = <String>{};
    for (final record in _history) {
      final event = record.event;
      final plan = planCheckoutReminder(
        event: event,
        checkInAt: record.checkInAt,
        checkOutAt: record.checkOutAt,
        now: now,
      );
      final id = _checkoutReminderId(event.id);
      if (plan.step == CheckoutReminderStep.schedule && plan.at != null) {
        final notice = checkoutReminderNotice(event, plan.at!);
        activeIds.add(notice.id);
        debugPrint(
          'PEAM checkout reminder scheduled at ${plan.at} for ${event.name}',
        );
        await _push.scheduleBanner(
          id: id,
          title: notice.title,
          body: notice.body,
          when: plan.at!,
          payload: notice.tapPayload.encode(),
        );
        continue;
      }
      await _push.cancel(id);
      if (plan.step == CheckoutReminderStep.due && plan.at != null) {
        final notice = checkoutReminderNotice(event, plan.at!);
        activeIds.add(notice.id);
        due.add(notice);
      }
    }
    final kept = [
      for (final item in _notifications)
        if (item.kind != NotificationKind.checkOutReminder ||
            activeIds.contains(item.id))
          item,
    ];
    if (kept.length != _notifications.length) {
      _notifications = kept;
      await _persistInbox();
      _notify();
    }
    await _prependNotices(due);
  }

  Future<Employee?> _cachedEmployee(String deviceUid) async {
    final session = await _authStore.readSession();
    if (session == null || session.deviceUid != deviceUid) {
      return null;
    }
    final boundUid = await _authStore.bindingFor(session.employeeNumber);
    if (boundUid != null && boundUid != deviceUid) {
      return null;
    }
    final saved = await _authStore.readEmployee();
    if (saved != null &&
        saved.employeeNumber.toLowerCase() ==
            session.employeeNumber.toLowerCase()) {
      return saved.copyWith(
        deviceUid: deviceUid,
        deviceName: _describeThisPhone(),
      );
    }
    final stub = Employee(
      employeeNumber: session.employeeNumber,
      fullName: session.employeeNumber,
      department: const Department(name: 'Saved on this phone', code: '—'),
      deviceUid: deviceUid,
      deviceName: _describeThisPhone(),
    );
    final history = await _local.listForEmployee(stub);
    if (history.isEmpty) {
      return stub;
    }
    return history.first.employee.copyWith(
      deviceUid: deviceUid,
      deviceName: _describeThisPhone(),
    );
  }

  Future<void> _rememberEmployee(Employee account, String deviceUid) async {
    await _authStore.saveBinding(
      employeeNumber: account.employeeNumber,
      deviceUid: deviceUid,
    );
    await _authStore.saveSession(
      employeeNumber: account.employeeNumber,
      deviceUid: deviceUid,
    );
    await _authStore.saveEmployee(account);
  }

  Future<void> _enterOfflineSession(Employee account) async {
    employee = account;
    await _loadInbox();
    await _reloadHistory(includeRemote: false);
    final catalog = _eventsCatalog;
    if (catalog is CachedEventsCatalog) {
      _events = await catalog.readCached();
    } else if (catalog == null) {
      _events = List.of(SampleData.events);
    }
    isLoadingEvents = false;
    eventsError = _events.isEmpty && !_connectivity.isOnline
        ? 'Could not load events. Pull down to try again.'
        : null;
    notifyListeners();
  }

  Future<void> _refreshRemoteSession(
    String deviceUid, {
    bool skipRestore = false,
  }) async {
    if (_disposed || _remoteAuth == null) {
      return;
    }
    if (!skipRestore) {
      try {
        final restored = await _remoteAuth
            .restore(deviceUid: deviceUid)
            .timeout(const Duration(seconds: 8));
        if (_disposed) {
          return;
        }
        if (restored != null) {
          employee = restored;
          await _rememberEmployee(restored, deviceUid);
          notifyListeners();
        }
      } on AuthBindingException {
        if (!_disposed) {
          await logout();
        }
        return;
      } catch (error) {
        debugPrint('PEAM profile refresh skipped: $error');
      }
    }
    if (_disposed || employee == null) {
      return;
    }
    if (!_connectivity.isOnline) {
      await _scheduleBackgroundSyncIfNeeded();
      return;
    }
    await refreshEvents();
    await _syncWhenOnline();
    await _scheduleBackgroundSyncIfNeeded();
    await _startLiveNotices();
    await _startFcm();
  }

  Future<void> _reloadHistory({bool includeRemote = true}) async {
    final currentEmployee = employee;
    if (currentEmployee == null) {
      _history = const [];
      remoteRecordCount = 0;
      _notify();
      return;
    }
    _history = await _local.listForEmployee(currentEmployee);
    _notify();
    unawaited(_syncCheckoutReminders());
    if (!includeRemote || !_connectivity.isOnline) {
      remoteRecordCount = _history
          .where((record) => record.syncStatus == SyncStatus.synced)
          .length;
      return;
    }
    try {
      remoteRecordCount =
          (await _remote
                  .listForEmployee(currentEmployee)
                  .timeout(const Duration(seconds: 12)))
              .length;
    } catch (error) {
      debugPrint('PEAM attendance history fetch failed: $error');
      remoteRecordCount = _history
          .where((record) => record.syncStatus == SyncStatus.synced)
          .length;
    }
    _notify();
  }

  void _onConnectivityChanged() {
    if (_disposed) {
      return;
    }
    _notify();
    if (_connectivity.isOnline && employee != null) {
      unawaited(_syncWhenOnline());
      unawaited(refreshNotifications());
      unawaited(_startLiveNotices());
      unawaited(_startFcm());
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    onHomeBack = null;
    unawaited(_fcm?.stop());
    unawaited(_liveNotifications?.stop());
    _connectivity.removeListener(_onConnectivityChanged);
    if (_ownsConnectivity) {
      _connectivity.dispose();
    }
    super.dispose();
  }
}
