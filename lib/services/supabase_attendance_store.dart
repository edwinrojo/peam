import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'attendance_stores.dart';
import 'events_catalog.dart';

/// Live `public.attendance_records` store. Local SQLite remains the offline queue.
class SupabaseAttendanceRemoteStore implements AttendanceRemoteStore {
  SupabaseAttendanceRemoteStore({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 12);
  static const _select = '''
id, event_id, check_in_at, check_out_at,
check_in_latitude, check_in_longitude, check_out_latitude, check_out_longitude,
geofence_verified, biometric_verified, verification_status, attendance_status,
recorded_offline, sync_status, client_record_id, client_recorded_at, synced_at,
events!event_id (id, name, description, event_date, start_time, end_time, venue, latitude, longitude, geofence_radius_meters, status)
''';
  static const _upsertSelect =
      'id, synced_at, attendance_status, verification_status, sync_status, client_record_id';

  @override
  Future<AttendanceRecord> upsert(AttendanceRecord record) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before uploading attendance.');
    }

    String? deviceId;
    try {
      deviceId = await _activeDeviceId(userId);
    } catch (_) {}

    final payload = attendanceInsertPayload(
      profileId: userId,
      deviceId: deviceId,
      record: record,
    );

    try {
      final row = await _client
          .from('attendance_records')
          .upsert(payload, onConflict: 'client_record_id')
          .select(_upsertSelect)
          .single()
          .timeout(_timeout);
      return attendanceRecordFromSupabaseRow(row, record.employee) ??
          _fallbackSynced(record, row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') {
        rethrow;
      }
      final existing = await _existingForEvent(
        profileId: userId,
        eventId: record.event.id,
        employee: record.employee,
      );
      if (existing != null) {
        return existing;
      }
      rethrow;
    }
  }

  @override
  Future<List<AttendanceRecord>> listForEmployee(Employee employee) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }
    Object response;
    try {
      response = await _client
          .from('attendance_records')
          .select(_select)
          .eq('profile_id', userId)
          .order('check_in_at', ascending: false)
          .timeout(_timeout);
    } catch (_) {
      response = await _client
          .from('attendance_records')
          .select(_upsertSelect)
          .eq('profile_id', userId)
          .order('check_in_at', ascending: false)
          .timeout(_timeout);
    }
    final rows = response as List<dynamic>;
    return [
      for (final row in rows)
        if (row is Map)
          ?attendanceRecordFromSupabaseRow(
            Map<String, dynamic>.from(row),
            employee,
          ),
    ];
  }

  Future<String?> _activeDeviceId(String profileId) async {
    final row = await _client
        .from('devices')
        .select('id')
        .eq('profile_id', profileId)
        .eq('is_active', true)
        .maybeSingle()
        .timeout(_timeout);
    return row?['id']?.toString();
  }

  Future<AttendanceRecord?> _existingForEvent({
    required String profileId,
    required String eventId,
    required Employee employee,
  }) async {
    final row = await _client
        .from('attendance_records')
        .select(_select)
        .eq('profile_id', profileId)
        .eq('event_id', eventId)
        .maybeSingle()
        .timeout(_timeout);
    if (row == null) {
      return null;
    }
    return attendanceRecordFromSupabaseRow(row, employee);
  }

  AttendanceRecord _fallbackSynced(
    AttendanceRecord record,
    Map<String, dynamic> row,
  ) {
    return record.copyWith(
      serverId: row['id']?.toString() ?? record.clientRecordId,
      syncStatus: SyncStatus.synced,
      syncedAt: parseAttendanceTime(row['synced_at']) ?? DateTime.now().toUtc(),
      attendanceStatus: parseAttendanceStatus(row['attendance_status']),
    );
  }
}

Map<String, Object?> attendanceInsertPayload({
  required String profileId,
  required String? deviceId,
  required AttendanceRecord record,
}) {
  return {
    'event_id': record.event.id,
    'profile_id': profileId,
    'device_id': deviceId,
    'check_in_at': record.checkInAt.toUtc().toIso8601String(),
    'check_out_at': record.checkOutAt?.toUtc().toIso8601String(),
    'check_in_latitude': record.checkInLatitude,
    'check_in_longitude': record.checkInLongitude,
    'check_out_latitude': record.checkOutLatitude,
    'check_out_longitude': record.checkOutLongitude,
    'geofence_verified': record.geofenceVerified,
    'biometric_verified': record.biometricVerified,
    'verification_status': record.verificationStatus.name,
    'attendance_status': record.attendanceStatus.name,
    'recorded_offline': record.recordedOffline,
    'client_record_id': record.clientRecordId,
    'client_recorded_at': record.clientRecordedAt.toUtc().toIso8601String(),
  };
}

AttendanceRecord? attendanceRecordFromSupabaseRow(
  Map<String, dynamic> row,
  Employee employee,
) {
  final eventPayload = row['events'];
  ProvincialEvent? event;
  if (eventPayload is Map) {
    event = provincialEventFromRow(
      Map<String, dynamic>.from(eventPayload),
      includeHidden: true,
    );
  }
  if (event == null) {
    return null;
  }
  final checkInAt = parseAttendanceTime(row['check_in_at']);
  if (checkInAt == null) {
    return null;
  }
  final clientRecordId =
      row['client_record_id']?.toString() ?? row['id']?.toString();
  if (clientRecordId == null || clientRecordId.isEmpty) {
    return null;
  }
  return AttendanceRecord(
    clientRecordId: clientRecordId,
    serverId: row['id']?.toString(),
    event: event,
    employee: employee,
    checkInAt: checkInAt,
    checkOutAt: parseAttendanceTime(row['check_out_at']),
    checkInLatitude: _asDouble(row['check_in_latitude']),
    checkInLongitude: _asDouble(row['check_in_longitude']),
    checkOutLatitude: _asDouble(row['check_out_latitude']),
    checkOutLongitude: _asDouble(row['check_out_longitude']),
    geofenceVerified: row['geofence_verified'] == true,
    biometricVerified: row['biometric_verified'] == true,
    verificationStatus: parseVerificationStatus(row['verification_status']),
    attendanceStatus: parseAttendanceStatus(row['attendance_status']),
    recordedOffline: row['recorded_offline'] == true,
    syncStatus: SyncStatus.synced,
    clientRecordedAt:
        parseAttendanceTime(row['client_recorded_at']) ?? checkInAt,
    syncedAt: parseAttendanceTime(row['synced_at']),
  );
}

DateTime? parseAttendanceTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toUtc();
}

AttendanceStatus parseAttendanceStatus(Object? value) {
  final name = value?.toString().trim().toLowerCase();
  return AttendanceStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => AttendanceStatus.incomplete,
  );
}

VerificationStatus parseVerificationStatus(Object? value) {
  final name = value?.toString().trim().toLowerCase();
  return VerificationStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => VerificationStatus.pending,
  );
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}
