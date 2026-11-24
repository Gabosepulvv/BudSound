import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Cuenta hacia arriba/abajo cuando [valor] cambia, en vez de reemplazar el
/// número de golpe — pensado para montos de recaudación o estadísticas que
/// suben cuando entra una propina aceptada. [builder] recibe el valor
/// intermedio ya formateado por [formatear].
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.valor,
    required this.builder,
    this.formatear,
  });

  final int valor;
  final Widget Function(BuildContext context, String texto) builder;
  final String Function(int valor)? formatear;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    return TweenAnimationBuilder<int>(
      tween: IntTween(end: valor),
      duration: motion.count,
      curve: Curves.easeOutCubic,
      builder: (context, intermedio, child) {
        final texto = formatear?.call(intermedio) ?? '$intermedio';
        return builder(context, texto);
      },
    );
  }
}
