import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Envuelve una tarjeta de solicitud recién llegada con un anillo azul de
/// 1.5px que se desvanece en 1.2s + un `HapticFeedback.selectionClick()` —
/// juega UNA sola vez, al montarse (por eso depende de que el caller le
/// pase una `key` estable por id de solicitud: con eso, Flutter solo crea
/// un `_NuevaSolicitudRingState` nuevo para una solicitud que de verdad es
/// nueva en la lista, no para las que ya estaban y simplemente se
/// redibujaron).
///
/// [activo] en `false` no dibuja nada (se usa para la carga inicial de la
/// cola, donde ninguna solicitud es realmente "nueva").
class NuevaSolicitudRing extends StatefulWidget {
  const NuevaSolicitudRing({
    super.key,
    required this.child,
    this.activo = true,
    this.radius = 20,
  });

  final Widget child;
  final bool activo;
  final double radius;

  @override
  State<NuevaSolicitudRing> createState() => _NuevaSolicitudRingState();
}

class _NuevaSolicitudRingState extends State<NuevaSolicitudRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _opacidad =
      Tween<double>(begin: 1, end: 0).animate(_controller);
  bool _disparado = false;

  @override
  void initState() {
    super.initState();
    if (!widget.activo) _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No se puede leer `MediaQuery` (vía `AppMotion.of`) desde `initState`
    // — recién acá hay un árbol de widgets válido para depender de él. El
    // flag evita repetir el disparo en rebuilds posteriores del mismo
    // Element.
    if (_disparado || !widget.activo) return;
    _disparado = true;
    HapticFeedback.selectionClick();
    if (AppMotion.of(context).reducida) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: AppColors.limeGreen.withValues(alpha: _opacidad.value),
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
