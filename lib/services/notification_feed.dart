import '../models/app_notification.dart';
import '../models/models.dart';

const reminderLead = Duration(minutes: 30);

String eventFingerprint(ProvincialEvent event) {
  return [
    event.id,
    event.name,
    event.venue,
    event.eventDate.toIso8601String(),
    event.startTime,
    event.endTime,
    event.status.name,
  ].join('|');
}

class EventNoticeResult {
  const EventNoticeResult({
    required this.fingerprints,
    required this.notices,
    required this.remindedEventIds,
    required this.remindersToSchedule,
  });

  final Map<String, String> fingerprints;
  final List<AppNotification> notices;
  final Set<String> remindedEventIds;
  final List<({ProvincialEvent event, DateTime when})> remindersToSchedule;
}

EventNoticeResult reconcileEventNotices({
  required Map<String, String> previousFingerprints,
  required Set<String> remindedEventIds,
  required List<ProvincialEvent> events,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final nextFingerprints = <String, String>{
    for (final event in events) event.id: eventFingerprint(event),
  };
  final notices = <AppNotification>[];
  final nextReminded = {...remindedEventIds};
  final remindersToSchedule = <({ProvincialEvent event, DateTime when})>[];
  final hasBaseline = previousFingerprints.isNotEmpty;

  for (final event in events) {
    final fingerprint = nextFingerprints[event.id]!;
    final previous = previousFingerprints[event.id];
    if (hasBaseline && previous == null) {
      notices.add(
        AppNotification(
          id: 'event-published-${event.id}',
          title: 'New event published',
          body:
              '${event.name} is scheduled for ${event.cardDateLabel} at ${event.venue}.',
          kind: NotificationKind.eventPublished,
          createdAt: clock,
          eventId: event.id,
        ),
      );
    } else if (hasBaseline && previous != fingerprint) {
      notices.add(
        AppNotification(
          id: 'event-updated-${event.id}-${clock.millisecondsSinceEpoch}',
          title: 'Event updated',
          body:
              '${event.name} was updated. Open PEAM for the latest schedule and venue.',
          kind: NotificationKind.eventPublished,
          createdAt: clock,
          eventId: event.id,
        ),
      );
    }

    final start = event.startsAt;
    if (start == null ||
        !clock.isBefore(start) ||
        nextReminded.contains(event.id)) {
      continue;
    }
    final reminderAt = start.subtract(reminderLead);
    if (!clock.isBefore(reminderAt)) {
      nextReminded.add(event.id);
      notices.add(_reminderNotice(event, clock));
    } else {
      remindersToSchedule.add((event: event, when: reminderAt));
    }
  }

  return EventNoticeResult(
    fingerprints: nextFingerprints,
    notices: notices,
    remindedEventIds: nextReminded,
    remindersToSchedule: remindersToSchedule,
  );
}

AppNotification _reminderNotice(ProvincialEvent event, DateTime createdAt) {
  return AppNotification(
    id: 'event-reminder-${event.id}',
    title: 'Event reminder',
    body: '${event.name} starts at ${event.startTime} at ${event.venue}.',
    kind: NotificationKind.eventReminder,
    createdAt: createdAt,
    eventId: event.id,
  );
}

class DeviceRequestNoticeResult {
  const DeviceRequestNoticeResult({
    required this.statuses,
    required this.notices,
  });

  final Map<String, String> statuses;
  final List<AppNotification> notices;
}

DeviceRequestNoticeResult reconcileDeviceRequests({
  required Map<String, String> previousStatuses,
  required List<Map<String, dynamic>> rows,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final next = <String, String>{
    for (final row in rows)
      if (row['id'] != null) row['id'].toString(): '${row['status'] ?? ''}',
  };
  final notices = <AppNotification>[];
  final hasBaseline = previousStatuses.isNotEmpty;

  if (!hasBaseline) {
    return DeviceRequestNoticeResult(statuses: next, notices: const []);
  }

  for (final entry in next.entries) {
    final previous = previousStatuses[entry.key];
    if (previous == entry.value) {
      continue;
    }
    final status = entry.value;
    if (status != 'approved' && status != 'rejected') {
      continue;
    }
    final approved = status == 'approved';
    notices.add(
      AppNotification(
        id: 'device-change-${entry.key}-$status',
        title: approved
            ? 'Device-change request approved'
            : 'Device-change request not approved',
        body: approved
            ? 'HRMDO approved your request. You can use the new phone for attendance after you sign in.'
            : 'HRMDO did not approve the request to bind a new phone.',
        kind: NotificationKind.deviceChangeUpdate,
        createdAt: clock,
      ),
    );
  }

  return DeviceRequestNoticeResult(statuses: next, notices: notices);
}

AppNotification reminderNoticeFor(ProvincialEvent event, DateTime createdAt) {
  return _reminderNotice(event, createdAt);
}
