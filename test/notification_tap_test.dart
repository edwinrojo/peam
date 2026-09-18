import 'package:flutter_test/flutter_test.dart';
import 'package:peam/models/app_notification.dart';

void main() {
  test('payload round-trips kind, event, and notice id', () {
    const payload = NotificationPayload(
      kind: NotificationKind.eventReminder,
      eventId: 'evt-assembly',
      notificationId: 'event-reminder-evt-assembly',
    );

    final parsed = NotificationPayload.tryParse(payload.encode());

    expect(parsed, isNotNull);
    expect(parsed!.kind, NotificationKind.eventReminder);
    expect(parsed.eventId, 'evt-assembly');
    expect(parsed.notificationId, 'event-reminder-evt-assembly');
  });

  test('payload parse ignores empty or invalid json', () {
    expect(NotificationPayload.tryParse(null), isNull);
    expect(NotificationPayload.tryParse(''), isNull);
    expect(NotificationPayload.tryParse('{'), isNull);
    expect(NotificationPayload.tryParse('{"event_id":"evt-1"}'), isNull);
  });

  test('notice kinds map to the matching destination', () {
    expect(
      notificationDestination(NotificationKind.eventPublished),
      NotificationDestination.checkIn,
    );
    expect(
      notificationDestination(NotificationKind.eventReminder),
      NotificationDestination.checkIn,
    );
    expect(
      notificationDestination(NotificationKind.attendanceSync),
      NotificationDestination.history,
    );
    expect(
      notificationDestination(NotificationKind.deviceChangeUpdate),
      NotificationDestination.profile,
    );
    expect(
      notificationDestination(NotificationKind.adminNotice),
      NotificationDestination.inbox,
    );
  });

  test('persisted notices keep the event id', () {
    final notice = AppNotification(
      id: 'event-published-evt-assembly',
      title: 'New event published',
      body: 'Assembly is open.',
      kind: NotificationKind.eventPublished,
      createdAt: DateTime(2026, 9, 18, 8),
      eventId: 'evt-assembly',
    );

    final restored = AppNotification.fromJson(notice.toJson());

    expect(restored, isNotNull);
    expect(restored!.eventId, 'evt-assembly');
    expect(restored.copyWith(isRead: true).eventId, 'evt-assembly');
    expect(restored.tapPayload.kind, NotificationKind.eventPublished);
  });

  test('FCM data maps to a tap payload', () {
    final parsed = NotificationPayload.fromRemoteData(<String, dynamic>{
      'kind': 'eventPublished',
      'event_id': 'evt-assembly',
      'notification_id': 'event-published-evt-assembly',
    });

    expect(parsed, isNotNull);
    expect(parsed!.kind, NotificationKind.eventPublished);
    expect(parsed.eventId, 'evt-assembly');
    expect(parsed.notificationId, 'event-published-evt-assembly');
  });
}
