import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PeamLogo extends StatelessWidget {
  const PeamLogo({super.key, this.size = 72, this.showWordmark = false});

  static const assetPath = 'assets/branding/app_icon.png';

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    return Column(
      children: [
        mark,
        const SizedBox(height: 16),
        const Text(
          'PEAM-Registry',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Provincial Government of Davao del Sur',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
