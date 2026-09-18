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

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'kind': kind.name,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  static AppNotification? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final title = json['title']?.toString();
    final body = json['body']?.toString();
    if (id == null || title == null || body == null) {
      return null;
    }
    final kindName = json['kind']?.toString();
    final kind = NotificationKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => NotificationKind.adminNotice,
    );
    final createdAt =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    return AppNotification(
      id: id,
      title: title,
      body: body,
      kind: kind,
      createdAt: createdAt,
      isRead: json['is_read'] == true,
    );
  }
}
