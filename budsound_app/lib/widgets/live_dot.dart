import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Punto ámbar que respira (opacidad 1.0 ↔ 0.35, loop de 1.6s) para marcar
/// "en vivo"/activo — solo el punto pulsa, nunca el texto de al lado. Se
/// detiene si el sistema tiene "reducir movimiento" activo
/// ([AppMotion.reducida]).
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 8, this.color});

  final double size;

  /// Color del punto — por defecto ámbar ([AppColors.success]); pásalo
  /// cuando el punto vaya sobre un fondo que ya es ámbar (ej. un chip
  /// "ACTIVO"), para que siga contrastando.
  final Color? color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _opacidad = Tween<double>(begin: 1, end: 0.35)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.of(context).reducida) {
      _controller.stop();
      _controller.value = 0;
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
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color ?? AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
