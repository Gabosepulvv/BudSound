import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// CTA principal — píldora sólida plana en el acento de la app, sin
/// degradado ni glow (antes tenía las dos cosas). Se achica levemente al
/// presionar, además del ripple de Material.
///
/// [color]/[colorTexto] son opcionales porque casi todas las pantallas (las
/// del DJ) usan el acento violeta de siempre sin tener que pasar nada —
/// las pantallas del Participante pasan el verde de `AppColors.success`
/// para su propio acento (ver DECISIONES_TECNICAS.md, rediseño de UI).
class NeonGradientButton extends StatefulWidget {
  const NeonGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color,
    this.colorTexto,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final Color? colorTexto;

  @override
  State<NeonGradientButton> createState() => _NeonGradientButtonState();
}

class _NeonGradientButtonState extends State<NeonGradientButton> {
  bool _presionado = false;

  void _setPresionado(bool valor) {
    final enabled = widget.onPressed != null && !widget.loading;
    if (!enabled) return;
    setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final color = widget.color ?? AppColors.limeGreen;
    final colorTexto = widget.colorTexto ?? AppColors.onLime;

    return GestureDetector(
      onTapDown: (_) => _setPresionado(true),
      onTapUp: (_) => _setPresionado(false),
      onTapCancel: () => _setPresionado(false),
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              color: enabled
                  ? (_presionado
                      ? Color.lerp(color, Colors.black, 0.25)
                      : color)
                  : color.withValues(alpha: 0.35),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(27),
                onTap: enabled ? widget.onPressed : null,
                child: Center(
                  child: widget.loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: colorTexto,
                          ),
                        )
                      : Text(
                          widget.label,
                          style: TextStyle(
                            color: colorTexto,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
