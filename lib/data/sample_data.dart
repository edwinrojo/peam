import '../models/models.dart';

abstract final class SampleData {
  static const departments = <Department>[
    Department(
      name: 'Human Resource Management and Development Office',
      code: 'HRMDO',
    ),
    Department(name: "Provincial Governor's Office", code: 'PGO'),
    Department(name: "Provincial Treasurer's Office", code: 'PTO'),
    Department(name: "Provincial Engineer's Office", code: 'PEO'),
    Department(name: 'Provincial Health Office', code: 'PHO'),
    Department(
      name: 'Provincial Social Welfare and Development Office',
      code: 'PSWDO',
    ),
    Department(
      name: 'Provincial Planning and Development Office',
      code: 'PPDO',
    ),
    Department(name: "Provincial Accountant's Office", code: 'PACCO'),
  ];

  static const capitol = EventLocation(
    latitude: 6.7492,
    longitude: 125.3571,
    geofenceRadiusMeters: 120,
  );

  static final demoEmployee = Employee(
    employeeNumber: '1234',
    fullName: 'Edwin Rojo',
    password: 'password',
    department: departments.first,
    phone: '0917 552 1840',
    deviceName: 'Samsung Galaxy A55',
  );

  static final events = <ProvincialEvent>[
    ProvincialEvent(
      id: 'evt-assembly',
      name: 'Provincial Employees Assembly 2026',
      description:
          'Annual assembly of provincial government employees at the Capitol grounds. Attendance is required for all regular plantilla personnel.',
      eventDate: DateTime(2026, 8, 25),
      startTime: '8:00 AM',
      endTime: '5:00 PM',
      venue: 'Provincial Capitol Grounds, Digos City',
      location: capitol,
      status: EventStatus.ongoing,
    ),
    ProvincialEvent(
      id: 'evt-health',
      name: 'Barangay Health Outreach',
      description:
          'Medical and wellness mission for coastal barangays, coordinated with the Provincial Health Office.',
      eventDate: DateTime(2026, 9, 4),
      startTime: '7:30 AM',
      endTime: '3:00 PM',
      venue: 'Malalag Municipal Gymnasium',
      location: const EventLocation(
        latitude: 6.6398,
        longitude: 125.3991,
        geofenceRadiusMeters: 150,
      ),
      status: EventStatus.published,
    ),
    ProvincialEvent(
      id: 'evt-disaster',
      name: 'Disaster Preparedness Training',
      description:
          'Tabletop exercise and field drill for department disaster risk reduction focal persons.',
      eventDate: DateTime(2026, 9, 12),
      startTime: '8:30 AM',
      endTime: '4:30 PM',
      venue: 'Magsaysay Covered Court',
      location: const EventLocation(
        latitude: 6.7550,
        longitude: 125.1814,
        geofenceRadiusMeters: 100,
      ),
      status: EventStatus.published,
    ),
    ProvincialEvent(
      id: 'evt-briefing',
      name: 'Midyear Financial Briefing',
      description:
          'Budget utilization review for department heads and administrative officers.',
      eventDate: DateTime(2026, 8, 18),
      startTime: '9:00 AM',
      endTime: '12:00 PM',
      venue: 'PGO Conference Hall, Provincial Capitol',
      location: capitol,
      status: EventStatus.completed,
    ),
  ];

  static List<AttendanceRecord> historyFor(Employee employee) {
    final briefing = events.firstWhere((event) => event.id == 'evt-briefing');
    return [
      AttendanceRecord(
        clientRecordId: 'c0a80100-0000-4000-8000-00000000bf01',
        serverId: 'a11e0000-0000-4000-8000-00000000bf01',
        event: briefing,
        employee: employee,
        checkInAt: DateTime(2026, 8, 18, 8, 51),
        checkOutAt: DateTime(2026, 8, 18, 12, 04),
        checkInLatitude: capitol.latitude,
        checkInLongitude: capitol.longitude,
        attendanceStatus: AttendanceStatus.present,
        verificationStatus: VerificationStatus.verified,
        recordedOffline: false,
        syncStatus: SyncStatus.synced,
        clientRecordedAt: DateTime(2026, 8, 18, 8, 51),
        syncedAt: DateTime(2026, 8, 18, 8, 52),
      ),
    ];
  }
}
