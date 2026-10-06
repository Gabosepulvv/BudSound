import 'package:flutter/material.dart';

/// Da feedback táctil (se achica levemente al presionar) a tarjetas y filas
/// que no son botones Material estándar — como los resultados de búsqueda.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _presionado = false;

  void _setPresionado(bool valor) {
    if (widget.onTap == null) return;
    setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPresionado(true),
      onTapUp: (_) => _setPresionado(false),
      onTapCancel: () => _setPresionado(false),
      child: AnimatedScale(
        scale: _presionado ? widget.scaleDown : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
