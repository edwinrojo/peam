import 'package:flutter_test/flutter_test.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/models/models.dart';
import 'package:peam/services/supabase_attendance_store.dart';

void main() {
  final employee = SampleData.demoEmployee;
  final event = SampleData.events.first;

  test('maps a Supabase attendance row with its nested event', () {
    final record = attendanceRecordFromSupabaseRow({
      'id': 'a11e0000-0000-4000-8000-00000000aa01',
      'client_record_id': 'c0a80100-0000-4000-8000-00000000aa01',
      'check_in_at': '2026-09-17T00:15:00.000Z',
      'check_in_latitude': 6.7492,
      'check_in_longitude': 125.3571,
      'geofence_verified': true,
      'biometric_verified': true,
      'verification_status': 'verified',
      'attendance_status': 'incomplete',
      'recorded_offline': true,
      'sync_status': 'synced',
      'client_recorded_at': '2026-09-17T00:15:00.000Z',
      'synced_at': '2026-09-17T01:02:00.000Z',
      'events': {
        'id': event.id,
        'name': event.name,
        'description': event.description,
        'event_date': '2026-09-17',
        'start_time': '08:00:00',
        'end_time': '17:00:00',
        'venue': event.venue,
        'latitude': event.location.latitude,
        'longitude': event.location.longitude,
        'geofence_radius_meters': event.location.geofenceRadiusMeters,
        'status': 'ongoing',
      },
    }, employee);

    expect(record, isNotNull);
    expect(record!.serverId, 'a11e0000-0000-4000-8000-00000000aa01');
    expect(record.clientRecordId, 'c0a80100-0000-4000-8000-00000000aa01');
    expect(record.event.name, event.name);
    expect(record.recordedOffline, isTrue);
    expect(record.syncStatus, SyncStatus.synced);
    expect(record.geofenceVerified, isTrue);
    expect(record.checkInLatitude, closeTo(6.7492, 0.0001));
  });

  test('insert payload uses profile_id, client_record_id, and GPS', () {
    final record = AttendanceRecord(
      clientRecordId: 'c0a80100-0000-4000-8000-00000000aa02',
      event: event,
      employee: employee,
      checkInAt: DateTime.utc(2026, 9, 17, 8, 15),
      checkInLatitude: 6.7492,
      checkInLongitude: 125.3571,
      recordedOffline: true,
      geofenceVerified: true,
      biometricVerified: true,
      clientRecordedAt: DateTime.utc(2026, 9, 17, 8, 15),
    );

    final payload = attendanceInsertPayload(
      profileId: 'profile-1',
      deviceId: 'device-1',
      record: record,
    );

    expect(payload['event_id'], event.id);
    expect(payload['profile_id'], 'profile-1');
    expect(payload['device_id'], 'device-1');
    expect(payload['client_record_id'], record.clientRecordId);
    expect(payload['recorded_offline'], isTrue);
    expect(payload['check_in_latitude'], 6.7492);
    expect(payload['geofence_verified'], isTrue);
    expect(payload['biometric_verified'], isTrue);
    expect(payload.containsKey('sync_status'), isFalse);
  });
}
