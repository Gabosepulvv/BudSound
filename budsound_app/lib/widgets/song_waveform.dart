import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Forma de onda puramente decorativa para la tarjeta "tu canción" — NUNCA
/// reproduce audio ni representa un progreso real de reproducción (ver
/// regla de iTunes en CLAUDE.md). [playedFraction] solo refleja el ESTADO
/// de la solicitud (pendiente/aceptada/reproducida), no un segundero real:
/// la parte "reproducida" va en el acento y el resto en `border`, con una
/// barra ámbar como "cabezal" en el límite entre ambas.
class SongWaveform extends StatefulWidget {
  const SongWaveform({
    super.key,
    required this.playedFraction,
    this.seed = 0,
    this.barCount = 44,
    this.height = 28,
  });

  /// 0 a 1 — cuántas barras de [barCount] se pintan como "ya reproducida".
  final double playedFraction;

  /// Semilla para variar la silueta entre canciones (ej. el hash del id de
  /// la solicitud) — sin esto, todas las tarjetas mostrarían la misma
  /// silueta, lo que se vería como un elemento repetido de plantilla.
  final int seed;

  final int barCount;
  final double height;

  @override
  State<SongWaveform> createState() => _SongWaveformState();
}

class _SongWaveformState extends State<SongWaveform>
    with SingleTickerProviderStateMixin {
  late final List<double> _siluetas = _generarSiluetas(widget.seed, widget.barCount);
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 15 * widget.barCount + 160),
  );

  static List<double> _generarSiluetas(int seed, int cantidad) {
    final random = math.Random(seed);
    return List.generate(cantidad, (i) {
      // Mezcla una onda suave (para que no se vea puro ruido) con algo de
      // variación aleatoria por barra.
      final onda = 0.55 + 0.35 * math.sin(i * 0.45 + seed);
      final ruido = random.nextDouble() * 0.3;
      return (onda + ruido).clamp(0.25, 1.0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.of(context).reducida) {
      _entrada.value = 1;
    } else if (!_entrada.isCompleted && !_entrada.isAnimating) {
      _entrada.forward();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barraReproducida =
        (widget.playedFraction * widget.barCount).floor();

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _entrada,
        builder: (context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.barCount; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                _barra(i, barraReproducida),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _barra(int indice, int barraReproducida) {
    const duracionBarraMs = 160;
    final inicioMs = indice * 15;
    final totalMs = _entrada.duration!.inMilliseconds;
    final localMs = _entrada.value * totalMs - inicioMs;
    final local =
        Curves.easeOutCubic.transform((localMs / duracionBarraMs).clamp(0.0, 1.0));

    final esCabezal = widget.playedFraction > 0 && indice == barraReproducida;
    final color = esCabezal
        ? AppColors.success
        : indice < barraReproducida
            ? AppColors.limeGreen
            : AppColors.border;

    final alturaFinal = _siluetas[indice] * widget.height;
    return Container(
      width: 4,
      height: alturaFinal * local,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
