import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import 'app_vector.dart';
import 'soft_card.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onTap});

  final ProvincialEvent event;
  final VoidCallback onTap;

  Color get _accent {
    return switch (event.status) {
      EventStatus.ongoing => AppColors.mint,
      EventStatus.published => AppColors.sky,
      EventStatus.completed => AppColors.lavender,
      _ => AppColors.peach,
    };
  }

  Color get _accentDeep {
    return switch (event.status) {
      EventStatus.ongoing => AppColors.mintDeep,
      EventStatus.published => AppColors.skyDeep,
      EventStatus.completed => AppColors.lavenderDeep,
      _ => AppColors.peachDeep,
    };
  }

  String get _badgeAsset {
    return switch (event.status) {
      EventStatus.ongoing => AppVectors.categoryOngoing,
      EventStatus.published => AppVectors.categoryUpcoming,
      EventStatus.completed => AppVectors.ticketPass,
      _ => AppVectors.eventBadge,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      key: ValueKey('event-card-${event.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AppVector(_badgeAsset, width: 40, height: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.venue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(event: event, color: _accentDeep, fill: _accent),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            event.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _Meta(icon: Icons.schedule_outlined, label: event.scheduleLabel),
                    _Meta(
                      icon: Icons.calendar_today_outlined,
                      label: event.dateLabel.split(',').first,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.button,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadii.pill)),
                ),
                child: const Text(
                  'Open',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.event,
    required this.color,
    required this.fill,
  });

  final ProvincialEvent event;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        event.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
