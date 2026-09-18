import 'dart:convert';

enum NotificationKind {
  eventPublished,
  eventReminder,
  deviceChangeUpdate,
  attendanceSync,
  adminNotice,
}

enum NotificationDestination { checkIn, history, profile, inbox }

NotificationDestination notificationDestination(NotificationKind kind) {
  return switch (kind) {
    NotificationKind.eventPublished ||
    NotificationKind.eventReminder => NotificationDestination.checkIn,
    NotificationKind.attendanceSync => NotificationDestination.history,
    NotificationKind.deviceChangeUpdate => NotificationDestination.profile,
    NotificationKind.adminNotice => NotificationDestination.inbox,
  };
}

class NotificationPayload {
  const NotificationPayload({
    required this.kind,
    this.eventId,
    this.notificationId,
  });

  final NotificationKind kind;
  final String? eventId;
  final String? notificationId;

  String encode() {
    return jsonEncode({
      'kind': kind.name,
      if (eventId != null) 'event_id': eventId,
      if (notificationId != null) 'notification_id': notificationId,
    });
  }

  static NotificationPayload? fromRemoteData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return null;
    }
    return tryParse(jsonEncode(data));
  }

  static NotificationPayload? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final kindName = decoded['kind']?.toString();
      if (kindName == null || kindName.isEmpty) {
        return null;
      }
      final kind = NotificationKind.values.firstWhere(
        (value) => value.name == kindName,
        orElse: () => NotificationKind.adminNotice,
      );
      final eventId = decoded['event_id']?.toString();
      final notificationId = decoded['notification_id']?.toString();
      return NotificationPayload(
        kind: kind,
        eventId: (eventId == null || eventId.isEmpty) ? null : eventId,
        notificationId: (notificationId == null || notificationId.isEmpty)
            ? null
            : notificationId,
      );
    } catch (_) {
      return null;
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.isRead = false,
    this.eventId,
  });

  final String id;
  final String title;
  final String body;
  final NotificationKind kind;
  final DateTime createdAt;
  final bool isRead;
  final String? eventId;

  NotificationPayload get tapPayload =>
      NotificationPayload(kind: kind, eventId: eventId, notificationId: id);

  NotificationDestination get destination => notificationDestination(kind);

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      kind: kind,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      eventId: eventId,
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
      if (eventId != null) 'event_id': eventId,
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
    final eventId = json['event_id']?.toString();
    return AppNotification(
      id: id,
      title: title,
      body: body,
      kind: kind,
      createdAt: createdAt,
      isRead: json['is_read'] == true,
      eventId: (eventId == null || eventId.isEmpty) ? null : eventId,
    );
  }
}
