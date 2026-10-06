import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo oscuro con degradado azul neón tenue en la base, más un glow
/// ambiental que respira lentamente — para que las pantallas de acceso no
/// se sientan estáticas incluso sin que la persona interactúe todavía.
class DarkNeonScaffold extends StatefulWidget {
  const DarkNeonScaffold({
    super.key,
    required this.child,
    this.appBar,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;

  @override
  State<DarkNeonScaffold> createState() => _DarkNeonScaffoldState();
}

class _DarkNeonScaffoldState extends State<DarkNeonScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _respiracion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _respiracion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.appBar,
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
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
            child: SizedBox.expand(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _respiracion,
                builder: (context, _) => Align(
                  alignment: const Alignment(-0.6, -0.9),
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonBlue.withOpacity(
                              0.10 + 0.08 * _respiracion.value),
                          blurRadius: 120,
                          spreadRadius: 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(child: widget.child),
        ],
      ),
    );
  }
}
