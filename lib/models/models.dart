enum EventStatus { draft, published, ongoing, completed, cancelled }

enum AttendanceStatus { present, incomplete, absent }

enum VerificationStatus { pending, verified, failed }

enum SyncStatus { pending, synced }

class Department {
  const Department({required this.name, required this.code});

  final String name;
  final String code;
}

class Employee {
  const Employee({
    required this.employeeNumber,
    required this.fullName,
    required this.department,
    this.email,
    this.phone,
    this.deviceUid,
    this.deviceName = 'Unbound',
  });

  final String employeeNumber;
  final String fullName;
  final String? email;
  final Department department;
  final String? phone;
  final String? deviceUid;
  final String deviceName;

  bool get deviceBound => deviceUid != null && deviceUid!.isNotEmpty;

  String get firstName => fullName.split(' ').first;

  String get workEmail => email?.trim() ?? '';

  bool get hasWorkEmail => workEmail.contains('@');

  Employee copyWith({
    String? employeeNumber,
    String? fullName,
    String? email,
    Department? department,
    String? phone,
    String? deviceUid,
    String? deviceName,
    bool clearDevice = false,
  }) {
    return Employee(
      employeeNumber: employeeNumber ?? this.employeeNumber,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      department: department ?? this.department,
      phone: phone ?? this.phone,
      deviceUid: clearDevice ? null : (deviceUid ?? this.deviceUid),
      deviceName: clearDevice ? 'Unbound' : (deviceName ?? this.deviceName),
    );
  }
}

class EventLocation {
  const EventLocation({
    required this.latitude,
    required this.longitude,
    required this.geofenceRadiusMeters,
  });

  final double latitude;
  final double longitude;
  final int geofenceRadiusMeters;
}

class ProvincialEvent {
  const ProvincialEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.venue,
    required this.location,
    required this.status,
    this.requiresCheckOut = false,
  });

  final String id;
  final String name;
  final String description;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final String venue;
  final EventLocation location;
  final EventStatus status;
  final bool requiresCheckOut;

  String get scheduleLabel => '$startTime – $endTime';

  DateTime? get startsAt => _dateAtClock(eventDate, startTime);

  DateTime? get endsAt {
    final start = startsAt;
    final end = _dateAtClock(eventDate, endTime);
    if (start != null && end != null && !end.isAfter(start)) {
      return end.add(const Duration(days: 1));
    }
    return end;
  }

  /// Employee-facing status from the event schedule.
  /// HR `completed` / `cancelled` / `draft` stay as stored.
  EventStatus effectiveStatus([DateTime? now]) {
    if (status == EventStatus.draft ||
        status == EventStatus.cancelled ||
        status == EventStatus.completed) {
      return status;
    }
    final clock = now ?? DateTime.now();
    final start = startsAt;
    final end = endsAt;
    if (start == null || end == null) {
      return status;
    }
    if (clock.isBefore(start)) {
      return EventStatus.published;
    }
    if (!clock.isBefore(end)) {
      return EventStatus.completed;
    }
    return EventStatus.ongoing;
  }

  /// Check-in is allowed until the scheduled end time.
  /// HR `completed` / `cancelled` / `draft` stay closed.
  bool allowsCheckIn([DateTime? now]) {
    if (status == EventStatus.draft ||
        status == EventStatus.cancelled ||
        status == EventStatus.completed) {
      return false;
    }
    final end = endsAt;
    if (end == null) {
      return status == EventStatus.ongoing;
    }
    return (now ?? DateTime.now()).isBefore(end);
  }

  /// Check-out stays available after the event ends, until it is recorded.
  bool allowsCheckOut() {
    return requiresCheckOut &&
        status != EventStatus.draft &&
        status != EventStatus.cancelled;
  }

  bool needsCheckOut(AttendanceRecord? record) {
    return allowsCheckOut() && record != null && record.checkOutAt == null;
  }

  String get dateLabel {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[eventDate.weekday - 1]}, ${months[eventDate.month - 1]} ${eventDate.day}, ${eventDate.year}';
  }

  String get cardDateLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[eventDate.weekday - 1]}, ${months[eventDate.month - 1]} ${eventDate.day}, ${eventDate.year}';
  }

  String get statusLabel => switch (effectiveStatus()) {
    EventStatus.ongoing => 'Ongoing',
    EventStatus.published => 'Upcoming',
    EventStatus.completed => 'Completed',
    EventStatus.cancelled => 'Cancelled',
    EventStatus.draft => 'Draft',
  };
}

({int hour, int minute})? parseEventClock(String raw) {
  final trimmed = raw.trim();
  final twelveHour = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (twelveHour != null) {
    var hour = int.parse(twelveHour.group(1)!);
    final minute = int.parse(twelveHour.group(2)!);
    final period = twelveHour.group(3)!.toUpperCase();
    if (period == 'AM') {
      if (hour == 12) {
        hour = 0;
      }
    } else if (hour != 12) {
      hour += 12;
    }
    return (hour: hour, minute: minute);
  }
  final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(trimmed);
  if (twentyFour == null) {
    return null;
  }
  return (
    hour: int.parse(twentyFour.group(1)!),
    minute: int.parse(twentyFour.group(2)!),
  );
}

DateTime? _dateAtClock(DateTime date, String clock) {
  final parsed = parseEventClock(clock);
  if (parsed == null) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.clientRecordId,
    required this.event,
    required this.checkInAt,
    required this.employee,
    required this.clientRecordedAt,
    this.serverId,
    this.checkOutAt,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.recordedOffline = false,
    this.geofenceVerified = true,
    this.biometricVerified = true,
    this.verificationStatus = VerificationStatus.verified,
    this.attendanceStatus = AttendanceStatus.incomplete,
    this.syncStatus = SyncStatus.pending,
    this.syncedAt,
  });

  /// Device-generated UUID used as the offline idempotency key (`client_record_id`).
  final String clientRecordId;
  final String? serverId;
  final ProvincialEvent event;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final Employee employee;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final bool recordedOffline;
  final bool geofenceVerified;
  final bool biometricVerified;
  final VerificationStatus verificationStatus;
  final AttendanceStatus attendanceStatus;
  final SyncStatus syncStatus;
  final DateTime clientRecordedAt;
  final DateTime? syncedAt;

  bool get isPending => syncStatus == SyncStatus.pending;

  String get syncLabel => switch (syncStatus) {
    SyncStatus.pending =>
      recordedOffline ? 'Pending · recorded offline' : 'Pending',
    SyncStatus.synced => 'Synced',
  };

  AttendanceRecord copyWith({
    String? serverId,
    ProvincialEvent? event,
    DateTime? checkOutAt,
    double? checkOutLatitude,
    double? checkOutLongitude,
    bool? recordedOffline,
    AttendanceStatus? attendanceStatus,
    SyncStatus? syncStatus,
    DateTime? syncedAt,
  }) {
    return AttendanceRecord(
      clientRecordId: clientRecordId,
      serverId: serverId ?? this.serverId,
      event: event ?? this.event,
      checkInAt: checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      employee: employee,
      checkInLatitude: checkInLatitude,
      checkInLongitude: checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      recordedOffline: recordedOffline ?? this.recordedOffline,
      geofenceVerified: geofenceVerified,
      biometricVerified: biometricVerified,
      verificationStatus: verificationStatus,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      syncStatus: syncStatus ?? this.syncStatus,
      clientRecordedAt: clientRecordedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

enum AttendanceAction { checkIn, checkOut }
