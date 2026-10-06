import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event_model.dart';
import '../models/song_request_model.dart';
import '../services/event_service.dart';
import '../services/event_socket.dart';
import '../services/request_service.dart';
import '../theme/app_colors.dart';
import '../widgets/fade_slide_in.dart';

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
  Map<String, dynamic>? _resumen;
  bool _cargando = true;
  bool _conectado = true;
  final Set<String> _resolviendo = {};

  @override
  void initState() {
    super.initState();
    _evento = widget.evento;
    _socket = EventSocket(_evento.id)
      ..conectar(
        onSolicitudCreada: _cargarCola,
        onSolicitudResuelta: _cargarCola,
        onSolicitudReproducida: _cargarCola,
        onConectado: () => setState(() => _conectado = true),
        onDesconectado: () => setState(() => _conectado = false),
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
      // El resumen solo tiene sentido una vez cerrado el evento — se queda
      // visible en la pantalla en vez de mostrarse una sola vez en un
      // diálogo que desaparece al salir.
      final resumen =
          _evento.activo ? null : await _eventService.resumen(_evento.id);
      if (!mounted) return;
      setState(() {
        _solicitudes = solicitudes;
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _resolver(SongRequestModel solicitud,
      {required bool aceptar}) async {
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

  /// Deja un registro con timestamp de que la canción sonó — es la
  /// evidencia que se usaría para disputar un contracargo de MercadoPago.
  Future<void> _marcarReproducida(SongRequestModel solicitud) async {
    setState(() => _resolviendo.add(solicitud.id));
    try {
      await _requestService.marcarReproducida(solicitud.id);
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
        title: const Text('¿Cerrar evento?',
            style: TextStyle(color: AppColors.white)),
        content: const Text(
          'Ya no se podrán recibir más solicitudes.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar evento')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final eventoCerrado = await _eventService.cerrar(_evento.id);
      if (!mounted) return;
      setState(() => _evento = eventoCerrado);
      await _cargarCola();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Evento cerrado. Abajo queda el resumen de recaudación.'),
          backgroundColor: AppColors.limeDark,
        ),
      );
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
              child: const Text('Cerrar evento',
                  style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarCola,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (!_conectado) _bannerSinConexion(),
            FadeSlideIn(child: _tarjetaQr()),
            if (!_evento.activo && _resumen != null) ...[
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: _tarjetaResumen(_resumen!),
              ),
            ],
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
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.limeGreen)),
              )
            else if (pendientes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Sin solicitudes pendientes.',
                    style: TextStyle(color: AppColors.muted)),
              )
            else
              ...pendientes.asMap().entries.map(
                    (e) => FadeSlideIn(
                      delay: Duration(milliseconds: 50 * e.key),
                      child: _tarjetaSolicitud(e.value),
                    ),
                  ),
            if (resueltas.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Resueltas',
                style: TextStyle(
                    color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...resueltas.asMap().entries.map(
                    (e) => FadeSlideIn(
                      delay: Duration(milliseconds: 50 * e.key),
                      child: _tarjetaSolicitud(e.value),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bannerSinConexion() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión — reconectando… la cola puede tardar en actualizarse.',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
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
                child:
                    QrImageView(data: _evento.code, size: 180, gapless: true),
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

  Widget _tarjetaResumen(Map<String, dynamic> resumen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.limeGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del evento',
            style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _filaResumen(
              'Solicitudes aceptadas', '${resumen['solicitudes_aceptadas']}'),
          _filaResumen(
              'Solicitudes totales', '${resumen['solicitudes_totales']}'),
          _filaResumen(
              'Recaudación bruta', '\$${resumen['recaudacion_bruta_clp']} CLP'),
          _filaResumen(
              'Comisión BudSound', '\$${resumen['comision_total_clp']} CLP'),
          _filaResumen(
              'Recaudación neta', '\$${resumen['recaudacion_neta_clp']} CLP',
              destacado: true),
        ],
      ),
    );
  }

  Widget _filaResumen(String etiqueta, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          Text(
            valor,
            style: TextStyle(
              color: destacado ? AppColors.limeGreen : AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: destacado ? 16 : 13,
            ),
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
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    solicitud.artista,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.lavender, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${solicitud.participanteNombreCompleto}'
                    '${solicitud.tienePropina ? ' · \$${solicitud.montoClp} CLP' : ''}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (solicitud.pendiente)
              resolviendo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.limeGreen),
                    )
                  : Row(
                      children: [
                        IconButton(
                          onPressed: () => _resolver(solicitud, aceptar: false),
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.danger),
                        ),
                        IconButton(
                          onPressed: () => _resolver(solicitud, aceptar: true),
                          icon: const Icon(Icons.check_circle_rounded,
                              color: AppColors.limeGreen),
                        ),
                      ],
                    )
            else if (solicitud.aceptada && !solicitud.reproducida)
              resolviendo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.limeGreen),
                    )
                  : TextButton.icon(
                      onPressed: () => _marcarReproducida(solicitud),
                      icon: const Icon(Icons.graphic_eq_rounded, size: 18),
                      label: const Text('Reproducida'),
                    )
            else
              Text(
                solicitud.aceptada
                    ? 'Reproducida'
                    : solicitud.cancelada
                        ? 'Cancelada'
                        : 'Rechazada',
                style: TextStyle(
                    color: _colorEstado(solicitud),
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Color _colorEstado(SongRequestModel solicitud) {
    if (solicitud.aceptada) return AppColors.limeGreen;
    if (solicitud.rechazada) return AppColors.danger;
    if (solicitud.cancelada) return AppColors.muted;
    return AppColors.border;
  }
}
