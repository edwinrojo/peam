enum EventStatus { draft, published, ongoing, completed, cancelled }

enum AttendanceStatus { present, incomplete, absent }

class Department {
  const Department({required this.name, required this.code});

  final String name;
  final String code;
}

class Employee {
  const Employee({
    required this.employeeNumber,
    required this.fullName,
    required this.password,
    required this.department,
    this.phone,
    this.deviceName = 'Samsung Galaxy A55',
    this.deviceBound = true,
  });

  final String employeeNumber;
  final String fullName;
  final String password;
  final Department department;
  final String? phone;
  final String deviceName;
  final bool deviceBound;

  String get firstName => fullName.split(' ').first;
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
    required this.event,
    required this.checkInAt,
    required this.employee,
    this.checkOutAt,
    this.recordedOffline = false,
    this.geofenceVerified = true,
    this.biometricVerified = true,
    this.attendanceStatus = AttendanceStatus.incomplete,
  });

  final ProvincialEvent event;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final Employee employee;
  final bool recordedOffline;
  final bool geofenceVerified;
  final bool biometricVerified;
  final AttendanceStatus attendanceStatus;
}
