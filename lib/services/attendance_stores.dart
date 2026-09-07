import '../data/sample_data.dart';
import '../models/models.dart';

/// On-device attendance log (Flutter stand-in for Room / Core Data).
abstract class AttendanceLocalStore {
  Future<List<AttendanceRecord>> listForEmployee(Employee employee);

  Future<AttendanceRecord?> find({
    required String eventId,
    required Employee employee,
  });

  /// Inserts a new row. If this employee already has a row for the event,
  /// the existing row is returned unchanged (one record per employee per event).
  Future<AttendanceRecord> upsert(AttendanceRecord record);

  Future<List<AttendanceRecord>> pendingFor(Employee employee);

  Future<void> markSynced({
    required String clientRecordId,
    required String serverId,
    required DateTime syncedAt,
  });
}

/// Prototype stand-in for `public.attendance_records` in Supabase.
abstract class AttendanceRemoteStore {
  Future<AttendanceRecord> upsert(AttendanceRecord record);

  Future<List<AttendanceRecord>> listForEmployee(Employee employee);
}

class MemoryAttendanceLocalStore implements AttendanceLocalStore {
  MemoryAttendanceLocalStore({List<AttendanceRecord>? seed})
    : _records = [...?seed];

  factory MemoryAttendanceLocalStore.withDemoSeed() {
    return MemoryAttendanceLocalStore(
      seed: SampleData.historyFor(SampleData.demoEmployee),
    );
  }

  final List<AttendanceRecord> _records;

  @override
  Future<List<AttendanceRecord>> listForEmployee(Employee employee) async {
    return _records
        .where(
          (record) => record.employee.employeeNumber == employee.employeeNumber,
        )
        .toList()
      ..sort((a, b) => b.checkInAt.compareTo(a.checkInAt));
  }

  @override
  Future<AttendanceRecord?> find({
    required String eventId,
    required Employee employee,
  }) async {
    for (final record in _records) {
      if (record.event.id == eventId &&
          record.employee.employeeNumber == employee.employeeNumber) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<AttendanceRecord> upsert(AttendanceRecord record) async {
    final existing = await find(
      eventId: record.event.id,
      employee: record.employee,
    );
    if (existing != null) {
      return existing;
    }
    _records.insert(0, record);
    return record;
  }

  @override
  Future<List<AttendanceRecord>> pendingFor(Employee employee) async {
    return (await listForEmployee(
      employee,
    )).where((record) => record.isPending).toList();
  }

  @override
  Future<void> markSynced({
    required String clientRecordId,
    required String serverId,
    required DateTime syncedAt,
  }) async {
    final index = _records.indexWhere(
      (record) => record.clientRecordId == clientRecordId,
    );
    if (index < 0) {
      return;
    }
    _records[index] = _records[index].copyWith(
      serverId: serverId,
      syncStatus: SyncStatus.synced,
      syncedAt: syncedAt,
    );
  }
}

class MemoryAttendanceRemoteStore implements AttendanceRemoteStore {
  MemoryAttendanceRemoteStore({List<AttendanceRecord>? seed})
    : _records = [...?seed];

  factory MemoryAttendanceRemoteStore.withDemoSeed() {
    return MemoryAttendanceRemoteStore(
      seed: SampleData.historyFor(SampleData.demoEmployee),
    );
  }

  final List<AttendanceRecord> _records;

  @override
  Future<AttendanceRecord> upsert(AttendanceRecord record) async {
    final index = _records.indexWhere(
      (item) => item.clientRecordId == record.clientRecordId,
    );
    final stored = record.copyWith(
      serverId: record.serverId ?? record.clientRecordId,
      syncStatus: SyncStatus.synced,
      syncedAt: record.syncedAt ?? DateTime.now().toUtc(),
    );
    if (index >= 0) {
      _records[index] = stored;
    } else {
      _records.add(stored);
    }
    return stored;
  }

  @override
  Future<List<AttendanceRecord>> listForEmployee(Employee employee) async {
    return _records
        .where(
          (record) => record.employee.employeeNumber == employee.employeeNumber,
        )
        .toList();
  }
}
