import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';
import '../services/geofence.dart';
import '../services/location_service.dart';
import '../services/maps_config.dart';
import '../theme/app_theme.dart';

class GeofenceMap extends StatelessWidget {
  const GeofenceMap({
    super.key,
    required this.event,
    this.employee,
    this.check,
    this.height = 240,
  });

  final ProvincialEvent event;
  final DevicePosition? employee;
  final GeofenceCheck? check;
  final double height;

  bool get _useGoogleMaps {
    if (kIsWeb || !MapsConfig.isConfigured) {
      return false;
    }
    try {
      return Platform.environment['FLUTTER_TEST'] != 'true';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: _useGoogleMaps
            ? _GoogleGeofenceMap(event: event, employee: employee, check: check)
            : _FallbackGeofenceMap(event: event, check: check),
      ),
    );
  }
}

class _GoogleGeofenceMap extends StatefulWidget {
  const _GoogleGeofenceMap({required this.event, this.employee, this.check});

  final ProvincialEvent event;
  final DevicePosition? employee;
  final GeofenceCheck? check;

  @override
  State<_GoogleGeofenceMap> createState() => _GoogleGeofenceMapState();
}

class _GoogleGeofenceMapState extends State<_GoogleGeofenceMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant _GoogleGeofenceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee?.latitude != widget.employee?.latitude ||
        oldWidget.employee?.longitude != widget.employee?.longitude) {
      unawaited(_fitCamera());
    }
  }

  Future<void> _fitCamera() async {
    final controller = _controller;
    final employee = widget.employee;
    if (controller == null || employee == null) {
      return;
    }

    final distance =
        widget.check?.distanceMeters ??
        distanceMeters(
          fromLat: widget.event.location.latitude,
          fromLng: widget.event.location.longitude,
          toLat: employee.latitude,
          toLng: employee.longitude,
        );
    if (distance <= 400) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) {
      return;
    }

    final south = math.min(widget.event.location.latitude, employee.latitude);
    final north = math.max(widget.event.location.latitude, employee.latitude);
    final west = math.min(widget.event.location.longitude, employee.longitude);
    final east = math.max(widget.event.location.longitude, employee.longitude);
    if (south == north || west == east) {
      return;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          64,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      widget.event.location.latitude,
      widget.event.location.longitude,
    );
    final employee = widget.employee;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('event'),
        position: center,
        infoWindow: InfoWindow(title: widget.event.venue),
      ),
    };
    if (employee != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('you'),
          position: LatLng(employee.latitude, employee.longitude),
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: _zoomForRadius(widget.event.location.geofenceRadiusMeters),
          ),
          onMapCreated: (controller) {
            _controller = controller;
            unawaited(_fitCamera());
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          markers: markers,
          circles: {
            Circle(
              circleId: const CircleId('geofence'),
              center: center,
              radius: widget.event.location.geofenceRadiusMeters.toDouble(),
              fillColor: AppColors.lavenderDeep.withValues(alpha: 0.18),
              strokeColor: AppColors.lavenderDeep.withValues(alpha: 0.8),
              strokeWidth: 2,
            ),
          },
        ),
        if (widget.check != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.lighter,
              ),
              child: Text(
                widget.check!.isInside
                    ? 'Inside geofence · ${widget.check!.distanceLabel}'
                    : widget.check!.isFarFromVenue
                    ? 'GPS is ${widget.check!.distanceLabel} away · ${widget.check!.position.coordinateLabel}'
                    : 'Outside geofence · ${widget.check!.distanceLabel} away',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

double _zoomForRadius(int meters) {
  if (meters <= 50) {
    return 18;
  }
  if (meters <= 120) {
    return 17;
  }
  if (meters <= 250) {
    return 16;
  }
  return 15;
}

class _FallbackGeofenceMap extends StatelessWidget {
  const _FallbackGeofenceMap({required this.event, this.check});

  final ProvincialEvent event;
  final GeofenceCheck? check;

  @override
  Widget build(BuildContext context) {
    final inside = check?.isInside ?? false;
    final youAlignment = inside
        ? const Alignment(0.12, 0.12)
        : const Alignment(0.72, 0.62);
    return Stack(
      children: [
        CustomPaint(painter: _MapPainter(), child: const SizedBox.expand()),
        Align(
          alignment: const Alignment(0.08, -0.08),
          child: _Pin(
            color: AppColors.lavenderDeep,
            icon: Icons.account_balance_outlined,
            label: 'Event',
          ),
        ),
        Align(
          alignment: youAlignment,
          child: _Pin(
            color: inside ? AppColors.skyDeep : AppColors.peachDeep,
            icon: Icons.person_pin_circle_outlined,
            label: 'You',
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.lighter,
            ),
            child: Row(
              children: [
                Icon(
                  inside
                      ? Icons.my_location_rounded
                      : Icons.location_off_outlined,
                  size: 18,
                  color: inside ? AppColors.mintDeep : AppColors.peachDeep,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    check == null
                        ? 'Finding your location…'
                        : inside
                        ? 'Inside geofence · ${event.location.geofenceRadiusMeters} m radius'
                        : 'Outside geofence · ${event.location.geofenceRadiusMeters} m radius',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Icon(icon, color: color, size: 36),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = AppColors.mapLand;
    canvas.drawRect(Offset.zero & size, land);

    final water = Paint()..color = AppColors.mapWater;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.62,
          size.height * 0.08,
          size.width * 0.5,
          size.height * 0.9,
        ),
        const Radius.circular(80),
      ),
      water,
    );

    final road = Paint()
      ..color = AppColors.mapRoad
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.38),
      Offset(size.width, size.height * 0.46),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.42, size.height),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.72),
      Offset(size.width * 0.7, size.height * 0.58),
      road,
    );

    final park = Paint()..color = const Color(0xFFB7D3B4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.42, size.height * 0.42),
          width: 86,
          height: 64,
        ),
        const Radius.circular(16),
      ),
      park,
    );

    final geofence = Paint()
      ..color = AppColors.lavenderDeep.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final geofenceStroke = Paint()
      ..color = AppColors.lavenderDeep.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.width * 0.48, size.height * 0.42);
    canvas.drawCircle(center, 58, geofence);
    canvas.drawCircle(center, 58, geofenceStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
