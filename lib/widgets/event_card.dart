import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import 'app_vector.dart';
import 'soft_card.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.actionLabel = 'Open',
    this.enabled = true,
  });

  final ProvincialEvent event;
  final VoidCallback? onTap;
  final String actionLabel;
  final bool enabled;

  Color get _accent {
    return switch (event.effectiveStatus()) {
      EventStatus.ongoing => AppColors.mint,
      EventStatus.published => AppColors.sky,
      EventStatus.completed => AppColors.lavender,
      _ => AppColors.peach,
    };
  }

  Color get _accentDeep {
    return switch (event.effectiveStatus()) {
      EventStatus.ongoing => AppColors.mintDeep,
      EventStatus.published => AppColors.skyDeep,
      EventStatus.completed => AppColors.lavenderDeep,
      _ => AppColors.peachDeep,
    };
  }

  String get _badgeAsset {
    return switch (event.effectiveStatus()) {
      EventStatus.ongoing => AppVectors.categoryOngoing,
      EventStatus.published => AppVectors.categoryUpcoming,
      EventStatus.completed => AppVectors.ticketPass,
      _ => AppVectors.eventBadge,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SoftCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppVector(_badgeAsset, width: 32, height: 32),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(event: event, color: _accentDeep, fill: _accent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              event.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Meta(
                        icon: Icons.calendar_today_outlined,
                        label: event.cardDateLabel,
                      ),
                      const SizedBox(height: 4),
                      _Meta(
                        icon: Icons.schedule_outlined,
                        label: event.scheduleLabel,
                      ),
                      if (event.requiresCheckOut) ...[
                        const SizedBox(height: 4),
                        const _Meta(
                          icon: Icons.logout_rounded,
                          label: 'Check-out required',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ActionBadge(label: actionLabel),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        event.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.label});

  final String label;

  ({Color fill, Color foreground, IconData icon}) get _style {
    return switch (label) {
      'Open' || 'Check-in' => (
        fill: AppColors.mint,
        foreground: AppColors.mintDeep,
        icon: Icons.login_rounded,
      ),
      'Check out' => (
        fill: AppColors.peach,
        foreground: AppColors.peachDeep,
        icon: Icons.logout_rounded,
      ),
      'Ended' => (
        fill: AppColors.lavender,
        foreground: AppColors.lavenderDeep,
        icon: Icons.event_busy_outlined,
      ),
      'Pending' => (
        fill: AppColors.peach,
        foreground: AppColors.peachDeep,
        icon: Icons.cloud_off_outlined,
      ),
      'Recorded' => (
        fill: AppColors.sky,
        foreground: AppColors.skyDeep,
        icon: Icons.check_rounded,
      ),
      _ => (
        fill: AppColors.line,
        foreground: AppColors.ink,
        icon: Icons.chevron_right_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: style.foreground,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
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
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
