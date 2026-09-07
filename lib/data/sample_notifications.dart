import '../models/app_notification.dart';

abstract final class SampleNotifications {
  static final List<AppNotification> seed = [
    AppNotification(
      id: 'n-event-assembly',
      title: 'New event published',
      body:
          'Provincial Employees Assembly 2026 is now open for check-in at the Capitol Grounds.',
      kind: NotificationKind.eventPublished,
      createdAt: DateTime(2026, 8, 25, 7, 15),
    ),
    AppNotification(
      id: 'n-reminder-health',
      title: 'Upcoming event reminder',
      body:
          'Barangay Health Outreach starts tomorrow at 7:30 AM in Malalag Municipal Gymnasium.',
      kind: NotificationKind.eventReminder,
      createdAt: DateTime(2026, 8, 24, 16, 40),
      isRead: true,
    ),
    AppNotification(
      id: 'n-device-approved',
      title: 'Device-change request approved',
      body:
          'HRMDO approved your request. You may bind your new phone as your attendance device.',
      kind: NotificationKind.deviceChangeUpdate,
      createdAt: DateTime(2026, 8, 22, 11, 5),
      isRead: true,
    ),
  ];
}
