import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// CTA principal con degradado verde lima → lima oscuro. Se achica levemente
/// y atenúa su glow al presionar, además del ripple de Material. El texto
/// usa [AppColors.onLime] (no blanco) porque el verde lima es demasiado
/// claro para que el blanco tenga buen contraste encima.
class NeonGradientButton extends StatefulWidget {
  const NeonGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

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
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: enabled
                    ? const [AppColors.limeGreen, AppColors.limeDark]
                    : [
                        AppColors.limeGreen.withOpacity(0.35),
                        AppColors.limeDark.withOpacity(0.35),
                      ],
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.limeGreen
                            .withOpacity(_presionado ? 0.25 : 0.45),
                        blurRadius: _presionado ? 10 : 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: enabled ? widget.onPressed : null,
                child: Center(
                  child: widget.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.onLime,
                          ),
                        )
                      : Text(
                          widget.label,
                          style: const TextStyle(
                            color: AppColors.onLime,
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
