import 'package:flutter/material.dart';

import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/soft_card.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final employee = session.employee;
        if (employee == null) {
          return const Center(child: Text('Not signed in.'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            SoftCard(
              color: AppColors.lavender,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                children: [
                  const AppVector(AppVectors.logoMark, width: 72, height: 72),
                  const SizedBox(height: 14),
                  Text(
                    employee.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    employee.employeeNumber,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: [
                  _DetailRow(label: 'Office', value: employee.department.name),
                  _DetailRow(
                    label: 'Department',
                    value: employee.department.code,
                  ),
                  _DetailRow(
                    label: 'Mobile',
                    value:
                        (employee.phone == null ||
                            employee.phone!.trim().isEmpty)
                        ? 'Not provided'
                        : employee.phone!,
                  ),
                  _DetailRow(label: 'Device', value: employee.deviceName),
                  _DetailRow(
                    label: 'Binding',
                    value: employee.deviceBound ? 'Active' : 'Unbound',
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              key: const Key('sign-out-button'),
              onPressed: () {
                session.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: AppColors.line),
      ],
    );
  }
}
