import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event_model.dart';
import '../models/song_request_model.dart';
import '../services/event_service.dart';
import '../services/event_socket.dart';
import '../services/request_service.dart';
import '../theme/app_colors.dart';

/// Cola en vivo de un evento: QR para que se unan, y aceptar/rechazar
/// solicitudes a medida que llegan por Socket.io.
class DjQueueScreen extends StatefulWidget {
  const DjQueueScreen({super.key, required this.evento});

  final EventModel evento;

  @override
  State<DjQueueScreen> createState() => _DjQueueScreenState();
}

class _DjQueueScreenState extends State<DjQueueScreen> {
  final _eventService = EventService();
  final _requestService = RequestService();
  late final EventSocket _socket;
  late EventModel _evento;

  List<SongRequestModel> _solicitudes = [];
  bool _cargando = true;
  final Set<String> _resolviendo = {};

  @override
  void initState() {
    super.initState();
    _evento = widget.evento;
    _socket = EventSocket(_evento.id)
      ..conectar(
        onSolicitudCreada: _cargarCola,
        onSolicitudResuelta: _cargarCola,
      );
    _cargarCola();
  }

  @override
  void dispose() {
    _socket.desconectar();
    super.dispose();
  }

  Future<void> _cargarCola() async {
    try {
      final solicitudes = await _requestService.listarPorEvento(_evento.id);
      if (!mounted) return;
      setState(() {
        _solicitudes = solicitudes;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _resolver(SongRequestModel solicitud, {required bool aceptar}) async {
    setState(() => _resolviendo.add(solicitud.id));
    try {
      if (aceptar) {
        await _requestService.aceptar(solicitud.id);
      } else {
        await _requestService.rechazar(solicitud.id);
      }
      await _cargarCola();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _resolviendo.remove(solicitud.id));
    }
  }

  Future<void> _cerrarEvento() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Cerrar evento?', style: TextStyle(color: AppColors.white)),
        content: const Text(
          'Ya no se podrán recibir más solicitudes.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cerrar evento')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _eventService.cerrar(_evento.id);
      final resumen = await _eventService.resumen(_evento.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Evento cerrado', style: TextStyle(color: AppColors.white)),
          content: Text(
            'Solicitudes aceptadas: ${resumen['solicitudes_aceptadas']}\n'
            'Recaudación neta: \$${resumen['recaudacion_neta_clp']} CLP',
            style: const TextStyle(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _solicitudes.where((s) => s.pendiente).toList();
    final resueltas = _solicitudes.where((s) => !s.pendiente).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_evento.nombre),
        actions: [
          if (_evento.activo)
            TextButton(
              onPressed: _cerrarEvento,
              child: const Text('Cerrar evento', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarCola,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _tarjetaQr(),
            const SizedBox(height: 20),
            Text(
              'Cola (${pendientes.length})',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
              )
            else if (pendientes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Sin solicitudes pendientes.', style: TextStyle(color: AppColors.muted)),
              )
            else
              ...pendientes.map(_tarjetaSolicitud),
            if (resueltas.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Resueltas',
                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...resueltas.map(_tarjetaSolicitud),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjetaQr() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (_evento.activo) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: _evento.code, size: 180, gapless: true),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _evento.code,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _evento.activo
                ? 'El público escanea este código para unirse.'
                : 'Este evento ya está cerrado.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaSolicitud(SongRequestModel solicitud) {
    final resolviendo = _resolviendo.contains(solicitud.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _colorEstado(solicitud)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    solicitud.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    solicitud.artista,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.lavender, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${solicitud.participanteNombreCompleto}'
                    '${solicitud.tienePropina ? ' · \$${solicitud.montoClp} CLP' : ''}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (solicitud.pendiente)
              resolviendo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue),
                    )
                  : Row(
                      children: [
                        IconButton(
                          onPressed: () => _resolver(solicitud, aceptar: false),
                          icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                        ),
                        IconButton(
                          onPressed: () => _resolver(solicitud, aceptar: true),
                          icon: const Icon(Icons.check_circle_rounded, color: AppColors.neonBlue),
                        ),
                      ],
                    )
            else
              Text(
                solicitud.aceptada ? 'Aceptada' : 'Rechazada',
                style: TextStyle(color: _colorEstado(solicitud), fontWeight: FontWeight.w700, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Color _colorEstado(SongRequestModel solicitud) {
    if (solicitud.aceptada) return AppColors.neonBlue;
    if (solicitud.rechazada) return AppColors.danger;
    return AppColors.border;
  }
}
