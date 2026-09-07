import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/geofence_map.dart';
import '../widgets/primary_button.dart';
import '../widgets/soft_card.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import 'biometric_screen.dart';

class CheckInScreen extends StatelessWidget {
  const CheckInScreen({super.key});

  static const routeName = '/check-in';

  @override
  Widget build(BuildContext context) {
    final event =
        ModalRoute.of(context)?.settings.arguments as ProvincialEvent? ??
        SessionScope.of(context).selectedEvent;

    if (event == null) {
      return const Scaffold(body: Center(child: Text('No event selected.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check in'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: const TextStyle(color: AppColors.muted, height: 1.45),
                ),
                const SizedBox(height: 18),
                GeofenceMap(event: event),
                const SizedBox(height: 16),
                SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const AppVector(AppVectors.mapPin, width: 56, height: 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location verified',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.venue,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SoftCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: event.dateLabel,
                      ),
                      _DetailRow(
                        icon: Icons.schedule_outlined,
                        label: event.scheduleLabel,
                      ),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: event.venue,
                      ),
                      _DetailRow(
                        icon: Icons.radar_outlined,
                        label:
                            'Geofence ${event.location.geofenceRadiusMeters} m · ${event.location.latitude.toStringAsFixed(4)}, ${event.location.longitude.toStringAsFixed(4)}',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  color: AppColors.mint,
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.mintDeep,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You are 18 m from the venue and inside the permitted area.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                key: const Key('check-in-button'),
                label: 'Check-in',
                icon: Icons.how_to_reg_rounded,
                onPressed: () {
                  SessionScope.of(context).selectEvent(event);
                  Navigator.of(context).pushNamed(BiometricScreen.routeName);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.skyDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
