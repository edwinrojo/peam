import 'package:flutter_test/flutter_test.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/models/models.dart';
import 'package:peam/services/events_catalog.dart';
import 'package:peam/state/session_controller.dart';

void main() {
  test('maps a Supabase event row into a home-screen event', () {
    final event = provincialEventFromRow({
      'id': '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      'name': 'Provincial Employees Assembly 2026',
      'description': 'Annual assembly at the Capitol grounds.',
      'event_date': '2026-08-25',
      'start_time': '08:00:00',
      'end_time': '17:00:00',
      'venue': 'Provincial Capitol Grounds, Digos City',
      'latitude': '6.7492000',
      'longitude': 125.3571,
      'geofence_radius_meters': 120,
      'status': 'ongoing',
    });

    expect(event, isNotNull);
    expect(event!.name, 'Provincial Employees Assembly 2026');
    expect(event.startTime, '8:00 AM');
    expect(event.endTime, '5:00 PM');
    expect(event.eventDate, DateTime(2026, 8, 25));
    expect(event.location.latitude, closeTo(6.7492, 0.0001));
    expect(event.status, EventStatus.ongoing);
  });

  test('a published event today during its hours shows as Ongoing', () {
    final event = ProvincialEvent(
      id: 'today',
      name: 'Today assembly',
      description: '',
      eventDate: DateTime(2026, 9, 17),
      startTime: '8:00 AM',
      endTime: '5:00 PM',
      venue: 'Capitol',
      location: SampleData.capitol,
      status: EventStatus.published,
    );

    expect(
      event.effectiveStatus(DateTime(2026, 9, 17, 14, 9)),
      EventStatus.ongoing,
    );
    expect(
      event.effectiveStatus(DateTime(2026, 9, 17, 7, 59)),
      EventStatus.published,
    );
    expect(
      event.effectiveStatus(DateTime(2026, 9, 17, 17, 0)),
      EventStatus.completed,
    );
  });

  test('drops draft and cancelled events from the employee list', () {
    expect(
      provincialEventFromRow({
        'id': 'draft',
        'name': 'Draft event',
        'event_date': '2026-09-17',
        'start_time': '08:00:00',
        'end_time': '12:00:00',
        'venue': 'Capitol',
        'latitude': 6.7,
        'longitude': 125.3,
        'status': 'draft',
      }),
      isNull,
    );
  });

  test(
    'uses a live events catalog after login instead of sample data',
    () async {
      final liveEvent = ProvincialEvent(
        id: 'live-assembly',
        name: 'HR-published Assembly',
        description: 'Created in peam-web.',
        eventDate: DateTime(2026, 9, 17),
        startTime: '8:00 AM',
        endTime: '5:00 PM',
        venue: 'Provincial Capitol Grounds, Digos City',
        location: SampleData.capitol,
        status: EventStatus.ongoing,
      );
      final session = SessionController(
        eventsCatalog: _FixedCatalog([liveEvent]),
      );
      addTearDown(session.dispose);

      expect(session.visibleEvents, isEmpty);
      await session.completePrototypeLogin(
        SampleData.demoEmployee.employeeNumber,
      );

      expect(session.visibleEvents, hasLength(1));
      expect(session.visibleEvents.first.name, 'HR-published Assembly');
      expect(
        session.visibleEvents.any((event) => event.id == 'evt-assembly'),
        isFalse,
      );
    },
  );

  test('falls back to the cached event list when refresh fails', () async {
    final cache = MemoryEventsCache();
    await cache.save([
      ProvincialEvent(
        id: 'cached',
        name: 'Cached outreach',
        description: '',
        eventDate: DateTime(2026, 9, 4),
        startTime: '7:30 AM',
        endTime: '3:00 PM',
        venue: 'Malalag Municipal Gymnasium',
        location: EventLocation(
          latitude: 6.6398,
          longitude: 125.3991,
          geofenceRadiusMeters: 150,
        ),
        status: EventStatus.published,
      ),
    ]);
    final catalog = CachedEventsCatalog(
      remote: const _FailingCatalog(),
      cache: cache,
    );

    final events = await catalog.listVisible();
    expect(events, hasLength(1));
    expect(events.first.name, 'Cached outreach');
  });
}

class _FixedCatalog implements EventsCatalog {
  const _FixedCatalog(this.events);

  final List<ProvincialEvent> events;

  @override
  Future<List<ProvincialEvent>> listVisible() async => List.of(events);
}

class _FailingCatalog implements EventsCatalog {
  const _FailingCatalog();

  @override
  Future<List<ProvincialEvent>> listVisible() async {
    throw Exception('offline');
  }
}
