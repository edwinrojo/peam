import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_notification.dart';

class NotificationSnapshot {
  const NotificationSnapshot({
    this.items = const [],
    this.eventFingerprints = const {},
    this.deviceRequestStatuses = const {},
    this.remindedEventIds = const {},
  });

  final List<AppNotification> items;
  final Map<String, String> eventFingerprints;
  final Map<String, String> deviceRequestStatuses;
  final Set<String> remindedEventIds;

  NotificationSnapshot copyWith({
    List<AppNotification>? items,
    Map<String, String>? eventFingerprints,
    Map<String, String>? deviceRequestStatuses,
    Set<String>? remindedEventIds,
  }) {
    return NotificationSnapshot(
      items: items ?? this.items,
      eventFingerprints: eventFingerprints ?? this.eventFingerprints,
      deviceRequestStatuses:
          deviceRequestStatuses ?? this.deviceRequestStatuses,
      remindedEventIds: remindedEventIds ?? this.remindedEventIds,
    );
  }
}

abstract class NotificationInbox {
  Future<NotificationSnapshot> load(String employeeNumber);

  Future<void> save(String employeeNumber, NotificationSnapshot snapshot);
}

class MemoryNotificationInbox implements NotificationInbox {
  final Map<String, NotificationSnapshot> _byEmployee = {};

  @override
  Future<NotificationSnapshot> load(String employeeNumber) async {
    return _byEmployee[employeeNumber] ?? const NotificationSnapshot();
  }

  @override
  Future<void> save(
    String employeeNumber,
    NotificationSnapshot snapshot,
  ) async {
    _byEmployee[employeeNumber] = snapshot;
  }
}

class FileNotificationInbox implements NotificationInbox {
  FileNotificationInbox({this.filePrefix = 'peam_notifications'});

  final String filePrefix;
  final Map<String, NotificationSnapshot> _memory = {};

  @override
  Future<NotificationSnapshot> load(String employeeNumber) async {
    final cached = _memory[employeeNumber];
    if (cached != null) {
      return cached;
    }
    try {
      final file = await _file(employeeNumber);
      if (!await file.exists()) {
        return _memory[employeeNumber] = const NotificationSnapshot();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return _memory[employeeNumber] = const NotificationSnapshot();
      }
      return _memory[employeeNumber] = snapshotFromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return _memory[employeeNumber] = const NotificationSnapshot();
    }
  }

  @override
  Future<void> save(
    String employeeNumber,
    NotificationSnapshot snapshot,
  ) async {
    _memory[employeeNumber] = snapshot;
    try {
      final file = await _file(employeeNumber);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(snapshotToJson(snapshot)));
    } catch (_) {}
  }

  Future<File> _file(String employeeNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final safe = employeeNumber.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File(p.join(directory.path, '$filePrefix-$safe.json'));
  }
}

Map<String, Object?> snapshotToJson(NotificationSnapshot snapshot) {
  return {
    'items': [for (final item in snapshot.items) item.toJson()],
    'event_fingerprints': snapshot.eventFingerprints,
    'device_request_statuses': snapshot.deviceRequestStatuses,
    'reminded_event_ids': snapshot.remindedEventIds.toList(),
  };
}

NotificationSnapshot snapshotFromJson(Map<String, dynamic> json) {
  final rawItems = json['items'];
  final items = <AppNotification>[
    if (rawItems is List)
      for (final row in rawItems)
        if (row is Map)
          ?AppNotification.fromJson(Map<String, dynamic>.from(row)),
  ];
  return NotificationSnapshot(
    items: items,
    eventFingerprints: _stringMap(json['event_fingerprints']),
    deviceRequestStatuses: _stringMap(json['device_request_statuses']),
    remindedEventIds: {
      if (json['reminded_event_ids'] is List)
        for (final id in json['reminded_event_ids'] as List) id.toString(),
    },
  );
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value.toString(),
  };
}
