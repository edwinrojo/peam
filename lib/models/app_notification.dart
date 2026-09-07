enum NotificationKind {
  eventPublished,
  eventReminder,
  deviceChangeUpdate,
  attendanceSync,
  adminNotice,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationKind kind;
  final DateTime createdAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      kind: kind,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  String get kindLabel => switch (kind) {
    NotificationKind.eventPublished => 'Event published',
    NotificationKind.eventReminder => 'Reminder',
    NotificationKind.deviceChangeUpdate => 'Device change',
    NotificationKind.attendanceSync => 'Attendance',
    NotificationKind.adminNotice => 'Notice',
  };
}
