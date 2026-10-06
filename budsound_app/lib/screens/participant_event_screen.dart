import 'dart:async';

import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../models/itunes_track.dart';
import '../models/pending_song_request.dart';
import '../models/song_request_model.dart';
import '../services/event_socket.dart';
import '../services/pending_requests_store.dart';
import '../services/request_service.dart';
import '../services/song_service.dart';
import '../theme/app_colors.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/neon_gradient_button.dart';
import '../widgets/pressable_scale.dart';
import 'mp_checkout_screen.dart';

/// Buscar canción y pedirla (con propina obligatoria) dentro de un evento, y
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
  bool _mostrandoPopulares = true;
  Timer? _debounce;

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
    _cargarPopulares();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _socket.desconectar();
    _busqueda.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Canciones populares que se muestran apenas se abre la pestaña, antes
  /// de escribir nada — así nunca es una pantalla vacía.
  Future<void> _cargarPopulares() async {
    setState(() => _buscando = true);
    try {
      final resultados = await _songService.top();
      if (!mounted) return;
      setState(() {
        _resultados = resultados;
        _mostrandoPopulares = true;
        _buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
    }
  }

  /// Dispara la búsqueda ~400ms después de que la persona deja de escribir
  /// (en vez de exigir tocar la lupa o Enter) — si borra todo, vuelve a
  /// mostrar las canciones populares.
  void _alEscribir(String termino) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (termino.trim().isEmpty) {
        _cargarPopulares();
      } else {
        _buscar(termino);
      }
    });
  }

  Future<void> _buscar(String termino) async {
    if (termino.trim().isEmpty) return;
    setState(() => _buscando = true);
    try {
      final resultados = await _songService.buscar(termino);
      if (!mounted) return;
      setState(() {
        _resultados = resultados;
        _mostrandoPopulares = false;
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

    // La propina es obligatoria (ver _elegirMonto): el pago se autoriza en
    // el checkout de MercadoPago antes de que la solicitud exista — es esa
    // pantalla la que llama a crear la solicitud una vez que la tarjeta
    // quedó tokenizada (ver McpCheckoutScreen y CLAUDE.md, riesgo
    // "Autorización de pago vs. captura").
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
      SnackBar(
          content: const Text('Solicitud enviada al DJ'),
          backgroundColor: AppColors.limeDark),
    );
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
  static String _formatearClp(int valor) =>
      valor >= 1000 ? '\$${valor ~/ 1000}.000' : '\$$valor';

  static const List<int> _montosPredefinidos = [
    500,
    1000,
    2000,
    5000,
    10000,
    20000
  ];

  /// Monto válido: entre $500 y $20.000, y múltiplo de 50 (termina en 0, y
  /// la decena es 0 o 5 — ej. 600, 650, 700, 750). `null` si no cumple.
  static int? _validarMontoCustom(String texto) {
    final valor = int.tryParse(texto.trim());
    if (valor == null) return null;
    if (valor < 500 || valor > 20000) return null;
    if (valor % 50 != 0) return null;
    return valor;
  }

  /// Diálogo flotante y centrado (no un bottom sheet, que quedaba muy
  /// escondido abajo) con montos predefinidos entre $500 y $20.000 — la
  /// propina es obligatoria para pedir una canción, ya no hay alternativa
  /// de enviar la solicitud gratis.
  Future<(int, bool)?> _elegirMonto(ItunesTrack pista) async {
    var monto = _montosPredefinidos.first;
    var aceptaTerminos = false;
    var mostrarOtro = false;
    String? errorOtro;
    final otroController = TextEditingController();

    return showDialog<(int, bool)>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.limeGreen.withOpacity(0.18),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pista.trackName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(pista.artistName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 20),
                // El monto flota grande y centrado, imposible de pasar por
                // alto — antes era un campo de texto chico al fondo de la
                // pantalla.
                Text(
                  _formatearClp(monto),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.limeGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 40),
                ),
                const Text('CLP',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._montosPredefinidos.map((valor) {
                      final activo = !mostrarOtro && valor == monto;
                      return _chipMonto(
                        label: _formatearClp(valor),
                        activo: activo,
                        onTap: () => setState(() {
                          monto = valor;
                          mostrarOtro = false;
                          errorOtro = null;
                        }),
                      );
                    }),
                    _chipMonto(
                      label: 'Otro monto',
                      activo: mostrarOtro,
                      onTap: () => setState(() => mostrarOtro = true),
                    ),
                  ],
                ),
                if (mostrarOtro) ...[
                  const SizedBox(height: 12),
                  BudsoundTextField(
                    controller: otroController,
                    label: 'Monto exacto en CLP',
                    hint: 'Ej. 700',
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onChanged: (texto) {
                      final valido = _validarMontoCustom(texto);
                      setState(() {
                        if (valido != null) {
                          monto = valido;
                          errorOtro = null;
                        } else {
                          errorOtro = texto.trim().isEmpty
                              ? null
                              : 'Tiene que terminar en 0 o 50 (ej. 600, 650, 700), entre \$500 y \$20.000.';
                        }
                      });
                    },
                  ),
                  if (errorOtro != null) ...[
                    const SizedBox(height: 4),
                    Text(errorOtro!,
                        style:
                            TextStyle(color: AppColors.danger, fontSize: 11)),
                  ],
                ],
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Mínimo \$500, máximo \$20.000. No garantiza que suene, es solo un incentivo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: aceptaTerminos,
                  onChanged: (v) => setState(() => aceptaTerminos = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.limeGreen,
                  title: const Text(
                    'Entiendo que si el DJ acepta la propina, no hay devolución.',
                    style: TextStyle(color: AppColors.lavender, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                NeonGradientButton(
                  label: 'Enviar con propina',
                  onPressed: () {
                    if (mostrarOtro &&
                        _validarMontoCustom(otroController.text) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'Ingresa un monto válido antes de enviar.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }
                    if (!aceptaTerminos) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
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
      ),
    );
  }

  Widget _chipMonto({
    required String label,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? AppColors.limeGreen : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? AppColors.limeGreen : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: activo ? AppColors.onLime : AppColors.lavender,
            fontWeight: FontWeight.w700,
            fontSize: 13,
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
      child: Row(
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
            onChanged: _alEscribir,
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
          Expanded(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.limeGreen)))
        else
          Expanded(
            child: _resultados.isEmpty
                ? const Center(
                    child: Text('No se encontraron canciones.',
                        style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _resultados.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _mostrandoPopulares
                                ? 'Populares ahora'
                                : 'Resultados',
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        );
                      }
                      final pista = _resultados[index - 1];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 35 * (index - 1)),
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
                              trailing: Icon(Icons.add_circle_outline_rounded,
                                  color: AppColors.limeGreen),
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
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.muted),
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
        ? AppColors.limeGreen
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
            Text('Pagado',
                style: TextStyle(
                    color: AppColors.limeGreen, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
