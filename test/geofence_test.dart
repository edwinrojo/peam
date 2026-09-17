import 'package:flutter_test/flutter_test.dart';
import 'package:peam/data/sample_data.dart';
import 'package:peam/services/geofence.dart';
import 'package:peam/services/location_service.dart';

void main() {
  test('distance is zero at the event center', () {
    final capitol = SampleData.capitol;
    expect(
      distanceMeters(
        fromLat: capitol.latitude,
        fromLng: capitol.longitude,
        toLat: capitol.latitude,
        toLng: capitol.longitude,
      ),
      0,
    );
  });

  test('a point about 111 m north is inside a 120 m geofence', () {
    final capitol = SampleData.capitol;
    final check = checkGeofence(
      fence: capitol,
      position: DevicePosition(
        latitude: capitol.latitude + 0.001,
        longitude: capitol.longitude,
      ),
    );

    expect(check.distanceMeters, closeTo(111.2, 2));
    expect(check.isInside, isTrue);
  });

  test('a far point is outside the geofence', () {
    final check = checkGeofence(
      fence: SampleData.capitol,
      position: const DevicePosition(latitude: 7.1, longitude: 125.6),
    );

    expect(check.isInside, isFalse);
    expect(check.distanceMeters, greaterThan(1000));
    expect(check.distanceLabel, contains('km'));
  });

  test('formatDistance switches to kilometres past 1 km', () {
    expect(formatDistance(80), '80 m');
    expect(formatDistance(1500), '1.5 km');
    expect(formatDistance(11496416), '11496 km');
  });

  test('emulator default GPS is treated as far from the Capitol', () {
    final check = checkGeofence(
      fence: SampleData.capitol,
      position: const DevicePosition(latitude: 37.4219, longitude: -122.0840),
    );

    expect(check.isFarFromVenue, isTrue);
    expect(check.distanceMeters, closeTo(11496000, 80000));
  });
}
