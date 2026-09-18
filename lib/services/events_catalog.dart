import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

abstract class EventsCatalog {
  Future<List<ProvincialEvent>> listVisible();
}

class SampleEventsCatalog implements EventsCatalog {
  const SampleEventsCatalog();

  @override
  Future<List<ProvincialEvent>> listVisible() async {
    return List.of(SampleData.events);
  }
}

class SupabaseEventsCatalog implements EventsCatalog {
  SupabaseEventsCatalog({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<ProvincialEvent>> listVisible() async {
    final response = await _client
        .from('events')
        .select(
          'id, name, description, event_date, start_time, end_time, venue, latitude, longitude, geofence_radius_meters, status, requires_check_out',
        )
        .inFilter('status', const ['published', 'ongoing', 'completed'])
        .order('event_date')
        .order('start_time');

    final rows = response as List<dynamic>;
    final events = <ProvincialEvent>[
      for (final row in rows)
        if (row is Map<String, dynamic>) ?provincialEventFromRow(row),
    ];
    events.sort(compareOfficialEvents);
    return events;
  }
}

class CachedEventsCatalog implements EventsCatalog {
  CachedEventsCatalog({required this.remote, required this.cache});

  final EventsCatalog remote;
  final EventsCache cache;

  @override
  Future<List<ProvincialEvent>> listVisible() async {
    try {
      final live = await remote.listVisible();
      await cache.save(live);
      return live;
    } catch (_) {
      final cached = await cache.read();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }
}

abstract class EventsCache {
  Future<List<ProvincialEvent>> read();

  Future<void> save(List<ProvincialEvent> events);
}

class MemoryEventsCache implements EventsCache {
  List<ProvincialEvent> _events = const [];

  @override
  Future<List<ProvincialEvent>> read() async => List.of(_events);

  @override
  Future<void> save(List<ProvincialEvent> events) async {
    _events = List.of(events);
  }
}

class FileEventsCache implements EventsCache {
  FileEventsCache({this.fileName = 'peam_events.json'});

  final String fileName;
  List<ProvincialEvent>? _memory;

  @override
  Future<List<ProvincialEvent>> read() async {
    if (_memory != null) {
      return List.of(_memory!);
    }
    try {
      final file = await _file();
      if (!await file.exists()) {
        return _memory = const [];
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return _memory = const [];
      }
      final events = <ProvincialEvent>[
        for (final row in decoded)
          if (row is Map)
            ?provincialEventFromRow(Map<String, dynamic>.from(row)),
      ];
      return _memory = events;
    } catch (_) {
      return _memory = const [];
    }
  }

  @override
  Future<void> save(List<ProvincialEvent> events) async {
    _memory = List.of(events);
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([for (final event in events) provincialEventToRow(event)]),
      );
    } catch (_) {}
  }

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, fileName));
  }
}

ProvincialEvent? provincialEventFromRow(
  Map<String, dynamic> row, {
  bool includeHidden = false,
}) {
  final id = row['id']?.toString();
  final name = row['name']?.toString().trim();
  final venue = row['venue']?.toString().trim();
  if (id == null || id.isEmpty || name == null || name.isEmpty) {
    return null;
  }
  if (venue == null || venue.isEmpty) {
    return null;
  }
  final eventDate = parseEventDate(row['event_date']);
  final latitude = _asDouble(row['latitude']);
  final longitude = _asDouble(row['longitude']);
  if (eventDate == null || latitude == null || longitude == null) {
    return null;
  }
  final status = parseEventStatus(row['status']);
  if (!includeHidden &&
      (status == EventStatus.draft || status == EventStatus.cancelled)) {
    return null;
  }
  final radius = _asInt(row['geofence_radius_meters']) ?? 100;
  return ProvincialEvent(
    id: id,
    name: name.trim(),
    description: (row['description'] as String?)?.trim() ?? '',
    eventDate: eventDate,
    startTime: formatEventClock(row['start_time']),
    endTime: formatEventClock(row['end_time']),
    venue: venue.trim(),
    location: EventLocation(
      latitude: latitude,
      longitude: longitude,
      geofenceRadiusMeters: radius > 0 ? radius : 100,
    ),
    status: status,
    requiresCheckOut: _asBool(row['requires_check_out']),
  );
}

Map<String, Object?> provincialEventToRow(ProvincialEvent event) {
  return {
    'id': event.id,
    'name': event.name,
    'description': event.description,
    'event_date':
        '${event.eventDate.year.toString().padLeft(4, '0')}-${event.eventDate.month.toString().padLeft(2, '0')}-${event.eventDate.day.toString().padLeft(2, '0')}',
    'start_time': event.startTime,
    'end_time': event.endTime,
    'venue': event.venue,
    'latitude': event.location.latitude,
    'longitude': event.location.longitude,
    'geofence_radius_meters': event.location.geofenceRadiusMeters,
    'status': event.status.name,
    'requires_check_out': event.requiresCheckOut,
  };
}

int compareOfficialEvents(ProvincialEvent a, ProvincialEvent b) {
  final rank = _statusRank(
    a.effectiveStatus(),
  ).compareTo(_statusRank(b.effectiveStatus()));
  if (rank != 0) {
    return rank;
  }
  final date = a.eventDate.compareTo(b.eventDate);
  if (date != 0) {
    return a.effectiveStatus() == EventStatus.completed ? -date : date;
  }
  return a.startTime.compareTo(b.startTime);
}

int _statusRank(EventStatus status) {
  return switch (status) {
    EventStatus.ongoing => 0,
    EventStatus.published => 1,
    EventStatus.completed => 2,
    EventStatus.cancelled => 3,
    EventStatus.draft => 4,
  };
}

EventStatus parseEventStatus(Object? value) {
  final name = value?.toString().trim().toLowerCase();
  return EventStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => EventStatus.published,
  );
}

DateTime? parseEventDate(Object? value) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  final iso = DateTime.tryParse(raw);
  if (iso != null) {
    return DateTime(iso.year, iso.month, iso.day);
  }
  return null;
}

String formatEventClock(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return '—';
  }
  if (RegExp(r'(AM|PM)$', caseSensitive: false).hasMatch(raw)) {
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) {
    return raw;
  }
  var hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  final period = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) {
    hour = 12;
  }
  return '$hour:$minute $period';
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final raw = value?.toString().trim().toLowerCase();
  if (raw == 'true' || raw == '1') {
    return true;
  }
  if (raw == 'false' || raw == '0') {
    return false;
  }
  return fallback;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '');
}
