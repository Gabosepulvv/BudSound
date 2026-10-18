import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo con una mancha de luz violeta que flota y late lento, para
/// ambientar la pantalla mientras el participante está dentro de un evento
/// pidiendo canciones — antes eran tres luces (lima, violeta, cian)
/// cruzando la pantalla; con el rediseño plano, un solo acento puntual
/// queda más coherente con el resto de la app. Decorativo puro (no
/// transmite ningún estado), así que el color queda fijo incluso en modo
/// daltónico. Va DETRÁS del contenido (`IgnorePointer`, opacidad baja,
/// mucho blur) para no competir con la legibilidad de las tarjetas encima.
class AmbientLightsBackground extends StatefulWidget {
  const AmbientLightsBackground({super.key});

  @override
  State<AmbientLightsBackground> createState() =>
      _AmbientLightsBackgroundState();
}

class _AmbientLightsBackgroundState extends State<AmbientLightsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * math.pi;
            return Stack(
              children: [
                _luz(
                  color: AppColors.glow,
                  dx: 0.5 + 0.2 * math.cos(t * 0.5),
                  dy: -0.8 + 0.12 * math.sin(t * 0.7),
                  size: 320,
                  opacity: 0.18 + 0.06 * math.sin(t),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _luz({
    required Color color,
    required double dx,
    required double dy,
    required double size,
    required double opacity,
  }) {
    return Align(
      alignment: Alignment(dx.clamp(-1.3, 1.3), dy.clamp(-1.3, 1.3)),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
              blurRadius: size * 0.9,
              spreadRadius: size * 0.25,
            ),
          ],
        ),
      ),
    );
  }
}
