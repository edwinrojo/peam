import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/soft_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const routeName = '/notifications';

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final items = session.notifications;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              if (session.unreadNotificationCount > 0)
                TextButton(
                  key: const Key('mark-all-read'),
                  onPressed: session.markAllNotificationsRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SoftCard(
                  color: AppColors.lavender,
                  padding: const EdgeInsets.all(14),
                  child: const Text(
                    'Prototype mode: these simulate FCM push alerts from Supabase (event published, reminders, device-change updates). Tap “Simulate push” to fire an in-app item and a system banner.',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No notifications yet.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _NotificationTile(
                            notification: item,
                            onTap: () => session.markNotificationRead(item.id),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: PrimaryButton(
                    key: const Key('simulate-push-button'),
                    label: 'Simulate push',
                    icon: Icons.notifications_active_outlined,
                    onPressed: () async {
                      await session.simulateIncomingPush();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Simulated push added. Check the notification shade if permission is allowed.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.kind) {
    NotificationKind.eventPublished => Icons.event_available_outlined,
    NotificationKind.eventReminder => Icons.alarm_outlined,
    NotificationKind.deviceChangeUpdate => Icons.phonelink_setup_outlined,
    NotificationKind.attendanceSync => Icons.cloud_upload_outlined,
    NotificationKind.adminNotice => Icons.campaign_outlined,
  };

  Color get _tint => switch (notification.kind) {
    NotificationKind.eventPublished => AppColors.mint,
    NotificationKind.eventReminder => AppColors.peach,
    NotificationKind.deviceChangeUpdate => AppColors.sky,
    NotificationKind.attendanceSync => AppColors.lavender,
    NotificationKind.adminNotice => AppColors.line,
  };

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icon, color: AppColors.ink, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.lavenderDeep,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${notification.kindLabel} · ${_format(notification.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${time.month}/${time.day} $hour:$minute $period';
  }
}
