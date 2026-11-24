import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/event_model.dart';
import '../models/itunes_track.dart';
import '../models/pending_song_request.dart';
import '../models/song_request_model.dart';
import '../services/api_client.dart';
import '../services/event_socket.dart';
import '../services/pending_requests_store.dart';
import '../services/request_service.dart';
import '../services/session_service.dart';
import '../services/song_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/clp_format.dart';
import '../widgets/ambient_lights_background.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/neon_gradient_button.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/song_waveform.dart';
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
        // Mismo fix que en DjQueueScreen: sin este refresco, una
        // solicitud resuelta por el DJ mientras el socket estaba caído
        // nunca llega — el reconnect solo reenvía lo pendiente local
        // (_reintentarPendientes), no refresca el estado de lo que ya
        // se había enviado antes del corte.
        onConectado: () {
          if (!mounted) return;
          setState(() => _conectado = true);
          _reintentarPendientes();
          _cargarMisSolicitudes();
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

  /// Dejar el evento actual sin esperar a que cierre — el participante lo
  /// pide expresamente desde donde pasa el tiempo pidiendo canciones.
  Future<void> _salirDelEvento() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Salir del evento?',
            style: TextStyle(color: AppColors.white)),
        content: const Text(
          'Vas a dejar de ver este evento en tu app. Puedes volver a unirte '
          'cuando quieras escaneando el QR o escribiendo el código.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await SessionService.instance.limpiarUltimoEventoCode();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Canciones populares que se muestran apenas se abre la pestaña, antes
  /// de escribir nada — así nunca es una pantalla vacía.
  Future<void> _cargarPopulares() async {
    setState(() => _buscando = true);
    try {
      final resultados = await _songService.top(eventId: widget.evento.id);
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
      final resultados =
          await _songService.buscar(termino, eventId: widget.evento.id);
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
        SnackBar(
          content: Text(e is ApiException
              ? e.message
              : 'No se pudo completar la acción. Revisa tu conexión.'),
          backgroundColor: AppColors.danger,
        ),
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

    // Mientras el backend no tenga credenciales reales de MercadoPago (ej.
    // el build de demo para la primera APK), se salta el Card Payment
    // Brick por completo y se confirma una propina simulada — ver
    // RequestService.pagoRealActivo. Si falla la consulta, se asume que
    // SÍ hay pago real (más seguro: nunca queremos saltarnos un cobro de
    // verdad por un error de red puntual).
    bool pagoReal;
    try {
      pagoReal = await _requestService.pagoRealActivo();
    } catch (_) {
      pagoReal = true;
    }
    if (!mounted) return;

    bool pagada;
    if (pagoReal) {
      // La propina es obligatoria (ver _elegirMonto): el pago se autoriza en
      // el checkout de MercadoPago antes de que la solicitud exista — es esa
      // pantalla la que llama a crear la solicitud una vez que la tarjeta
      // quedó tokenizada (ver McpCheckoutScreen y CLAUDE.md, riesgo
      // "Autorización de pago vs. captura").
      pagada = await Navigator.of(context).push<bool>(
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
          ) ??
          false;
    } else {
      pagada = await _confirmarPagoSimulado(
        pista: pista,
        montoClp: monto,
        terminosAceptados: terminosAceptados,
      );
    }
    if (!pagada) return;
    await _cargarMisSolicitudes();
    if (!mounted) return;
    _tabController.animateTo(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: const Text('Solicitud enviada al DJ'),
          backgroundColor: AppColors.limeDark),
    );
  }

  /// Reemplaza el checkout real cuando el backend no tiene credenciales de
  /// MercadoPago cargadas (ver `_pedirCancion` y RequestService.
  /// pagoRealActivo) — confirma la propina directo, sin tarjeta ni WebView,
  /// para no perder el flujo completo (pedir → aceptar/rechazar) en un
  /// build de demo. Deja clarísimo en el diálogo que no es un cobro real.
  Future<bool> _confirmarPagoSimulado({
    required ItunesTrack pista,
    required int montoClp,
    required bool terminosAceptados,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: Icon(Icons.science_outlined, color: AppColors.limeGreen, size: 32),
        title: const Text('Propina simulada (demo)',
            style: TextStyle(color: AppColors.white)),
        content: Text(
          'Esta versión de demostración no cobra de verdad. Se registrará '
          'una propina de \$${montoClp.toString()} CLP simulada para que el '
          'DJ pueda aceptar o rechazar la solicitud igual que en producción.',
          style: const TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                Text('Confirmar', style: TextStyle(color: AppColors.limeGreen)),
          ),
        ],
      ),
    );
    if (confirmar != true) return false;
    if (!mounted) return false;

    try {
      await _requestService.crear(
        eventId: widget.evento.id,
        itunesTrackId: pista.trackId,
        titulo: pista.trackName,
        artista: pista.artistName,
        artworkUrl: pista.artworkUrl,
        montoClp: montoClp,
        terminosAceptados: terminosAceptados,
      );
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo conectar con el servidor.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return false;
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
  static String _formatearClp(int valor) => formatearClp(valor);

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
    // 1 = el monto subió (el dígito nuevo entra desde abajo), -1 = bajó
    // (entra desde arriba) — para el efecto "odómetro" del monto grande.
    var direccionMonto = 1;
    // Breve estado "éxito" (check en el botón) antes de cerrar el diálogo
    // — le da tiempo al ojo de registrar que sí se envió, en vez de que el
    // diálogo desaparezca de golpe apenas se toca el botón.
    var enviado = false;
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
              borderRadius: BorderRadius.circular(20),
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, animation) => ClipRect(
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.6 * direccionMonto),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                  ),
                  child: Text(
                    _formatearClp(monto),
                    key: ValueKey(monto),
                    textAlign: TextAlign.center,
                    style: AppTheme.numeric(
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                      fontSize: 48,
                      letterSpacing: -1.9,
                    ),
                  ),
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
                          direccionMonto = valor > monto ? 1 : -1;
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
                          direccionMonto = valido > monto ? 1 : -1;
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
                  activeColor: AppColors.success,
                  title: const Text(
                    'Entiendo que si el DJ acepta la propina, no hay devolución.',
                    style: TextStyle(color: AppColors.lavender, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                NeonGradientButton(
                  label: 'Enviar propina',
                  exito: enviado,
                  onPressed: enviado
                      ? null
                      : () async {
                          if (mostrarOtro &&
                              _validarMontoCustom(otroController.text) ==
                                  null) {
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
                          HapticFeedback.mediumImpact();
                          setState(() => enviado = true);
                          if (!AppMotion.of(context).reducida) {
                            await Future.delayed(
                                const Duration(milliseconds: 260));
                          }
                          if (context.mounted) {
                            Navigator.of(context)
                                .pop((monto, aceptaTerminos));
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Píldora de 44 de alto — el chip seleccionado va en [AppColors.white]
  /// (textPrimary) con el texto en [AppColors.background], invirtiendo el
  /// contraste normal para que se note de un vistazo cuál está elegido, sin
  /// necesitar un borde.
  Widget _chipMonto({
    required String label,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: activo ? AppColors.white : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: activo ? AppColors.background : AppColors.lavender,
            fontWeight: FontWeight.w600,
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
        actions: [
          IconButton(
            onPressed: _salirDelEvento,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Salir del evento',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Buscar canción'),
            Tab(text: 'Mis solicitudes'),
          ],
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientLightsBackground()),
          Column(
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
        ],
      ),
    );
  }

  Widget _bannerSinConexion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppColors.danger.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
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
        if (widget.evento.generos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mostrando ${widget.evento.generos.join(', ')} — lo que pide este evento.',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        if (_buscando)
          Expanded(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.success)))
        else
          Expanded(
            child: _resultados.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        widget.evento.generos.isNotEmpty
                            ? 'No se encontraron canciones de ${widget.evento.generos.join(', ')} con ese término.'
                            : 'No se encontraron canciones.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
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
                        delay: AppMotion.of(context).escalonado(index - 1),
                        child: PressableScale(
                          onTap: () => _pedirCancion(pista),
                          child: Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
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
                                  color: AppColors.success),
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
          final delay = AppMotion.of(context).escalonado(index);
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

  /// Punto de 8px que reemplaza la franja lateral/borde de color de antes
  /// — ver `DjQueueScreen._puntoEstado`, mismo patrón.
  Widget _puntoEstado(Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  /// Carátula de la canción con el mismo recorte/tamaño que en los
  /// resultados de búsqueda — antes estas tarjetas no mostraban ninguna
  /// imagen, así que una vez enviada la solicitud la canción perdía toda
  /// identidad visual.
  Widget _caratula(String? artworkUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: artworkUrl == null || artworkUrl.isEmpty
          ? Container(
              width: 48,
              height: 48,
              color: AppColors.background,
              child: const Icon(Icons.album_rounded,
                  color: AppColors.muted, size: 22),
            )
          : Image.network(
              artworkUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: AppColors.background,
                child: const Icon(Icons.album_rounded,
                    color: AppColors.muted, size: 22),
              ),
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _puntoEstado(AppColors.muted),
          const SizedBox(width: 8),
          _caratula(pendiente.artworkUrl),
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
                const Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.muted),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sin conexión — se enviará sola',
                        style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (pendiente.montoClp > 0) ...[
            const SizedBox(width: 8),
            Text(
              _formatearClp(pendiente.montoClp),
              style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaSolicitud(SongRequestModel solicitud) {
    // Azul = en cola, ámbar = aceptada, rojo = rechazada, gris = cancelada
    // por tiempo (ver DECISIONES_TECNICAS.md, rebranding "Cabina minimal" —
    // reemplaza la franja lateral de color de antes por un punto de 8px).
    final color = solicitud.aceptada
        ? AppColors.success
        : solicitud.rechazada
            ? AppColors.danger
            : solicitud.cancelada
                ? AppColors.muted
                : AppColors.limeGreen;

    // Decorativo puro, nunca representa un progreso real de reproducción
    // (ver CLAUDE.md) — solo distingue "esperando" (sin nada "reproducido")
    // de "aceptada" (a medio camino, señal de que viene en camino) y
    // "reproducida" (toda la barra). No se muestra si quedó
    // rechazada/cancelada, ahí no aporta nada.
    final mostrarOnda = !solicitud.rechazada && !solicitud.cancelada;
    final ondaFraccion =
        solicitud.reproducida ? 1.0 : solicitud.aceptada ? 0.45 : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _puntoEstado(color),
              const SizedBox(width: 8),
              _caratula(solicitud.artworkUrl),
              const SizedBox(width: 12),
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
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      solicitud.pendiente
                          ? 'Esperando al DJ'
                          : solicitud.aceptada
                              ? (solicitud.reproducida
                                  ? 'Reproducida'
                                  : 'Aceptada')
                              : solicitud.cancelada
                                  ? 'Cancelada (sin respuesta a tiempo)'
                                  : 'Rechazada',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (solicitud.tienePropina) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatearClp(solicitud.montoClp),
                      style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    // La propina se autoriza al crear la solicitud y se cobra
                    // sola cuando el DJ acepta (ver McpCheckoutScreen) — no
                    // hay un paso de pago manual aparte que el Participante
                    // tenga que hacer acá.
                    if (solicitud.aceptada)
                      Text('Pagado',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                  ],
                ),
              ],
            ],
          ),
          if (mostrarOnda) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SongWaveform(
                playedFraction: ondaFraccion,
                seed: solicitud.id.hashCode,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
