import 'package:flutter/material.dart';

import '../services/biometric_auth_service.dart';
import '../services/device_guard.dart';
import '../state/biometric_scope.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/primary_button.dart';
import '../widgets/soft_card.dart';
import 'confirmation_screen.dart';
import 'login_screen.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  static const routeName = '/biometric';

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  bool _scanning = false;
  bool _loadingAvailability = true;
  BiometricMethod _method = BiometricMethod.fingerprint;
  BiometricAvailability _availability = BiometricAvailability.none;
  String? _error;
  bool _biometricsChanged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailability();
    });
  }

  Future<void> _loadAvailability() async {
    final session = SessionScope.of(context);
    final availability = await BiometricAuthScope.of(context).probe();
    final guard = await session.biometricGuardState();
    if (!mounted) {
      return;
    }
    setState(() {
      _availability = availability;
      _loadingAvailability = false;
      if (guard == BioGuardState.changed) {
        _biometricsChanged = true;
        _error =
            'A new fingerprint or face was added to this phone. Sign in again to confirm it is still you.';
        return;
      }
      if (availability.supports(BiometricMethod.fingerprint)) {
        _method = BiometricMethod.fingerprint;
      } else if (availability.supports(BiometricMethod.face)) {
        _method = BiometricMethod.face;
      }
      if (!availability.hasAny) {
        _error =
            'This phone has no fingerprint or face unlock set up. Add one in your phone settings, then come back to PEAM.';
      }
    });
  }

  Future<void> _signInAgain() async {
    final session = SessionScope.of(context);
    await session.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _authenticate() async {
    if (_scanning || _biometricsChanged || !_availability.supports(_method)) {
      return;
    }
    setState(() {
      _scanning = true;
      _error = null;
    });

    final result = await BiometricAuthScope.of(
      context,
    ).authenticate(method: _method);

    if (!mounted) {
      return;
    }
    if (!result.authenticated) {
      setState(() {
        _scanning = false;
        _error = result.message;
      });
      return;
    }
    final event = SessionScope.of(context).selectedEvent;
    final session = SessionScope.of(context);
    final checkingOut =
        event != null && event.needsCheckOut(session.recordFor(event.id));
    if (event == null ||
        (checkingOut ? !event.allowsCheckOut() : !event.allowsCheckIn())) {
      setState(() {
        _scanning = false;
        _error = checkingOut
            ? 'Check-out is not available for this event.'
            : event?.checkInClosedDetail ??
                  'Check-in is not available for this event.';
      });
      return;
    }
    await session.armBiometricGuardIfMissing();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(ConfirmationScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final canAuthenticate =
        !_scanning &&
        !_loadingAvailability &&
        !_biometricsChanged &&
        _availability.supports(_method);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm it is you'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _scanning ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: [
                    const Text(
                      'Verify it is you',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use this phone’s built-in fingerprint or face unlock. PEAM never stores your fingerprint or face.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 28),
                    const AppVector(
                      AppVectors.biometric,
                      width: 180,
                      height: 180,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _MethodCard(
                            selected: _method == BiometricMethod.face,
                            enabled:
                                !_scanning &&
                                _availability.supports(BiometricMethod.face),
                            icon: Icons.face_retouching_natural,
                            label: 'Face',
                            caption: _captionFor(BiometricMethod.face),
                            onTap: () => setState(() {
                              _method = BiometricMethod.face;
                              _error = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MethodCard(
                            selected: _method == BiometricMethod.fingerprint,
                            enabled:
                                !_scanning &&
                                _availability.supports(
                                  BiometricMethod.fingerprint,
                                ),
                            icon: Icons.fingerprint_rounded,
                            label: 'Fingerprint',
                            caption: _captionFor(BiometricMethod.fingerprint),
                            onTap: () => setState(() {
                              _method = BiometricMethod.fingerprint;
                              _error = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    if (_availability.face && _availability.fingerprint) ...[
                      const SizedBox(height: 14),
                      Text(
                        _method == BiometricMethod.face
                            ? 'Look at the front camera. Your phone may also offer fingerprint.'
                            : 'Place your finger on the sensor.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (_scanning) ...[
                      const SizedBox(height: 20),
                      Text(
                        _method == BiometricMethod.face
                            ? 'Waiting for face unlock…'
                            : 'Waiting for fingerprint…',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      SoftCard(
                        color: AppColors.peach,
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _biometricsChanged
                  ? PrimaryButton(
                      key: const Key('biometric-sign-in-again'),
                      label: 'Sign in again',
                      icon: Icons.login_rounded,
                      onPressed: _signInAgain,
                    )
                  : PrimaryButton(
                      key: const Key('biometric-button'),
                      label: _scanning
                          ? 'Confirming…'
                          : _method == BiometricMethod.face
                          ? 'Confirm with face unlock'
                          : 'Confirm with fingerprint',
                      icon: Icons.verified_user_outlined,
                      loading: _scanning || _loadingAvailability,
                      onPressed: canAuthenticate ? _authenticate : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _captionFor(BiometricMethod method) {
    if (_loadingAvailability) {
      return 'Checking…';
    }
    if (_availability.supports(method)) {
      return 'Available';
    }
    return 'Not set up';
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SoftCard(
        onTap: enabled ? onTap : null,
        color: selected ? AppColors.lavender : AppColors.surface,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.lavenderDeep : AppColors.muted,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.ink : AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
