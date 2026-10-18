import 'package:flutter/material.dart';

import '../models/song_request_model.dart';
import '../services/request_service.dart';
import '../theme/app_colors.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/glow_logo.dart';

/// Historial de propinas del Participante a través de TODOS sus eventos —
/// a diferencia de `ParticipantEventScreen`, que solo muestra lo pedido
/// dentro del evento activo. Se accede desde Perfil.
class ParticipantHistoryScreen extends StatefulWidget {
  const ParticipantHistoryScreen({super.key});

  @override
  State<ParticipantHistoryScreen> createState() =>
      _ParticipantHistoryScreenState();
}

class _ParticipantHistoryScreenState extends State<ParticipantHistoryScreen> {
  final _requestService = RequestService();
  late Future<List<SongRequestModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _requestService.misSolicitudesGlobal();
  }

  void _recargar() {
    setState(() => _future = _requestService.misSolicitudesGlobal());
  }

  String _formatearFecha(DateTime fecha) {
    final local = fecha.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} · $hh:$mm';
  }

  String _formatearClp(int monto) {
    final texto = monto.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
      buffer.write(texto[i]);
    }
    return '\$$buffer';
  }

  ({IconData icono, Color color, String etiqueta}) _estado(
      SongRequestModel s) {
    if (s.aceptada) {
      return (
        icono: Icons.check_circle_rounded,
        color: AppColors.success,
        etiqueta: s.reproducida ? 'Reproducida' : 'Aceptada',
      );
    }
    if (s.rechazada) {
      return (
        icono: Icons.cancel_rounded,
        color: AppColors.danger,
        etiqueta: 'Rechazada',
      );
    }
    if (s.cancelada) {
      return (
        icono: Icons.block_rounded,
        color: AppColors.muted,
        etiqueta: 'Cancelada',
      );
    }
    return (
      icono: Icons.hourglass_top_rounded,
      color: AppColors.muted,
      etiqueta: 'Pendiente',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            GlowLogo(size: 30),
            SizedBox(width: 10),
            Text('Historial de propinas'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _recargar(),
        child: FutureBuilder<List<SongRequestModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.limeGreen),
              );
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('${snapshot.error}',
                      style: const TextStyle(color: AppColors.muted),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                        onPressed: _recargar,
                        child: const Text('Reintentar')),
                  ),
                ],
              );
            }

            final solicitudes = snapshot.data ?? [];
            if (solicitudes.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(32),
                children: const [
                  SizedBox(height: 60),
                  Icon(Icons.receipt_long_rounded,
                      size: 48, color: AppColors.muted),
                  SizedBox(height: 14),
                  Text(
                    'Todavía no has pedido ninguna canción',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Cuando pidas una canción con propina en un evento, va a aparecer acá.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              );
            }

            final totalGastado = solicitudes
                .where((s) => s.aceptada)
                .fold<int>(0, (sum, s) => sum + s.montoClp);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                FadeSlideIn(child: _tarjetaResumen(solicitudes.length, totalGastado)),
                const SizedBox(height: 16),
                ...solicitudes.asMap().entries.map(
                      (e) => FadeSlideIn(
                        delay: Duration(milliseconds: 40 * e.key),
                        child: _tarjetaSolicitud(e.value),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tarjetaResumen(int total, int gastado) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$total',
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const Text('Canciones pedidas',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatearClp(gastado),
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const Text('Propinas aceptadas',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaSolicitud(SongRequestModel s) {
    final estado = _estado(s);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(estado.icono, color: estado.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    s.artista,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.lavender, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.eventoNombre ?? 'Evento'} · ${_formatearFecha(s.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatearClp(s.montoClp),
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(estado.etiqueta,
                    style: TextStyle(
                        color: estado.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
