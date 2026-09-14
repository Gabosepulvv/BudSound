import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo oscuro con degradado azul neón tenue en la base.
class DarkNeonScaffold extends StatelessWidget {
  const DarkNeonScaffold({
    super.key,
    required this.child,
    this.appBar,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              Color(0xFF07102A),
              AppColors.cobalt,
            ],
            stops: [0.0, 0.62, 1.0],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
