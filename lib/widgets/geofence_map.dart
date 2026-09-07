import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class GeofenceMap extends StatelessWidget {
  const GeofenceMap({super.key, required this.event, this.height = 240});

  final ProvincialEvent event;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
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
            const Align(
              alignment: Alignment(0.22, 0.28),
              child: _Pin(
                color: AppColors.skyDeep,
                icon: Icons.person_pin_circle_outlined,
                label: 'You',
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.lighter,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      size: 18,
                      color: AppColors.mintDeep,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Inside geofence · ${event.location.geofenceRadiusMeters} m radius',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${event.location.latitude.toStringAsFixed(4)}° N',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
