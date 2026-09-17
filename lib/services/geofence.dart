import 'dart:math' as math;

import '../models/models.dart';
import 'location_service.dart';

const earthRadiusMeters = 6371000.0;

double distanceMeters({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  final dLat = _toRadians(toLat - fromLat);
  final dLng = _toRadians(toLng - fromLng);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(fromLat)) *
          math.cos(_toRadians(toLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

class GeofenceCheck {
  const GeofenceCheck({
    required this.position,
    required this.distanceMeters,
    required this.radiusMeters,
  });

  final DevicePosition position;
  final double distanceMeters;
  final int radiusMeters;

  bool get isInside => distanceMeters <= radiusMeters;

  int get distanceRounded => distanceMeters.round();

  String get distanceLabel => formatDistance(distanceMeters);

  /// Typical Android emulator GPS is thousands of kilometres from Davao.
  bool get isFarFromVenue => distanceMeters >= 5000;
}

GeofenceCheck checkGeofence({
  required EventLocation fence,
  required DevicePosition position,
}) {
  return GeofenceCheck(
    position: position,
    distanceMeters: distanceMeters(
      fromLat: fence.latitude,
      fromLng: fence.longitude,
      toLat: position.latitude,
      toLng: position.longitude,
    ),
    radiusMeters: fence.geofenceRadiusMeters,
  );
}

double _toRadians(double degrees) => degrees * math.pi / 180;

String formatDistance(double meters) {
  if (meters >= 1000) {
    final km = meters / 1000;
    if (km >= 10) {
      return '${km.round()} km';
    }
    return '${km.toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}
