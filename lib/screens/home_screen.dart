import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/event_card.dart';
import 'check_in_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final employee = session.employee;
    final events = session.visibleEvents;
    final ongoingCount =
        events.where((event) => event.status == EventStatus.ongoing).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            _RoundIconButton(icon: Icons.search_rounded, onTap: () {}),
            const SizedBox(width: 8),
            _RoundIconButton(
              icon: Icons.notifications_none_rounded,
              onTap: () {},
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
        const SizedBox(height: 18),
        const AppVector(AppVectors.heroAttendance, height: 112),
        const SizedBox(height: 18),
        TextField(
          key: const Key('home-search'),
          controller: _searchController,
          onChanged: session.updateSearch,
          decoration: const InputDecoration(
            hintText: 'Search events or venues',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 118,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryTile(
                label: 'All',
                asset: AppVectors.categoryAll,
                color: AppColors.lavender,
                selected: session.statusFilter == null,
                onTap: () => session.updateStatusFilter(null),
              ),
              _CategoryTile(
                label: 'Ongoing',
                asset: AppVectors.categoryOngoing,
                color: AppColors.mint,
                badge: ongoingCount > 0 ? '$ongoingCount' : null,
                selected: session.statusFilter == EventStatus.ongoing,
                onTap: () => session.updateStatusFilter(EventStatus.ongoing),
              ),
              _CategoryTile(
                label: 'Upcoming',
                asset: AppVectors.categoryUpcoming,
                color: AppColors.sky,
                selected: session.statusFilter == EventStatus.published,
                onTap: () => session.updateStatusFilter(EventStatus.published),
              ),
              _CategoryTile(
                label: 'Done',
                asset: AppVectors.categoryDone,
                color: AppColors.peach,
                selected: session.statusFilter == EventStatus.completed,
                onTap: () => session.updateStatusFilter(EventStatus.completed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
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
        const SizedBox(height: 14),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('No events match your search.')),
          )
        else
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: EventCard(
                event: event,
                onTap: () {
                  session.selectEvent(event);
                  Navigator.of(context).pushNamed(
                    CheckInScreen.routeName,
                    arguments: event,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
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
