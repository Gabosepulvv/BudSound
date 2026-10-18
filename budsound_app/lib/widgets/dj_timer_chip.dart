import 'dart:async';

import 'package:flutter/material.dart';

import '../services/dj_timer_service.dart';
import '../theme/app_colors.dart';

/// Vista previa compacta del temporizador del DJ (ver `DjTimerService` y
/// `DjQueueScreen._tarjetaTemporizador`, donde se configura). Se usa en
/// "Inicio" y en la tarjeta del evento activo de "En vivo" para poder
/// seguir controlando cuánto lleva tocando sin tener que entrar a la cola
/// del evento. No muestra nada si no hay un temporizador activo PARA ESTE
/// evento ([eventoId] — ver `DjTimerService.activoPara`, evita que el
/// temporizador de un evento ya cerrado se vea "activo" en uno nuevo). Se
/// actualiza sola con su propio tick — no depende de que la pantalla que
/// la contiene se repinte.
class DjTimerChip extends StatefulWidget {
  const DjTimerChip({super.key, required this.eventoId});

  final String eventoId;

  @override
  State<DjTimerChip> createState() => _DjTimerChipState();
}

class _DjTimerChipState extends State<DjTimerChip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicio = DjTimerService.instance;
    if (!servicio.activoPara(widget.eventoId)) return const SizedBox.shrink();

    final restante = servicio.restante;
    final expirado = restante.inSeconds <= 0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expirado ? AppColors.danger : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            servicio.pausado
                ? Icons.pause_circle_outline_rounded
                : Icons.timer_outlined,
            size: 16,
            color: expirado ? AppColors.danger : AppColors.limeGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              servicio.pausado
                  ? 'Temporizador en pausa — ${_formatear(restante)}'
                  : 'Temporizador — ${_formatear(restante)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: expirado ? AppColors.danger : AppColors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatear(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
