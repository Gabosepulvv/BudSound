import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Isotipo oficial de Budsound — plano, sin glow (el acento visual de la
/// pantalla ya lo pone `DarkNeonScaffold`).
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
        SizedBox(
          width: size,
          height: size,
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
          Text(
            'budsound',
            style: AppTheme.fontDisplay(
              color: AppColors.white,
              fontSize: 28,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}
