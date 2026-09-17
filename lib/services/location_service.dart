import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationFault { denied, disabled, unavailable, failed }

class DevicePosition {
  const DevicePosition({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  String get coordinateLabel =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}

class LocationResult {
  const LocationResult._({this.position, this.fault, this.message});

  const LocationResult.ok(DevicePosition position) : this._(position: position);

  const LocationResult.error(LocationFault fault, String message)
    : this._(fault: fault, message: message);

  final DevicePosition? position;
  final LocationFault? fault;
  final String? message;

  bool get hasFix => position != null;
}

abstract class LocationService {
  Future<LocationResult> currentPosition();
}

class StubLocationService implements LocationService {
  const StubLocationService({
    this.position = const DevicePosition(latitude: 6.7492, longitude: 125.3571),
    this.fault,
    this.message,
  });

  final DevicePosition position;
  final LocationFault? fault;
  final String? message;

  @override
  Future<LocationResult> currentPosition() async {
    final currentFault = fault;
    if (currentFault != null) {
      return LocationResult.error(
        currentFault,
        message ?? 'Location is not available in this test.',
      );
    }
    return LocationResult.ok(position);
  }
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  @override
  Future<LocationResult> currentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult.error(
          LocationFault.disabled,
          'Turn on Location Services, then try again.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.error(
          LocationFault.denied,
          'Allow location access so PEAM can confirm you are at the venue.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.error(
          LocationFault.denied,
          'Location is blocked for PEAM. Enable it in system Settings, then return here.',
        );
      }

      final fix = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(),
      );
      return LocationResult.ok(
        DevicePosition(
          latitude: fix.latitude,
          longitude: fix.longitude,
          accuracyMeters: fix.accuracy,
        ),
      );
    } on LocationServiceDisabledException {
      return const LocationResult.error(
        LocationFault.disabled,
        'Turn on Location Services, then try again.',
      );
    } catch (_) {
      return const LocationResult.error(
        LocationFault.failed,
        'Could not read GPS. Move to an open area and try again.',
      );
    }
  }
}

LocationSettings _locationSettings() {
  const timeLimit = Duration(seconds: 25);
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        // Fused Location on the emulator often stays at Mountain View even
        // after Extended Controls are updated. LocationManager reads geo fix.
        forceLocationManager: true,
        timeLimit: timeLimit,
      );
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: timeLimit,
      );
    default:
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      );
  }
}
