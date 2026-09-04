import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/primary_button.dart';
import '../widgets/soft_card.dart';
import 'confirmation_screen.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  static const routeName = '/biometric';

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  bool _scanning = false;
  String _method = 'fingerprint';

  Future<void> _authenticate() async {
    setState(() => _scanning = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(ConfirmationScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authenticate'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
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
                      'Use this phone’s built-in biometric authentication. PEAM never stores your fingerprint or face.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 28),
                    const AppVector(AppVectors.biometric, width: 180, height: 180),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _MethodCard(
                            selected: _method == 'face',
                            icon: Icons.face_retouching_natural,
                            label: 'Face',
                            onTap: () => setState(() => _method = 'face'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MethodCard(
                            selected: _method == 'fingerprint',
                            icon: Icons.fingerprint_rounded,
                            label: 'Fingerprint',
                            onTap: () =>
                                setState(() => _method = 'fingerprint'),
                          ),
                        ),
                      ],
                    ),
                    if (_scanning) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Matching local biometric…',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: PrimaryButton(
                key: const Key('biometric-button'),
                label: _scanning ? 'Authenticating' : 'Authenticate',
                icon: Icons.verified_user_outlined,
                loading: _scanning,
                onPressed: _authenticate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      color: selected ? AppColors.lavender : AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 18),
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
        ],
      ),
    );
  }
}
