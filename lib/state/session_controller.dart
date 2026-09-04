import 'package:flutter/foundation.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

export 'session_scope.dart';

class SessionController extends ChangeNotifier {
  SessionController() {
    _accounts = [SampleData.demoEmployee];
    _history = List.of(SampleData.historyFor(SampleData.demoEmployee));
  }

  late List<Employee> _accounts;
  Employee? employee;
  ProvincialEvent? selectedEvent;
  AttendanceRecord? lastAttendance;
  late List<AttendanceRecord> _history;
  String searchQuery = '';
  EventStatus? statusFilter;

  List<Employee> get accounts => List.unmodifiable(_accounts);
  List<AttendanceRecord> get history => List.unmodifiable(_history);

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

  String? login({
    required String employeeNumber,
    required String password,
  }) {
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
    notifyListeners();
    return null;
  }

  String? register({
    required String fullName,
    required String employeeNumber,
    required String password,
    required Department department,
    String? phone,
  }) {
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
    notifyListeners();
    return null;
  }

  void logout() {
    employee = null;
    selectedEvent = null;
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

  void confirmAttendance({required DateTime checkInAt}) {
    final currentEmployee = employee;
    final event = selectedEvent;
    if (currentEmployee == null || event == null) {
      return;
    }
    lastAttendance = AttendanceRecord(
      event: event,
      employee: currentEmployee,
      checkInAt: checkInAt,
      recordedOffline: true,
      geofenceVerified: true,
      biometricVerified: true,
      attendanceStatus: AttendanceStatus.incomplete,
    );
    _history = [lastAttendance!, ..._history];
    notifyListeners();
  }
}
