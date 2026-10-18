import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo casi negro con una sola mancha de glow violeta en la esquina
/// superior, que flota en un recorrido lento y amplio (no solo respira de
/// tamaño en el mismo lugar) — un acento puntual (como una luna
/// moviéndose despacio), no un degradado que cubre toda la pantalla.
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
  // Un solo recorrido continuo (no reverse) de 22s — lo bastante lento para
  // sentirse como deriva, no como una animación que se nota "latiendo".
  late final AnimationController _deriva = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  @override
  void dispose() {
    _deriva.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.appBar,
      body: Stack(
        children: [
          const ColoredBox(
            color: AppColors.background,
            child: SizedBox.expand(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _deriva,
                builder: (context, _) {
                  final t = _deriva.value * 2 * math.pi;
                  // Recorrido elíptico chico alrededor de la esquina
                  // superior derecha — nunca se aleja tanto como para
                  // dejar de leerse como "esquina", solo deriva dentro de
                  // ella.
                  final dx = 1.0 + 0.18 * math.cos(t);
                  final dy = -0.95 + 0.14 * math.sin(t * 0.8);
                  return Align(
                    alignment: Alignment(dx, dy),
                    child: Container(
                      width: 420,
                      height: 420,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.glow.withValues(
                                alpha: 0.30 + 0.06 * math.sin(t * 1.3)),
                            AppColors.glow.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(child: widget.child),
        ],
      ),
    );
  }
}
