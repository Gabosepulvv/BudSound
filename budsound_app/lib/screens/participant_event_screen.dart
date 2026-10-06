import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../models/itunes_track.dart';
import '../models/pending_song_request.dart';
import '../models/song_request_model.dart';
import '../services/api_client.dart';
import '../services/event_socket.dart';
import '../services/pending_requests_store.dart';
import '../services/request_service.dart';
import '../services/song_service.dart';
import '../theme/app_colors.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/neon_gradient_button.dart';
import '../widgets/pressable_scale.dart';
import 'mp_checkout_screen.dart';

/// Buscar canción y pedirla (con propina opcional) dentro de un evento, y
/// ver el estado de las propias solicitudes en vivo.
class ParticipantEventScreen extends StatefulWidget {
  const ParticipantEventScreen({super.key, required this.evento});

  final EventModel evento;

  @override
  State<ParticipantEventScreen> createState() => _ParticipantEventScreenState();
}

class _ParticipantEventScreenState extends State<ParticipantEventScreen>
    with SingleTickerProviderStateMixin {
  final _songService = SongService();
  final _requestService = RequestService();
  final _pendingStore = PendingRequestsStore.instance;
  final _busqueda = TextEditingController();
  late final EventSocket _socket;
  late final TabController _tabController;

  List<ItunesTrack> _resultados = [];
  List<SongRequestModel> _misSolicitudes = [];
  List<PendingSongRequest> _pendientesLocales = [];
  bool _buscando = false;
  bool _conectado = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _socket = EventSocket(widget.evento.id)
      ..conectar(
        onSolicitudResuelta: _cargarMisSolicitudes,
        onPagoAprobado: _cargarMisSolicitudes,
        onConectado: () {
          if (!mounted) return;
          setState(() => _conectado = true);
          _reintentarPendientes();
        },
        onDesconectado: () => setState(() => _conectado = false),
      );
    _cargarMisSolicitudes();
    _reintentarPendientes();
  }

  @override
  void dispose() {
    _socket.desconectar();
    _busqueda.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _buscar(String termino) async {
    if (termino.trim().isEmpty) return;
    setState(() => _buscando = true);
    try {
      final resultados = await _songService.buscar(termino);
      if (!mounted) return;
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _buscando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _cargarMisSolicitudes() async {
    try {
      final solicitudes =
          await _requestService.misSolicitudes(widget.evento.id);
      if (!mounted) return;
      setState(() => _misSolicitudes = solicitudes);
    } catch (_) {
      // La cola sigue funcionando aunque falle un refresh puntual.
    }
  }

  Future<void> _pedirCancion(ItunesTrack pista) async {
    final eleccion = await _elegirMonto(pista);
    if (eleccion == null) return;
    final (monto, terminosAceptados) = eleccion;

    // Con propina, el pago se autoriza en el checkout de MercadoPago antes
    // de que la solicitud exista — es esa pantalla la que llama a crear la
    // solicitud una vez que la tarjeta quedó tokenizada (ver
    // McpCheckoutScreen y CLAUDE.md, riesgo "Autorización de pago vs.
    // captura"). Sin propina no hay nada que pagar, así que se crea directo
    // y puede aprovechar la cola local si falla la conexión.
    if (monto > 0) {
      if (!mounted) return;
      final pagada = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => McpCheckoutScreen(
            eventId: widget.evento.id,
            itunesTrackId: pista.trackId,
            titulo: pista.trackName,
            artista: pista.artistName,
            artworkUrl: pista.artworkUrl,
            montoClp: monto,
            terminosAceptados: terminosAceptados,
          ),
        ),
      );
      if (pagada != true) return;
      await _cargarMisSolicitudes();
      if (!mounted) return;
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitud enviada al DJ'),
            backgroundColor: AppColors.cobalt),
      );
      return;
    }

    try {
      await _requestService.crear(
        eventId: widget.evento.id,
        itunesTrackId: pista.trackId,
        titulo: pista.trackName,
        artista: pista.artistName,
        artworkUrl: pista.artworkUrl,
        montoClp: monto,
        terminosAceptados: terminosAceptados,
      );
      await _cargarMisSolicitudes();
      if (!mounted) return;
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitud enviada al DJ'),
            backgroundColor: AppColors.cobalt),
      );
    } on ApiException catch (e) {
      // El backend respondió y la rechazó (validación, regla de negocio) —
      // reintentar no va a cambiar el resultado, así que no se encola.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      // No hubo respuesta del backend (corte de conexión en el evento, ver
      // CLAUDE.md riesgo "Congestión de red") — se guarda para no perder la
      // solicitud y se reintenta sola apenas vuelva la señal.
      await _pendingStore.agregar(PendingSongRequest(
        localId: DateTime.now().microsecondsSinceEpoch.toString(),
        eventId: widget.evento.id,
        itunesTrackId: pista.trackId,
        titulo: pista.trackName,
        artista: pista.artistName,
        artworkUrl: pista.artworkUrl,
        montoClp: monto,
        terminosAceptados: terminosAceptados,
      ));
      await _cargarPendientesLocales();
      if (!mounted) return;
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión: se enviará sola apenas vuelva la señal'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _cargarPendientesLocales() async {
    final pendientes = await _pendingStore.todas(widget.evento.id);
    if (!mounted) return;
    setState(() => _pendientesLocales = pendientes);
  }

  /// Reenvía las solicitudes guardadas localmente. Se corta en el primer
  /// fallo (sigue sin conexión) en vez de seguir intentando una por una —
  /// se vuelve a llamar solo apenas el socket reporte que reconectó.
  Future<void> _reintentarPendientes() async {
    final pendientes = await _pendingStore.todas(widget.evento.id);
    var huboEnvios = false;
    for (final p in pendientes) {
      try {
        await _requestService.crear(
          eventId: p.eventId,
          itunesTrackId: p.itunesTrackId,
          titulo: p.titulo,
          artista: p.artista,
          artworkUrl: p.artworkUrl,
          montoClp: p.montoClp,
          terminosAceptados: p.terminosAceptados,
        );
        await _pendingStore.eliminar(p.eventId, p.localId);
        huboEnvios = true;
      } catch (_) {
        break;
      }
    }
    if (!mounted) return;
    await _cargarPendientesLocales();
    if (huboEnvios) await _cargarMisSolicitudes();
  }

  /// Devuelve (monto, aceptóTérminos) o null si canceló. Con propina, el
  /// checkbox de Términos y Condiciones es obligatorio: una vez que el DJ
  /// acepta la solicitud no hay devolución (ver CLAUDE.md, riesgo "El
  /// participante pide la devolución del dinero").
  Future<(int, bool)?> _elegirMonto(ItunesTrack pista) async {
    final controller = TextEditingController();
    var aceptaTerminos = false;
    return showModalBottomSheet<(int, bool)>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pista.trackName,
                style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              Text(pista.artistName,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              const Text(
                'Propina opcional para el DJ (\$500 - \$20.000 CLP). '
                'No garantiza que suene, es solo un incentivo.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.white),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Monto en CLP (opcional)',
                  hintText: '0',
                ),
              ),
              if ((int.tryParse(controller.text.trim()) ?? 0) > 0) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: aceptaTerminos,
                  onChanged: (v) => setState(() => aceptaTerminos = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.neonBlue,
                  title: const Text(
                    'Entiendo que si el DJ acepta la propina, no hay devolución.',
                    style: TextStyle(color: AppColors.lavender, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              NeonGradientButton(
                label: 'Enviar solicitud',
                onPressed: () {
                  final monto = int.tryParse(controller.text.trim()) ?? 0;
                  if (monto != 0 && (monto < 500 || monto > 20000)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'El monto debe ser entre \$500 y \$20.000 CLP.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  if (monto > 0 && !aceptaTerminos) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Acepta los Términos y Condiciones para enviar una propina.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop((monto, aceptaTerminos));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.evento.nombre),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Buscar canción'),
            Tab(text: 'Mis solicitudes'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_conectado) _bannerSinConexion(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_tabBuscar(), _tabMisSolicitudes()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerSinConexion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppColors.danger.withOpacity(0.15),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión — reconectando…',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBuscar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _busqueda,
            style: const TextStyle(color: AppColors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: _buscar,
            decoration: InputDecoration(
              hintText: 'Buscar canción o artista',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () => _buscar(_busqueda.text),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
        ),
        if (_buscando)
          const Expanded(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.neonBlue)))
        else
          Expanded(
            child: _resultados.isEmpty
                ? const Center(
                    child: Text('Busca una canción para pedirla.',
                        style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _resultados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final pista = _resultados[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 35 * index),
                        child: PressableScale(
                          onTap: () => _pedirCancion(pista),
                          child: Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  pista.artworkUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.album_rounded),
                                ),
                              ),
                              title: Text(
                                pista.trackName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                pista.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              trailing: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppColors.neonBlue),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _tabMisSolicitudes() {
    if (_misSolicitudes.isEmpty && _pendientesLocales.isEmpty) {
      return const Center(
        child: Text('Todavía no has pedido ninguna canción.',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _reintentarPendientes();
        await _cargarMisSolicitudes();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _pendientesLocales.length + _misSolicitudes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final delay = Duration(milliseconds: 40 * index);
          if (index < _pendientesLocales.length) {
            return FadeSlideIn(
              delay: delay,
              child: _tarjetaPendienteLocal(_pendientesLocales[index]),
            );
          }
          return FadeSlideIn(
            delay: delay,
            child: _tarjetaSolicitud(
                _misSolicitudes[index - _pendientesLocales.length]),
          );
        },
      ),
    );
  }

  /// Solicitud guardada en el celular, todavía sin confirmar por el backend
  /// (sin `id` de servidor) — se distingue visualmente de las ya enviadas.
  Widget _tarjetaPendienteLocal(PendingSongRequest pendiente) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.muted),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pendiente.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w700),
                ),
                Text(
                  pendiente.artista,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sin conexión — se enviará sola',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaSolicitud(SongRequestModel solicitud) {
    final color = solicitud.aceptada
        ? AppColors.neonBlue
        : solicitud.rechazada
            ? AppColors.danger
            : solicitud.cancelada
                ? AppColors.muted
                : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
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
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  solicitud.pendiente
                      ? 'Esperando al DJ'
                      : solicitud.aceptada
                          ? (solicitud.reproducida ? 'Reproducida' : 'Aceptada')
                          : solicitud.cancelada
                              ? 'Cancelada (sin respuesta a tiempo)'
                              : 'Rechazada',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          // La propina se autoriza al crear la solicitud y se cobra sola
          // cuando el DJ acepta (ver McpCheckoutScreen) — no hay un paso de
          // pago manual aparte que el Participante tenga que hacer acá.
          if (solicitud.aceptada && solicitud.tienePropina)
            const Text('Pagado',
                style:
                    TextStyle(color: AppColors.neonBlue, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
