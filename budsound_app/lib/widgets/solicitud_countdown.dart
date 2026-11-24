import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Minutos que tiene el DJ para aceptar o rechazar una solicitud antes de
/// que el barrido automático del backend la cancele sola (ver
/// cleanupRequests.js, `REQUEST_TIMEOUT_MINUTES`) — el mismo valor en los
/// dos lados a propósito: si se cambia acá sin cambiar el backend, la
/// cuenta regresiva deja de ser precisa.
const limiteSolicitudMinutos = 7;

/// Cuenta regresiva en vivo de cuánto le queda a una solicitud pendiente
/// antes de vencer sola — una barra fina que avanza suave segundo a segundo
/// (nunca salta de golpe) hace tangible el límite de 7 minutos, en vez de
/// que el DJ se entere recién cuando la solicitud desaparece de la cola.
/// Bajo el último minuto, la barra pasa a rojo con un único pulso de
/// opacidad (no en loop, para no competir con el punto "en vivo" de al
/// lado).
class SolicitudCountdown extends StatefulWidget {
  const SolicitudCountdown({super.key, required this.createdAt});

  final DateTime createdAt;

  @override
  State<SolicitudCountdown> createState() => _SolicitudCountdownState();
}

class _SolicitudCountdownState extends State<SolicitudCountdown>
    with SingleTickerProviderStateMixin {
  late final Timer _tick;
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  bool _yaPorVencer = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_revisarUmbral);
    });
    _revisarUmbral();
  }

  void _revisarUmbral() {
    final porVencer = _segundosRestantes() <= 60;
    if (porVencer && !_yaPorVencer) {
      // Un solo pulso (ida y vuelta), no un loop — se nota el cambio de
      // estado sin quedar parpadeando todo el último minuto.
      _pulso.forward().then((_) => _pulso.reverse());
    }
    _yaPorVencer = porVencer;
  }

  int _segundosRestantes() {
    final vence =
        widget.createdAt.add(const Duration(minutes: limiteSolicitudMinutos));
    return vence
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, limiteSolicitudMinutos * 60);
  }

  @override
  void dispose() {
    _tick.cancel();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    final segundos = _segundosRestantes();
    final m = segundos ~/ 60;
    final s = segundos % 60;
    final porVencer = segundos <= 60;
    final fraccion = segundos / (limiteSolicitudMinutos * 60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: porVencer ? AppColors.danger : AppColors.muted,
              ),
              duration: const Duration(milliseconds: 300),
              builder: (context, color, child) => Icon(
                porVencer ? Icons.timer_rounded : Icons.timer_outlined,
                size: 12,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: porVencer ? AppColors.danger : AppColors.muted,
              ),
              duration: const Duration(milliseconds: 300),
              builder: (context, color, child) => Text(
                segundos == 0
                    ? 'Vence ya'
                    : 'Vence en $m:${s.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: porVencer ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FadeTransition(
          // El pulso sube la opacidad momentáneamente al cruzar el umbral
          // de "por vencer" — 1 sola vez, no un loop.
          opacity: Tween<double>(begin: 1, end: 0.4).animate(_pulso),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              width: 120,
              child: Stack(
                children: [
                  const ColoredBox(color: AppColors.border),
                  TweenAnimationBuilder<double>(
                    key: const ValueKey('barraCountdown'),
                    tween: Tween<double>(end: fraccion.clamp(0, 1)),
                    duration: motion.reducida
                        ? Duration.zero
                        : const Duration(seconds: 1),
                    curve: AppMotion.progress,
                    builder: (context, valor, child) =>
                        FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: valor,
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          end:
                              porVencer ? AppColors.danger : AppColors.limeGreen,
                        ),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, color, child) =>
                            ColoredBox(color: color ?? AppColors.limeGreen),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
