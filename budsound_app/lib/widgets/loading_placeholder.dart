import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Placeholder de carga: un rectángulo `surface` que pulsa de opacidad
/// (0.5 ↔ 1.0 cada 1.2s) en vez de un spinner — para listas/pantallas
/// completas, no para el botón puntual que dispara la acción (ese sigue
/// usando spinner, ver `NeonGradientButton`). Nada de shimmer con
/// degradado: solo el pulso de opacidad.
class LoadingPlaceholder extends StatefulWidget {
  const LoadingPlaceholder({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = 8,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<LoadingPlaceholder> createState() => _LoadingPlaceholderState();
}

class _LoadingPlaceholderState extends State<LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _opacidad = Tween<double>(begin: 0.5, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.of(context).reducida) {
      _controller.stop();
      _controller.value = 0.75;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacidad,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Bloque de varios [LoadingPlaceholder] apilados, para reemplazar un
/// spinner centrado de pantalla completa mientras carga una lista.
class LoadingPlaceholderList extends StatelessWidget {
  const LoadingPlaceholderList({
    super.key,
    this.cantidad = 3,
    this.alturaItem = 64,
    this.padding = const EdgeInsets.all(16),
  });

  final int cantidad;
  final double alturaItem;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < cantidad; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            LoadingPlaceholder(height: alturaItem, radius: 20),
          ],
        ],
      ),
    );
  }
}
