import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geofence.dart';
import '../state/location_scope.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/geofence_map.dart';
import '../widgets/primary_button.dart';
import '../widgets/soft_card.dart';
import 'biometric_screen.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  static const routeName = '/check-in';

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  bool _loading = true;
  String? _error;
  GeofenceCheck? _check;

  ProvincialEvent? get _event {
    return ModalRoute.of(context)?.settings.arguments as ProvincialEvent? ??
        SessionScope.of(context).selectedEvent;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_locate());
    });
  }

  bool _isCheckingOut(ProvincialEvent event) {
    return event.needsCheckOut(SessionScope.of(context).recordFor(event.id));
  }

  bool _alreadyRecorded(ProvincialEvent event) {
    final record = SessionScope.of(context).recordFor(event.id);
    return record != null && !event.needsCheckOut(record);
  }

  bool _windowOpen(ProvincialEvent event) {
    if (_alreadyRecorded(event)) {
      return false;
    }
    return _isCheckingOut(event)
        ? event.allowsCheckOut()
        : event.allowsCheckIn();
  }

  Future<void> _locate() async {
    final event = _event;
    if (event == null) {
      return;
    }
    if (_alreadyRecorded(event)) {
      SessionScope.of(context).stageGeofence(null);
      setState(() {
        _loading = false;
        _check = null;
        _error = 'Attendance for this event is already recorded.';
      });
      return;
    }
    if (!_windowOpen(event)) {
      SessionScope.of(context).stageGeofence(null);
      setState(() {
        _loading = false;
        _check = null;
        _error = _isCheckingOut(event)
            ? 'Check-out is not available for this event.'
            : 'Check-in closed at ${event.endTime}. This event has ended.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await LocationScope.of(context).currentPosition();
    if (!mounted) {
      return;
    }
    final position = result.position;
    if (position == null) {
      SessionScope.of(context).stageGeofence(null);
      setState(() {
        _loading = false;
        _check = null;
        _error = result.message ?? 'Could not read GPS.';
      });
      return;
    }

    final check = checkGeofence(fence: event.location, position: position);
    SessionScope.of(context).stageGeofence(check);
    setState(() {
      _loading = false;
      _check = check;
      _error = null;
    });
  }

  void _continue() {
    final event = _event;
    final check = _check;
    if (event == null ||
        !_windowOpen(event) ||
        check == null ||
        !check.isInside) {
      return;
    }
    SessionScope.of(context).selectEvent(event);
    SessionScope.of(context).stageGeofence(check);
    SessionScope.of(context).stageAttendanceAction(
      _isCheckingOut(event)
          ? AttendanceAction.checkOut
          : AttendanceAction.checkIn,
    );
    Navigator.of(context).pushNamed(BiometricScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionScope.of(context),
      builder: (context, _) {
        final event = _event;
        if (event == null) {
          return const Scaffold(
            body: Center(child: Text('No event selected.')),
          );
        }

        final check = _check;
        final inside = check?.isInside ?? false;
        final checkingOut = _isCheckingOut(event);
        final alreadyRecorded = _alreadyRecorded(event);
        final windowOpen = _windowOpen(event);
        final actionLabel = checkingOut ? 'Check-out' : 'Check-in';

        return Scaffold(
          appBar: AppBar(
            title: Text(checkingOut ? 'Check out' : 'Check in'),
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
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GeofenceMap(
                      event: event,
                      employee: check?.position,
                      check: check,
                    ),
                    const SizedBox(height: 16),
                    SoftCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const AppVector(
                            AppVectors.mapPin,
                            width: 56,
                            height: 56,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _loading
                                      ? 'Checking your location'
                                      : alreadyRecorded
                                      ? 'Already recorded'
                                      : !windowOpen
                                      ? (checkingOut
                                            ? 'Check-out unavailable'
                                            : 'Check-in closed')
                                      : inside
                                      ? 'Location verified'
                                      : 'Outside the event area',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alreadyRecorded
                                      ? 'This event already has your attendance on this device.'
                                      : !windowOpen
                                      ? (checkingOut
                                            ? 'Check-out is not available for this event.'
                                            : 'Check-in closed at ${event.endTime}. This event has ended.')
                                      : event.venue,
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
                            isLast: !event.requiresCheckOut && check == null,
                          ),
                          if (event.requiresCheckOut)
                            _DetailRow(
                              icon: Icons.logout_rounded,
                              label: checkingOut
                                  ? 'Check-out required to complete attendance'
                                  : alreadyRecorded
                                  ? 'Check-out recorded'
                                  : 'This event requires a check-out',
                              isLast: check == null,
                            ),
                          if (check != null)
                            _DetailRow(
                              icon: Icons.my_location_outlined,
                              label:
                                  'Your GPS · ${check.position.coordinateLabel}',
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SoftCard(
                      color: _statusColor,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(_statusIcon, color: _statusIconColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusMessage(event),
                              style: const TextStyle(
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
                    label: alreadyRecorded
                        ? 'Already recorded'
                        : !windowOpen
                        ? (checkingOut
                              ? 'Check-out unavailable'
                              : 'Event ended')
                        : _loading
                        ? 'Checking location'
                        : inside
                        ? actionLabel
                        : 'Recheck location',
                    icon: alreadyRecorded
                        ? Icons.check_rounded
                        : !windowOpen
                        ? Icons.event_busy_rounded
                        : inside
                        ? (checkingOut
                              ? Icons.logout_rounded
                              : Icons.how_to_reg_rounded)
                        : Icons.my_location_rounded,
                    loading: _loading,
                    onPressed: !windowOpen || _loading
                        ? null
                        : inside
                        ? _continue
                        : _locate,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color get _statusColor {
    if (_loading) {
      return AppColors.sky;
    }
    final event = _event;
    if (_error != null ||
        event == null ||
        !_windowOpen(event) ||
        _check?.isInside != true) {
      return AppColors.peach;
    }
    return AppColors.mint;
  }

  IconData get _statusIcon {
    if (_loading) {
      return Icons.gps_fixed;
    }
    final event = _event;
    if (event != null && !_windowOpen(event)) {
      return Icons.event_busy_outlined;
    }
    if (_error != null) {
      return Icons.location_off_outlined;
    }
    if (_check?.isInside == true) {
      return Icons.check_circle_rounded;
    }
    return Icons.wrong_location_outlined;
  }

  Color get _statusIconColor {
    if (_check?.isInside == true) {
      return AppColors.mintDeep;
    }
    if (_loading) {
      return AppColors.skyDeep;
    }
    return AppColors.peachDeep;
  }

  String _statusMessage(ProvincialEvent event) {
    final checkingOut = _isCheckingOut(event);
    if (_alreadyRecorded(event)) {
      return 'Attendance for this event is already recorded.';
    }
    if (!_windowOpen(event)) {
      return checkingOut
          ? 'Check-out is not available for this event.'
          : 'Check-in closed at ${event.endTime}. This event has ended.';
    }
    if (_loading) {
      return 'Reading GPS to confirm you are inside the ${event.location.geofenceRadiusMeters} m geofence.';
    }
    if (_error != null) {
      return _error!;
    }
    final check = _check;
    if (check == null) {
      return checkingOut
          ? 'Location is required before check-out.'
          : 'Location is required before check-in.';
    }
    if (check.isInside) {
      return 'You are ${check.distanceLabel} from the venue and inside the permitted area.';
    }
    if (check.isFarFromVenue) {
      return 'Your device GPS is ${check.distanceLabel} from this venue (${check.position.coordinateLabel}). The map is zoomed to the event, so that is not your pin. On an emulator, set the simulated location to ${event.location.latitude.toStringAsFixed(4)}, ${event.location.longitude.toStringAsFixed(4)}, then recheck.';
    }
    return 'You are ${check.distanceLabel} from the venue. Move inside the ${check.radiusMeters} m geofence, then recheck.';
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
