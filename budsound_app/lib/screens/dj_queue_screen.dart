import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_config.dart';
import '../models/event_model.dart';
import '../models/song_request_model.dart';
import '../services/dj_timer_service.dart';
import '../services/event_service.dart';
import '../services/event_socket.dart';
import '../services/request_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/image_data_url.dart';
import '../widgets/event_banner_image.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/solicitud_countdown.dart';

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
  final _picker = ImagePicker();
  late final EventSocket _socket;
  late EventModel _evento;

  List<SongRequestModel> _solicitudes = [];
  Map<String, dynamic>? _resumen;
  bool _cargando = true;
  bool _conectado = true;
  final Set<String> _resolviendo = {};

  // El estado del temporizador en sí vive en `DjTimerService.instance`, no
  // acá — así sigue corriendo aunque el DJ salga de esta pantalla y vuelva.
  // Este `Timer.periodic` es solo el "tick" que refresca la cuenta
  // regresiva en pantalla; no guarda tiempo, solo repinta.
  Timer? _tickTemporizador;

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
    if (DjTimerService.instance.activoPara(_evento.id) &&
        !DjTimerService.instance.pausado) {
      _iniciarTick();
    }
  }

  @override
  void dispose() {
    _socket.desconectar();
    _tickTemporizador?.cancel();
    super.dispose();
  }

  void _configurarTemporizador() async {
    final elegida = await showDialog<Duration>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Configurar temporizador',
            style: TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Te ayuda a controlar cuánto tiempo llevas tocando — es solo '
              'para ti, no afecta el evento ni lo ven los participantes.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Duration(minutes: 15),
                const Duration(minutes: 30),
                const Duration(minutes: 45),
                const Duration(hours: 1),
                const Duration(hours: 1, minutes: 30),
                const Duration(hours: 2),
                const Duration(hours: 3),
              ]
                  .map((d) => ActionChip(
                        label: Text(_formatearDuracionCorta(d)),
                        onPressed: () => Navigator.of(context).pop(d),
                        backgroundColor: AppColors.background,
                        labelStyle: const TextStyle(color: AppColors.lavender),
                        side: const BorderSide(color: AppColors.border),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (elegida == null) return;
    DjTimerService.instance.iniciar(_evento.id, elegida);
    _iniciarTick();
    setState(() {});
  }

  /// Refresca la UI una vez por segundo leyendo el tiempo restante desde
  /// `DjTimerService` — el servicio calcula contra la hora real, así que
  /// este tick nunca "pierde" segundos aunque se pause/reanude.
  void _iniciarTick() {
    _tickTemporizador?.cancel();
    _tickTemporizador = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DjTimerService.instance.restante.inSeconds <= 0) {
        _tickTemporizador?.cancel();
      }
      setState(() {});
    });
  }

  void _pausarOReanudarTemporizador() {
    if (DjTimerService.instance.pausado) {
      DjTimerService.instance.reanudar();
      _iniciarTick();
    } else {
      DjTimerService.instance.pausar();
      _tickTemporizador?.cancel();
    }
    setState(() {});
  }

  void _quitarTemporizador() {
    _tickTemporizador?.cancel();
    DjTimerService.instance.quitar();
    setState(() {});
  }

  String _formatearDuracionCorta(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final horas = d.inMinutes ~/ 60;
    final minutos = d.inMinutes % 60;
    return minutos == 0 ? '${horas}h' : '${horas}h ${minutos}min';
  }

  String _formatearCuentaRegresiva(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
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

  /// Confirma antes de aceptar o rechazar — una vez aceptada se autoriza
  /// el cobro de la propina (ver CLAUDE.md, riesgo "Autorización de pago
  /// vs. captura") y una vez rechazada se libera sin poder deshacerse; un
  /// toque de más no debería bastar para ninguna de las dos.
  Future<void> _confirmarYResolver(SongRequestModel solicitud,
      {required bool aceptar}) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          aceptar ? '¿Aceptar esta canción?' : '¿Rechazar esta canción?',
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          aceptar
              ? '"${solicitud.titulo}" de ${solicitud.artista}.'
                  '${solicitud.tienePropina ? ' Se va a cobrar la propina de \$${solicitud.montoClp} CLP.' : ''}'
              : '"${solicitud.titulo}" de ${solicitud.artista}.'
                  '${solicitud.tienePropina ? ' Se va a liberar la propina retenida, sin cobrarla.' : ''}',
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
            child: Text(
              aceptar ? 'Aceptar' : 'Rechazar',
              style: TextStyle(
                  color: aceptar ? AppColors.success : AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    if (!mounted) return;
    await _resolver(solicitud, aceptar: aceptar);
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

  /// Link a `/display/:code` (ver `display.controller.js`) — página
  /// pública, sin login, pensada para abrirse en una TV o tablet del
  /// local con el QR gigante, no en el celular. El código en sí es
  /// público por diseño (alcanza con verlo para unirse, escaneado o a
  /// mano), así que no hace falta ningún token acá.
  String get _linkPantalla => '${ApiConfig.socketUrl}/display/${_evento.code}';

  void _compartirCodigo() {
    Share.share(
      'Únete a "${_evento.nombre}" en BudSound y pide tu canción:\n'
      'Código: ${_evento.code}\n'
      'O ábrelo acá: $_linkPantalla',
      subject: 'Código de BudSound — ${_evento.nombre}',
    );
  }

  /// Abre `/display/:code` en el navegador del celular — desde ahí el DJ
  /// puede castear/espejar la pantalla a una TV, o mandar el link (ver
  /// `_compartirCodigo`) para abrirlo directo en una tablet del local.
  Future<void> _mostrarEnPantallaGrande() async {
    final uri = Uri.parse(_linkPantalla);
    final abrio = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abrio && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir el navegador.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// A diferencia del nombre artístico (ver decisión 35), la imagen del
  /// evento se puede cambiar o quitar en cualquier momento, activo o
  /// cerrado — no hay ninguna razón para bloquearla, es solo una imagen
  /// de referencia.
  Future<void> _cambiarImagenEvento() async {
    final opcion = await showModalBottomSheet<_OpcionImagenEvento>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.photo_camera_outlined, color: AppColors.limeGreen),
              title: const Text('Tomar foto',
                  style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.of(context).pop(_OpcionImagenEvento.camara),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.limeGreen),
              title: const Text('Elegir de la galería',
                  style: TextStyle(color: AppColors.white)),
              onTap: () =>
                  Navigator.of(context).pop(_OpcionImagenEvento.galeria),
            ),
            if (_evento.imagenDataUrl != null)
              ListTile(
                leading:
                    Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: Text('Quitar imagen',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () =>
                    Navigator.of(context).pop(_OpcionImagenEvento.quitar),
              ),
          ],
        ),
      ),
    );
    if (opcion == null) return;

    if (opcion == _OpcionImagenEvento.quitar) {
      await _guardarImagenEvento(quitar: true);
      return;
    }

    final XFile? archivo;
    try {
      archivo = await _picker.pickImage(
        source: opcion == _OpcionImagenEvento.camara
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No se pudo abrir la imagen: $e'),
            backgroundColor: AppColors.danger),
      );
      return;
    }
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    await _guardarImagenEvento(dataUrl: imagenABase64DataUrl(bytes));
  }

  Future<void> _guardarImagenEvento({String? dataUrl, bool quitar = false}) async {
    try {
      final actualizado = await _eventService.actualizarImagen(
        _evento.id,
        imagenDataUrl: dataUrl,
        quitarImagen: quitar,
      );
      if (!mounted) return;
      setState(() => _evento = actualizado);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
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
        SnackBar(
          content: const Text(
              'Evento cerrado. Abajo queda el resumen de recaudación.'),
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
              child: Text('Cerrar evento',
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
            if (_evento.activo) ...[
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _tarjetaTemporizador(),
              ),
            ],
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
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
        color: AppColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
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

  /// Temporizador opcional para que el DJ controle cuánto lleva tocando —
  /// el estado vive en `DjTimerService` (no en esta pantalla), así que
  /// sigue corriendo si sale de la cola y vuelve; solo se reinicia si se
  /// quita a mano o se cierra la app. Ni se guarda en el backend ni lo ve
  /// el público. El texto que explica para qué sirve queda siempre
  /// visible, no solo la primera vez, porque no todos los DJ van a usarlo
  /// y conviene que quede claro de un vistazo que es opcional y privado.
  Widget _tarjetaTemporizador() {
    final activo = DjTimerService.instance.activoPara(_evento.id);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: AppColors.limeGreen, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Temporizador',
                style: TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Te ayuda a controlar cuánto tiempo llevas tocando — es solo '
            'para ti, no afecta el evento ni lo ven los participantes.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (!activo)
            OutlinedButton.icon(
              onPressed: _configurarTemporizador,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.limeGreen,
                side: BorderSide(color: AppColors.limeGreen),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              icon: const Icon(Icons.add_alarm_rounded, size: 18),
              label: const Text('Configurar temporizador'),
            )
          else
            Row(
              children: [
                Text(
                  _formatearCuentaRegresiva(DjTimerService.instance.restante),
                  style: TextStyle(
                    color: DjTimerService.instance.restante.inSeconds <= 0
                        ? AppColors.danger
                        : AppColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _pausarOReanudarTemporizador,
                  icon: Icon(
                    DjTimerService.instance.pausado
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: AppColors.limeGreen,
                  ),
                  tooltip:
                      DjTimerService.instance.pausado ? 'Reanudar' : 'Pausar',
                ),
                IconButton(
                  onPressed: _quitarTemporizador,
                  icon: Icon(Icons.stop_rounded, color: AppColors.danger),
                  tooltip: 'Quitar',
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Imagen del evento (si tiene una) con un lápiz de "editar" encima; si
  /// no tiene ninguna, una franja angosta invitando a agregarla — el mismo
  /// toque abre el selector en los dos casos.
  Widget _bannerImagenEvento() {
    final imagen = decodificarImagenDataUrl(_evento.imagenDataUrl);
    if (imagen == null) {
      return Container(
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.muted, size: 18),
            SizedBox(width: 8),
            Text(
              'Agregar imagen al evento',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          EventBannerImage(image: imagen),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded,
                  color: AppColors.white, size: 16),
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
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _cambiarImagenEvento,
            child: _bannerImagenEvento(),
          ),
          const SizedBox(height: 16),
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
            style: AppTheme.fontDisplay(
              color: AppColors.white,
              fontSize: 24,
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
          if (_evento.horarioVisible != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  _evento.horarioVisible!,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ],
          if (_evento.generos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: _evento.generos
                  .map((g) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.limeGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                              color: AppColors.limeGreen, fontSize: 11),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (_evento.activo) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _compartirCodigo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.limeGreen,
                    side: BorderSide(color: AppColors.limeGreen),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir código'),
                ),
                OutlinedButton.icon(
                  onPressed: _mostrarEnPantallaGrande,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.lavender,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                  icon: const Icon(Icons.tv_rounded, size: 18),
                  label: const Text('Mostrar en pantalla grande'),
                ),
              ],
            ),
          ],
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
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: destacado ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Antes todo (carátula, título, BPM, estado, botones) iba en una sola
  /// `Row` apretada — con un título largo y el chip de BPM competiendo con
  /// el texto de estado ("Reproducida") se veía todo encimado. Ahora es un
  /// bloque arriba (carátula + título/artista + BPM) y una fila aparte
  /// abajo (participante/monto a la izquierda, acciones o estado a la
  /// derecha), con más aire entre cada parte.
  Widget _tarjetaSolicitud(SongRequestModel solicitud) {
    final resolviendo = _resolviendo.contains(solicitud.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _colorEstado(solicitud)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        solicitud.artista,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.lavender, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (solicitud.bpm != null) ...[
                  const SizedBox(width: 8),
                  _chipBpm(solicitud.bpm!),
                ],
              ],
            ),
            if (solicitud.pendiente) ...[
              const SizedBox(height: 6),
              SolicitudCountdown(createdAt: solicitud.createdAt),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '${solicitud.participanteNombreCompleto}'
                    '${solicitud.tienePropina ? ' · \$${solicitud.montoClp} CLP' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                if (solicitud.pendiente)
                  resolviendo
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.limeGreen),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _confirmarYResolver(solicitud,
                                  aceptar: false),
                              icon: Icon(Icons.close_rounded,
                                  color: AppColors.danger),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              onPressed: () => _confirmarYResolver(solicitud,
                                  aceptar: true),
                              icon: Icon(Icons.check_circle_rounded,
                                  color: AppColors.success),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        )
                else if (solicitud.aceptada && !solicitud.reproducida)
                  resolviendo
                      ? SizedBox(
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
                        fontSize: 12.5),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipBpm(int bpm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.limeGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.limeGreen.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq_rounded, size: 11, color: AppColors.limeGreen),
          const SizedBox(width: 3),
          Text(
            '$bpm BPM',
            style: TextStyle(
              color: AppColors.limeGreen,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(SongRequestModel solicitud) {
    if (solicitud.aceptada) return AppColors.success;
    if (solicitud.rechazada) return AppColors.danger;
    if (solicitud.cancelada) return AppColors.muted;
    return AppColors.border;
  }
}

enum _OpcionImagenEvento { camara, galeria, quitar }
