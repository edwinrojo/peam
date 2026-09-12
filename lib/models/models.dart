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

  String get scheduleLabel => '$startTime – $endTime';

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

  String get statusLabel => switch (status) {
    EventStatus.ongoing => 'Ongoing',
    EventStatus.published => 'Upcoming',
    EventStatus.completed => 'Completed',
    EventStatus.cancelled => 'Cancelled',
    EventStatus.draft => 'Draft',
  };
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
    DateTime? checkOutAt,
    bool? recordedOffline,
    AttendanceStatus? attendanceStatus,
    SyncStatus? syncStatus,
    DateTime? syncedAt,
  }) {
    return AttendanceRecord(
      clientRecordId: clientRecordId,
      serverId: serverId ?? this.serverId,
      event: event,
      checkInAt: checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      employee: employee,
      checkInLatitude: checkInLatitude,
      checkInLongitude: checkInLongitude,
      checkOutLatitude: checkOutLatitude,
      checkOutLongitude: checkOutLongitude,
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
