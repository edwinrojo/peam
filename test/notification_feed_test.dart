import 'package:flutter_test/flutter_test.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/models/app_notification.dart';
import 'package:peam/models/models.dart';
import 'package:peam/services/notification_feed.dart';

void main() {
  final assembly = SampleData.events.first;

  test('first event snapshot is a baseline with no employee notices', () {
    final result = reconcileEventNotices(
      previousFingerprints: const {},
      remindedEventIds: const {},
      events: [assembly],
      now: DateTime(2026, 1, 1, 8),
    );

    expect(result.notices, isEmpty);
    expect(result.fingerprints[assembly.id], isNotNull);
  });

  test('a newly published event creates a notice after the baseline', () {
    final previous = reconcileEventNotices(
      previousFingerprints: const {},
      remindedEventIds: const {},
      events: [assembly],
      now: DateTime(2026, 1, 1, 8),
    );
    final extra = ProvincialEvent(
      id: 'evt-new',
      name: 'Coastal Clean-up',
      description: '',
      eventDate: DateTime(2026, 10, 1),
      startTime: '8:00 AM',
      endTime: '12:00 PM',
      venue: 'Digos Boulevard',
      location: SampleData.capitol,
      status: EventStatus.published,
    );

    final result = reconcileEventNotices(
      previousFingerprints: previous.fingerprints,
      remindedEventIds: previous.remindedEventIds,
      events: [assembly, extra],
      now: DateTime(2026, 1, 1, 9),
    );

    expect(result.notices, hasLength(1));
    expect(result.notices.single.kind, NotificationKind.eventPublished);
    expect(result.notices.single.title, 'New event published');
    expect(result.notices.single.body, contains('Coastal Clean-up'));
    expect(result.notices.single.eventId, extra.id);
  });

  test('a venue or schedule change creates an update notice', () {
    final previous = {assembly.id: eventFingerprint(assembly)};
    final updated = ProvincialEvent(
      id: assembly.id,
      name: assembly.name,
      description: assembly.description,
      eventDate: assembly.eventDate,
      startTime: assembly.startTime,
      endTime: assembly.endTime,
      venue: 'New Capitol Grounds',
      location: assembly.location,
      status: assembly.status,
    );

    final result = reconcileEventNotices(
      previousFingerprints: previous,
      remindedEventIds: const {},
      events: [updated],
      now: DateTime(2026, 1, 1, 9),
    );

    expect(result.notices.single.title, 'Event updated');
  });

  test('an event starting within 30 minutes creates a reminder', () {
    final now = DateTime(2026, 9, 21, 7, 40);
    final event = ProvincialEvent(
      id: 'evt-soon',
      name: 'Flag Ceremony',
      description: '',
      eventDate: DateTime(2026, 9, 21),
      startTime: '8:00 AM',
      endTime: '9:00 AM',
      venue: 'Capitol',
      location: SampleData.capitol,
      status: EventStatus.published,
    );

    final result = reconcileEventNotices(
      previousFingerprints: {event.id: eventFingerprint(event)},
      remindedEventIds: const {},
      events: [event],
      now: now,
    );

    expect(
      result.notices.where(
        (item) => item.kind == NotificationKind.eventReminder,
      ),
      hasLength(1),
    );
    expect(result.notices.single.eventId, event.id);
    expect(result.remindedEventIds, contains(event.id));
  });

  test('device-change approval after the baseline creates a notice', () {
    final first = reconcileDeviceRequests(
      previousStatuses: const {},
      rows: [
        {'id': 'req-1', 'status': 'pending'},
      ],
    );
    expect(first.notices, isEmpty);

    final second = reconcileDeviceRequests(
      previousStatuses: first.statuses,
      rows: [
        {'id': 'req-1', 'status': 'approved'},
      ],
    );

    expect(second.notices, hasLength(1));
    expect(second.notices.single.title, 'Device-change request approved');
  });
}
