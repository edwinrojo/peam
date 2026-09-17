import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/event_card.dart';
import '../widgets/soft_card.dart';
import 'check_in_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  bool get _searching =>
      _searchFocus.hasFocus || _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_rebuildForSearch);
    _searchController.addListener(_syncSearchQuery);
  }

  @override
  void dispose() {
    _searchFocus
      ..removeListener(_rebuildForSearch)
      ..dispose();
    _searchController
      ..removeListener(_syncSearchQuery)
      ..dispose();
    super.dispose();
  }

  void _rebuildForSearch() {
    setState(() {});
  }

  void _syncSearchQuery() {
    if (!mounted) {
      return;
    }
    final session = SessionScope.of(context);
    if (session.searchQuery != _searchController.text) {
      session.updateSearch(_searchController.text);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    SessionScope.of(context).updateSearch('');
  }

  void _closeSearch() {
    _searchController.clear();
    SessionScope.of(context).updateSearch('');
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final employee = session.employee;
    final searching = _searching;
    final events = session.eventsMatching(ignoreStatusFilter: searching);
    final ongoingCount = session
        .eventsMatching(ignoreStatusFilter: true)
        .where((event) => event.effectiveStatus() == EventStatus.ongoing)
        .length;

    return PopScope(
      canPop: !searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeSearch();
        }
      },
      child: RefreshIndicator(
        onRefresh: session.refreshEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!searching) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.peachDeep,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            employee?.department.code ?? 'PEAM',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _RoundIconButton(
                      icon: Icons.search_rounded,
                      onTap: () => _searchFocus.requestFocus(),
                    ),
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: session,
                      builder: (context, _) {
                        return _NotificationButton(
                          unreadCount: session.unreadNotificationCount,
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed(NotificationsScreen.routeName);
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Good day, ${employee?.firstName ?? 'Employee'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Attendance Made Simple',
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  employee == null
                      ? 'Select an official provincial event to check in.'
                      : 'Device bound to ${employee.deviceName}',
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                _OfflineSyncBanner(session: session),
                const SizedBox(height: 18),
                const AppVector(AppVectors.heroAttendance, height: 112),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  if (searching)
                    IconButton(
                      key: const Key('home-search-back'),
                      tooltip: 'Close search',
                      onPressed: _closeSearch,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Expanded(
                    child: TextField(
                      key: const Key('home-search'),
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: session.updateSearch,
                      onSubmitted: (_) => _searchFocus.unfocus(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search events or venues',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: session.searchQuery.trim().isEmpty
                            ? null
                            : IconButton(
                                key: const Key('home-search-clear'),
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _clearSearch,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!searching) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 118,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryTile(
                        key: const Key('filter-all'),
                        label: 'All',
                        asset: AppVectors.categoryAll,
                        color: AppColors.line,
                        selected: session.statusFilter == null,
                        onTap: () => session.updateStatusFilter(null),
                      ),
                      _CategoryTile(
                        key: const Key('filter-ongoing'),
                        label: 'Ongoing',
                        asset: AppVectors.categoryOngoing,
                        color: AppColors.mint,
                        badge: ongoingCount > 0 ? '$ongoingCount' : null,
                        selected: session.statusFilter == EventStatus.ongoing,
                        onTap: () =>
                            session.updateStatusFilter(EventStatus.ongoing),
                      ),
                      _CategoryTile(
                        key: const Key('filter-upcoming'),
                        label: 'Upcoming',
                        asset: AppVectors.categoryUpcoming,
                        color: AppColors.sky,
                        selected: session.statusFilter == EventStatus.published,
                        onTap: () =>
                            session.updateStatusFilter(EventStatus.published),
                      ),
                      _CategoryTile(
                        key: const Key('filter-done'),
                        label: 'Done',
                        asset: AppVectors.categoryDone,
                        color: AppColors.lavender,
                        selected: session.statusFilter == EventStatus.completed,
                        onTap: () =>
                            session.updateStatusFilter(EventStatus.completed),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (searching)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    '${events.length} found',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    const Text(
                      'Official events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${events.length} found',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              if (!searching) const SizedBox(height: 14),
              if (session.eventsError != null) ...[
                SoftCard(
                  color: AppColors.peach,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    session.eventsError!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (session.isLoadingEvents && events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      session.searchQuery.trim().isEmpty &&
                              session.statusFilter == null &&
                              !searching
                          ? 'No published events yet.'
                          : 'No events match your search.',
                    ),
                  ),
                )
              else
                ...events.map((event) {
                  final recorded = session.recordFor(event.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: EventCard(
                      key: Key('event-card-${event.id}'),
                      event: event,
                      actionLabel: recorded == null
                          ? (event.allowsCheckIn() ? 'Open' : 'Ended')
                          : recorded.isPending
                          ? 'Pending'
                          : 'Recorded',
                      onTap: () {
                        session.selectEvent(event);
                        Navigator.of(
                          context,
                        ).pushNamed(CheckInScreen.routeName, arguments: event);
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.label,
    required this.asset,
    required this.color,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String asset;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 92,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.ink : Colors.transparent,
              width: 1.6,
            ),
            boxShadow: AppShadows.lighter,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppVector(asset, width: 42, height: 42),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: -6,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.button,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadii.pill),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppShadows.lighter,
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        key: const Key('notifications-button'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppShadows.lighter,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AppColors.ink,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.lavenderDeep,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadii.pill),
                      ),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineSyncBanner extends StatelessWidget {
  const _OfflineSyncBanner({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final pending = session.pendingCount;
    final online = session.isOnline;
    return SoftCard(
      color: online
          ? (pending > 0 ? AppColors.sky : AppColors.mint)
          : AppColors.peach,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: online
                ? (pending > 0 ? AppColors.skyDeep : AppColors.mintDeep)
                : AppColors.peachDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pending == 0
                  ? (online
                        ? 'Online · local attendance is synced'
                        : 'Offline · new check-ins stay on this device')
                  : (online
                        ? '$pending pending · open History to sync'
                        : '$pending pending · saved offline until connectivity returns'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
