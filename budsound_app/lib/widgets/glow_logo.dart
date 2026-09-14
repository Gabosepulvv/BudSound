import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Isotipo oficial de Budsound con glow neón.
class GlowLogo extends StatelessWidget {
  const GlowLogo({
    super.key,
    this.size = 96,
    this.showWordmark = false,
  });

  static const String assetPath = 'assets/brand/budsound_logo.jpg';

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withOpacity(0.55),
                blurRadius: 36,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: AppColors.cobalt.withOpacity(0.35),
                blurRadius: 64,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.28),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return ColoredBox(
                  color: AppColors.surface,
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: size * 0.48,
                    color: AppColors.white,
                  ),
                );
              },
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 14),
          const Text(
            'budsound',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}
