import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import 'app_vector.dart';

class PeamLogo extends StatelessWidget {
  const PeamLogo({super.key, this.size = 72, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: AppShadows.soft,
      ),
      child: AppVector(AppVectors.logoMark, width: size, height: size),
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
