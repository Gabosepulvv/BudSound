import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Envuelve una tarjeta de solicitud pendiente para animarla cuando el DJ
/// la acepta o rechaza, antes de que desaparezca de la lista "pendientes"
/// (ver `DjQueueScreen._resolver` — el id queda en `_resolviendoOptimista`
/// unos cientos de ms antes de que `_cargarCola()` la mueva de verdad a
/// "resueltas").
///
/// - Rechazada ([resultado] `false`): fade + deslizamiento de 24px a la
///   izquierda, y recién después se colapsa.
/// - Aceptada ([resultado] `true`): sin salida propia (el punto de estado
///   ya pasa de azul a ámbar por su cuenta) — solo se colapsa.
/// - [resultado] en `null` (todavía pendiente): se muestra tal cual.
class ResolucionTransition extends StatefulWidget {
  const ResolucionTransition({
    super.key,
    required this.child,
    required this.resultado,
  });

  final Widget child;
  final bool? resultado;

  @override
  State<ResolucionTransition> createState() => _ResolucionTransitionState();
}

class _ResolucionTransitionState extends State<ResolucionTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _salida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _colapsado = false;

  @override
  void didUpdateWidget(covariant ResolucionTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resultado == null && widget.resultado != null) {
      _jugarSalida();
    }
  }

  Future<void> _jugarSalida() async {
    final reducida = AppMotion.of(context).reducida;
    if (widget.resultado == false) {
      if (reducida) {
        _salida.value = 1;
      } else {
        await _salida.forward();
      }
    }
    if (!mounted) return;
    if (!reducida) {
      await Future.delayed(const Duration(milliseconds: 180));
    }
    if (mounted) setState(() => _colapsado = true);
  }

  @override
  void dispose() {
    _salida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    final contenido = widget.resultado == false
        ? AnimatedBuilder(
            animation: _salida,
            child: widget.child,
            builder: (context, child) => Opacity(
              opacity: 1 - _salida.value,
              child: Transform.translate(
                offset: Offset(-24 * _salida.value, 0),
                child: child,
              ),
            ),
          )
        : widget.child;

    return AnimatedSize(
      duration: motion.medium,
      curve: AppMotion.exit,
      alignment: Alignment.topCenter,
      child: _colapsado ? const SizedBox.shrink() : contenido,
    );
  }
}
