import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Isotipo oficial de BudSound — una "b" hecha de 6 barras redondeadas tipo
/// forma de onda, dibujada a mano con [CustomPainter] (antes era la imagen
/// `assets/brand/budsound_logo.jpg`). Reemplaza [GlowLogo] en la ruta
/// "Cabina minimal" (ver DECISIONES_TECNICAS.md).
class BudSoundMark extends StatelessWidget {
  const BudSoundMark({
    super.key,
    this.size = 96,
    this.showWordmark = false,
    this.progreso,
  });

  final double size;
  final bool showWordmark;

  /// Progreso de crecimiento por barra (0 a 1, de abajo hacia arriba) —
  /// `null` dibuja las 6 barras completas, como siempre. Ver
  /// [BudSoundMark.progresoEscalonado] para la secuencia del splash.
  final List<double>? progreso;

  /// Progreso por barra para la animación del splash: cada barra empieza a
  /// crecer 40ms después de la anterior y tarda 400ms en llegar a su altura
  /// final — con 6 barras, el total dura ≈600ms (200ms de arranque + 400ms
  /// de crecimiento de la última). [t] es el progreso global (0 a 1) de un
  /// `AnimationController` de 600ms.
  static List<double> progresoEscalonado(double t) {
    const duracionTotalMs = 600;
    const escalonMs = 40;
    const duracionBarraMs = 400;
    return List.generate(6, (i) {
      final inicioMs = i * escalonMs;
      final localMs = t * duracionTotalMs - inicioMs;
      final local = (localMs / duracionBarraMs).clamp(0.0, 1.0);
      return Curves.easeOutCubic.transform(local);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BudSoundMarkPainter(
          stem: AppColors.white,
          accent: AppColors.limeGreen,
          live: AppColors.success,
          progreso: progreso,
        ),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.22),
        Text(
          'BudSound',
          style: AppTheme.wordmark(
            color: AppColors.white,
            fontSize: size * 0.38,
          ),
        ),
      ],
    );
  }
}

/// Dibuja las 6 barras sobre un lienzo lógico de 72×72, escalado al tamaño
/// real del widget — así [size] puede ser cualquier valor (34 en una barra
/// superior, 120 en el splash) sin recalcular las coordenadas a mano.
class _BudSoundMarkPainter extends CustomPainter {
  const _BudSoundMarkPainter({
    required this.stem,
    required this.accent,
    required this.live,
    this.progreso,
  });

  final Color stem;
  final Color accent;
  final Color live;

  /// Progreso (0 a 1) por barra, mismo orden que la lista de barras acá
  /// abajo — `null` equivale a las 6 en 1 (altura completa).
  final List<double>? progreso;

  static const double _canvas = 72;
  static const double _barWidth = 8;
  static const Radius _radius = Radius.circular(4);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _canvas, size.height / _canvas);

    final barras = <_Barra>[
      _Barra(x: 0, top: 0, bottom: 72, color: stem),
      _Barra(x: 12, top: 38, bottom: 62, color: accent),
      _Barra(x: 24, top: 32, bottom: 68, color: accent),
      _Barra(x: 36, top: 29, bottom: 71, color: accent),
      _Barra(x: 48, top: 32, bottom: 68, color: accent),
      _Barra(x: 60, top: 38, bottom: 62, color: live),
    ];

    for (var i = 0; i < barras.length; i++) {
      final barra = barras[i];
      final p = progreso == null ? 1.0 : progreso![i];
      if (p <= 0) continue;
      // Crece desde abajo (bottom fijo, top se acerca desde bottom).
      final alturaTotal = barra.bottom - barra.top;
      final top = barra.bottom - alturaTotal * p;
      final rect = Rect.fromLTWH(
        barra.x,
        top,
        _barWidth,
        barra.bottom - top,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, _radius),
        Paint()..color = barra.color,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BudSoundMarkPainter oldDelegate) =>
      oldDelegate.stem != stem ||
      oldDelegate.accent != accent ||
      oldDelegate.live != live ||
      oldDelegate.progreso != progreso;
}

class _Barra {
  const _Barra({
    required this.x,
    required this.top,
    required this.bottom,
    required this.color,
  });

  final double x;
  final double top;
  final double bottom;
  final Color color;
}
