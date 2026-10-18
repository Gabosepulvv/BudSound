import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Minutos que tiene el DJ para aceptar o rechazar una solicitud antes de
/// que el barrido automático del backend la cancele sola (ver
/// cleanupRequests.js, `REQUEST_TIMEOUT_MINUTES`) — el mismo valor en los
/// dos lados a propósito: si se cambia acá sin cambiar el backend, la
/// cuenta regresiva deja de ser precisa.
const limiteSolicitudMinutos = 7;

/// Cuenta regresiva en vivo de cuánto le queda a una solicitud pendiente
/// antes de vencer sola — hace tangible el límite de 7 minutos en vez de
/// que el DJ se entere recién cuando la solicitud desaparece de la cola.
/// Pasa a rojo en el último minuto para que destaque entre las demás.
class SolicitudCountdown extends StatefulWidget {
  const SolicitudCountdown({super.key, required this.createdAt});

  final DateTime createdAt;

  @override
  State<SolicitudCountdown> createState() => _SolicitudCountdownState();
}

class _SolicitudCountdownState extends State<SolicitudCountdown> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vence =
        widget.createdAt.add(const Duration(minutes: limiteSolicitudMinutos));
    final totalSegundos = vence.difference(DateTime.now()).inSeconds;
    final segundos = totalSegundos.clamp(0, limiteSolicitudMinutos * 60);
    final m = segundos ~/ 60;
    final s = segundos % 60;
    final porVencer = segundos <= 60;
    final color = porVencer ? AppColors.danger : AppColors.muted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          porVencer ? Icons.timer_rounded : Icons.timer_outlined,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          segundos == 0
              ? 'Vence ya'
              : 'Vence en $m:${s.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: porVencer ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
