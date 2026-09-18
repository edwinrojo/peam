import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/sample_data.dart';
import '../models/models.dart';
import 'attendance_stores.dart';
import 'events_catalog.dart';

const _localTable = 'attendance_records';
const _remoteTable = 'remote_attendance_records';

const _createSql = '''
CREATE TABLE IF NOT EXISTS {table} (
  client_record_id TEXT PRIMARY KEY NOT NULL,
  server_id TEXT,
  event_id TEXT NOT NULL,
  event_json TEXT,
  employee_number TEXT NOT NULL,
  check_in_at TEXT,
  check_out_at TEXT,
  check_in_latitude REAL,
  check_in_longitude REAL,
  check_out_latitude REAL,
  check_out_longitude REAL,
  geofence_verified INTEGER NOT NULL DEFAULT 0,
  biometric_verified INTEGER NOT NULL DEFAULT 0,
  verification_status TEXT NOT NULL DEFAULT 'pending',
  attendance_status TEXT NOT NULL DEFAULT 'incomplete',
  recorded_offline INTEGER NOT NULL DEFAULT 0,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  client_recorded_at TEXT,
  synced_at TEXT,
  created_at TEXT NOT NULL,
  UNIQUE (event_id, employee_number)
)
''';

class PeamAttendanceDatabase {
  PeamAttendanceDatabase._(this.db);

  final Database db;

  static Future<PeamAttendanceDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'peam_attendance.db');
    final database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(_createSql.replaceAll('{table}', _localTable));
        await db.execute(_createSql.replaceAll('{table}', _remoteTable));
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_localTable ADD COLUMN event_json TEXT',
          );
          await db.execute(
            'ALTER TABLE $_remoteTable ADD COLUMN event_json TEXT',
          );
        }
      },
    );
    return PeamAttendanceDatabase._(database);
  }

  Future<void> ensureEventJsonColumn() async {
    await _addEventJsonColumn(_localTable);
    await _addEventJsonColumn(_remoteTable);
  }

  Future<void> _addEventJsonColumn(String table) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN event_json TEXT');
    } catch (_) {}
  }

  Future<void> seedDemoIfEmpty() async {
    final localCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_localTable'),
    );
    if (localCount == 0) {
      for (final record in SampleData.historyFor(SampleData.demoEmployee)) {
        await db.insert(_localTable, AttendanceRowCodec.toMap(record));
      }
    }
    final remoteCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_remoteTable'),
    );
    if (remoteCount == 0) {
      for (final record in SampleData.historyFor(SampleData.demoEmployee)) {
        await db.insert(_remoteTable, AttendanceRowCodec.toMap(record));
      }
    }
  }
}

class SqliteAttendanceLocalStore implements AttendanceLocalStore {
  SqliteAttendanceLocalStore(this._database);

  final PeamAttendanceDatabase _database;

  Database get _db => _database.db;

  @override
  Future<List<AttendanceRecord>> listForEmployee(Employee employee) async {
    final rows = await _db.query(
      _localTable,
      where: 'employee_number = ?',
      whereArgs: [employee.employeeNumber],
      orderBy: 'check_in_at DESC',
    );
    return AttendanceRowCodec.hydrateAll(rows, employee);
  }

  @override
  Future<AttendanceRecord?> find({
    required String eventId,
    required Employee employee,
  }) async {
    final rows = await _db.query(
      _localTable,
      where: 'event_id = ? AND employee_number = ?',
      whereArgs: [eventId, employee.employeeNumber],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AttendanceRowCodec.fromMap(rows.first, employee);
  }

  @override
  Future<AttendanceRecord> upsert(AttendanceRecord record) async {
    final existing = await find(
      eventId: record.event.id,
      employee: record.employee,
    );
    if (existing != null) {
      final merged = mergeAttendanceRecords(existing, record);
      await _replace(merged);
      return merged;
    }
    await _insert(record);
    return record;
  }

  Future<void> _replace(AttendanceRecord record) async {
    try {
      await _db.update(
        _localTable,
        AttendanceRowCodec.toMap(record),
        where: 'client_record_id = ?',
        whereArgs: [record.clientRecordId],
      );
    } catch (error) {
      if (!_needsEventJson(error)) {
        rethrow;
      }
      await _database.ensureEventJsonColumn();
      await _db.update(
        _localTable,
        AttendanceRowCodec.toMap(record),
        where: 'client_record_id = ?',
        whereArgs: [record.clientRecordId],
      );
    }
  }

  Future<void> _insert(AttendanceRecord record) async {
    try {
      await _db.insert(_localTable, AttendanceRowCodec.toMap(record));
    } catch (error) {
      if (!_needsEventJson(error)) {
        rethrow;
      }
      await _database.ensureEventJsonColumn();
      await _db.insert(_localTable, AttendanceRowCodec.toMap(record));
    }
  }

  bool _needsEventJson(Object error) {
    return error.toString().contains('event_json');
  }

  @override
  Future<List<AttendanceRecord>> pendingFor(Employee employee) async {
    final rows = await _db.query(
      _localTable,
      where: 'employee_number = ? AND sync_status = ?',
      whereArgs: [employee.employeeNumber, SyncStatus.pending.name],
      orderBy: 'check_in_at DESC',
    );
    return AttendanceRowCodec.hydrateAll(rows, employee);
  }

  @override
  Future<void> markSynced({
    required String clientRecordId,
    required String serverId,
    required DateTime syncedAt,
  }) async {
    await _db.update(
      _localTable,
      {
        'server_id': serverId,
        'sync_status': SyncStatus.synced.name,
        'synced_at': syncedAt.toIso8601String(),
      },
      where: 'client_record_id = ?',
      whereArgs: [clientRecordId],
    );
  }
}

class SqliteAttendanceRemoteStore implements AttendanceRemoteStore {
  SqliteAttendanceRemoteStore(this._database);

  final PeamAttendanceDatabase _database;

  Database get _db => _database.db;

  @override
  Future<AttendanceRecord> upsert(AttendanceRecord record) async {
    await _db.insert(
      _remoteTable,
      AttendanceRowCodec.toMap(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record;
  }

  @override
  Future<List<AttendanceRecord>> listForEmployee(Employee employee) async {
    final rows = await _db.query(
      _remoteTable,
      where: 'employee_number = ?',
      whereArgs: [employee.employeeNumber],
    );
    return AttendanceRowCodec.hydrateAll(rows, employee);
  }
}

abstract final class AttendanceRowCodec {
  static Map<String, Object?> toMap(AttendanceRecord record) {
    return {
      'client_record_id': record.clientRecordId,
      'server_id': record.serverId,
      'event_id': record.event.id,
      'event_json': jsonEncode(provincialEventToRow(record.event)),
      'employee_number': record.employee.employeeNumber,
      'check_in_at': record.checkInAt.toIso8601String(),
      'check_out_at': record.checkOutAt?.toIso8601String(),
      'check_in_latitude': record.checkInLatitude,
      'check_in_longitude': record.checkInLongitude,
      'check_out_latitude': record.checkOutLatitude,
      'check_out_longitude': record.checkOutLongitude,
      'geofence_verified': record.geofenceVerified ? 1 : 0,
      'biometric_verified': record.biometricVerified ? 1 : 0,
      'verification_status': record.verificationStatus.name,
      'attendance_status': record.attendanceStatus.name,
      'recorded_offline': record.recordedOffline ? 1 : 0,
      'sync_status': record.syncStatus.name,
      'client_recorded_at': record.clientRecordedAt.toIso8601String(),
      'synced_at': record.syncedAt?.toIso8601String(),
      'created_at': record.clientRecordedAt.toIso8601String(),
    };
  }

  static List<AttendanceRecord> hydrateAll(
    List<Map<String, Object?>> rows,
    Employee employee,
  ) {
    return [for (final row in rows) ?fromMap(row, employee)];
  }

  static AttendanceRecord? fromMap(
    Map<String, Object?> row,
    Employee employee,
  ) {
    final eventId = row['event_id']?.toString();
    final clientRecordId = row['client_record_id']?.toString();
    if (eventId == null || eventId.isEmpty || clientRecordId == null) {
      return null;
    }
    final event = _eventFromRow(row, eventId);
    final checkInAt =
        _parseTime(row['check_in_at']) ??
        _parseTime(row['client_recorded_at']) ??
        DateTime.now();
    return AttendanceRecord(
      clientRecordId: clientRecordId,
      serverId: row['server_id'] as String?,
      event: event,
      employee: employee,
      checkInAt: checkInAt,
      checkOutAt: _parseTime(row['check_out_at']),
      checkInLatitude: (row['check_in_latitude'] as num?)?.toDouble(),
      checkInLongitude: (row['check_in_longitude'] as num?)?.toDouble(),
      checkOutLatitude: (row['check_out_latitude'] as num?)?.toDouble(),
      checkOutLongitude: (row['check_out_longitude'] as num?)?.toDouble(),
      geofenceVerified: (row['geofence_verified'] as int? ?? 0) == 1,
      biometricVerified: (row['biometric_verified'] as int? ?? 0) == 1,
      verificationStatus: _verification(row['verification_status'] as String?),
      attendanceStatus: _attendance(row['attendance_status'] as String?),
      recordedOffline: (row['recorded_offline'] as int? ?? 0) == 1,
      syncStatus: (row['sync_status'] as String?) == SyncStatus.synced.name
          ? SyncStatus.synced
          : SyncStatus.pending,
      clientRecordedAt: _parseTime(row['client_recorded_at']) ?? checkInAt,
      syncedAt: _parseTime(row['synced_at']),
    );
  }

  static ProvincialEvent _eventFromRow(
    Map<String, Object?> row,
    String eventId,
  ) {
    final raw = row['event_json'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final event = provincialEventFromRow(
            Map<String, dynamic>.from(decoded),
            includeHidden: true,
          );
          if (event != null) {
            return event;
          }
        }
      } catch (_) {}
    }
    final sample = SampleData.events.cast<ProvincialEvent?>().firstWhere(
      (item) => item!.id == eventId,
      orElse: () => null,
    );
    if (sample != null) {
      return sample;
    }
    return ProvincialEvent(
      id: eventId,
      name: 'Event',
      description: '',
      eventDate: DateTime.now(),
      startTime: '—',
      endTime: '—',
      venue: '—',
      location: const EventLocation(
        latitude: 0,
        longitude: 0,
        geofenceRadiusMeters: 100,
      ),
      status: EventStatus.completed,
    );
  }

  static DateTime? _parseTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static VerificationStatus _verification(String? name) {
    return VerificationStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => VerificationStatus.pending,
    );
  }

  static AttendanceStatus _attendance(String? name) {
    return AttendanceStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AttendanceStatus.incomplete,
    );
  }
}
