import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// CTA principal — píldora sólida plana en el acento azul de la app (igual
/// para ambos roles desde el rebranding "Cabina minimal", ver
/// DECISIONES_TECNICAS.md), sin degradado ni glow. Se achica levemente al
/// presionar (con un toque háptico) y el texto cruza a un spinner con fade
/// mientras `loading` está activo, en vez de reemplazarse de golpe.
///
/// [color]/[colorTexto] quedan como escape hatch para un caso puntual que
/// necesite otro color — hoy ninguna pantalla los usa.
class NeonGradientButton extends StatefulWidget {
  const NeonGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.exito = false,
    this.color,
    this.colorTexto,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Muestra un check en vez del texto/spinner — para el instante breve
  /// entre "la acción salió bien" y que la pantalla que lo llamó reaccione
  /// (ej. cerrar un diálogo). No deshabilita el botón por sí solo: pásalo
  /// junto con `onPressed: null` si también quieres bloquear el toque.
  final bool exito;
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
    final motion = AppMotion.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final color = widget.color ?? AppColors.limeGreen;
    final colorTexto = widget.colorTexto ?? AppColors.onLime;
    // accentPressed cuando es el acento por defecto; para un [color]
    // puntual, se oscurece hacia el fondo en vez de asumir un valor fijo.
    final colorPresionado = widget.color == null
        ? AppColors.limeDark
        : Color.lerp(color, AppColors.background, 0.25);

    return GestureDetector(
      onTapDown: (_) => _setPresionado(true),
      onTapUp: (_) => _setPresionado(false),
      onTapCancel: () => _setPresionado(false),
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1,
        duration: motion.fast,
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: AnimatedContainer(
            duration: motion.base,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: enabled
                  ? (_presionado ? colorPresionado : color)
                  : color.withValues(alpha: 0.35),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        widget.onPressed!();
                      }
                    : null,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: motion.base,
                    child: widget.exito
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('exito'),
                            color: colorTexto,
                            size: 26,
                          )
                        : widget.loading
                        ? SizedBox(
                            key: const ValueKey('cargando'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: colorTexto,
                            ),
                          )
                        : Text(
                            widget.label,
                            key: const ValueKey('etiqueta'),
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
      ),
    );
  }
}
