import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/event_model.dart';
import '../services/api_client.dart';
import '../services/event_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/neon_gradient_button.dart';
import 'participant_event_screen.dart';

/// Punto de entrada del Participante: si ya está en un evento, muestra una
/// vista previa de acceso directo; si no, escanear el QR del DJ o escribir
/// el código a mano.
class ParticipantJoinScreen extends StatefulWidget {
  const ParticipantJoinScreen({super.key});

  @override
  State<ParticipantJoinScreen> createState() => _ParticipantJoinScreenState();
}

class _ParticipantJoinScreenState extends State<ParticipantJoinScreen> {
  final _eventService = EventService();
  final _codigoController = TextEditingController();
  bool _cargando = false;
  bool _cargandoEventoActual = true;
  EventModel? _eventoActual;

  @override
  void initState() {
    super.initState();
    _cargarEventoActual();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  /// Revalida contra el backend el código guardado del último evento al que
  /// se unió este dispositivo — puede haberse cerrado desde la última vez.
  Future<void> _cargarEventoActual() async {
    final code = SessionService.instance.ultimoEventoCode;
    if (code == null) {
      setState(() {
        _eventoActual = null;
        _cargandoEventoActual = false;
      });
      return;
    }
    try {
      final evento = await _eventService.buscarPorCodigo(code);
      if (!mounted) return;
      setState(() {
        _eventoActual = evento;
        _cargandoEventoActual = false;
      });
    } on ApiException {
      await SessionService.instance.limpiarUltimoEventoCode();
      if (!mounted) return;
      setState(() => _cargandoEventoActual = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoEventoActual = false);
    }
  }

  Future<void> _unirsePorCodigo(String codigo) async {
    if (codigo.trim().isEmpty || _cargando) return;
    setState(() => _cargando = true);
    try {
      final evento = await _eventService.buscarPorCodigo(codigo);
      await SessionService.instance.guardarUltimoEventoCode(evento.code);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ParticipantEventScreen(evento: evento)),
      );
      if (mounted) _cargarEventoActual();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException
              ? e.message
              : 'No se pudo completar la acción. Revisa tu conexión.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (codigo != null) _unirsePorCodigo(codigo);
  }

  Future<void> _abrirEventoActual() async {
    final evento = _eventoActual;
    if (evento == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ParticipantEventScreen(evento: evento)),
    );
    if (mounted) _cargarEventoActual();
  }

  /// Dejar el evento actual sin esperar a que cierre o a que el código
  /// guardado deje de servir — el participante lo pide expresamente.
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
    setState(() => _eventoActual = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoEventoActual) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.success),
      );
    }

    // Mientras el participante siga en un evento activo, no puede unirse a
    // otro — ni escaneando ni escribiendo un código a mano (se quitó el
    // "¿No es tu evento? Unirse a otro" que había antes). En cuanto el
    // evento actual cierra, `_cargarEventoActual` lo nota solo (limpia
    // `ultimoEventoCode`) y esta pantalla vuelve a la vista normal de
    // unirse sin que haga falta nada más acá.
    if (_eventoActual != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _tarjetaEventoActual(_eventoActual!),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner_rounded,
                size: 72, color: AppColors.success),
            const SizedBox(height: 16),
            const Text(
              'Únete a un evento',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Escanea el código QR del DJ o escribe el código del evento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            NeonGradientButton(
              label: 'Escanear código QR',
              loading: _cargando,
              color: AppColors.success,
              colorTexto: AppColors.onSuccess,
              onPressed: _escanear,
            ),
            const SizedBox(height: 18),
            const Text('o', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            BudsoundTextField(
              controller: _codigoController,
              label: 'Código del evento',
              hint: 'Ej. NRFQHU',
              textInputAction: TextInputAction.go,
              prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _unirsePorCodigo(_codigoController.text),
              style: TextButton.styleFrom(foregroundColor: AppColors.success),
              child: const Text('Unirse con el código'),
            ),
          ],
        ),
      ),
    );
  }

  /// Acceso directo al evento al que ya se unió este dispositivo — antes,
  /// esta pestaña mostraba siempre la pantalla de "escanear QR" aunque ya
  /// se estuviera en un evento, obligando a buscarlo de nuevo.
  Widget _tarjetaEventoActual(EventModel evento) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ESTÁS AQUÍ',
              style: TextStyle(
                  color: AppColors.onSuccess,
                  fontSize: 10,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            evento.nombre,
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Código ${evento.code}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (evento.generos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: evento.generos
                  .map((g) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                              color: AppColors.success, fontSize: 11),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          NeonGradientButton(
            label: 'Pedir una canción',
            color: AppColors.success,
            colorTexto: AppColors.onSuccess,
            onPressed: _abrirEventoActual,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _salirDelEvento,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Salir del evento'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

/// Pantalla de escaneo con linterna manual — discotecas y lugares con luces
/// en movimiento pueden hacer fallar la cámara sin ella (ver CLAUDE.md,
/// riesgo "Escaneo de QR con poca luz").
class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final _controller = MobileScannerController();
  // Sin esto, si onDetect dispara más de una vez con el mismo QR (pasa
  // seguido mientras la cámara sigue leyendo cuadros de video de camino a
  // cerrarse), se intenta hacer pop() dos veces sobre la misma ruta — la
  // segunda vez no hay nada que cerrar y la pantalla queda colgada en
  // negro en vez de navegar.
  bool _yaDetectado = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Escanea el QR del evento'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, estado, _) {
                final prendida = estado.torchState == TorchState.on;
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: prendida
                        ? AppColors.limeGreen
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                  child: IconButton(
                    onPressed: _controller.toggleTorch,
                    icon: Icon(
                      prendida
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: prendida ? AppColors.onLime : Colors.white,
                    ),
                    tooltip: 'Linterna',
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_yaDetectado) return;
              final valor = capture.barcodes.firstOrNull?.rawValue;
              if (valor != null && valor.isNotEmpty) {
                _yaDetectado = true;
                Navigator.of(context).pop(valor);
              }
            },
            // Por defecto, si la cámara falla, mobile_scanner solo muestra
            // un ícono sobre fondo negro, sin ningún texto — imposible
            // saber qué pasó realmente (permiso denegado, cámara en uso,
            // etc.) sin conectar el celular a una computadora. Mostrar el
            // error acá mismo en pantalla deja ver la causa real con solo
            // una captura.
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudo abrir la cámara.\nVerifica que le diste permiso de cámara a BudSound en el celular.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${error.errorCode.name}: ${error.errorDetails?.message ?? "sin más detalles"}',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            placeholderBuilder: (context) => const Center(
              child: Text('Iniciando cámara…',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ),
          // Puramente decorativo: oscurece todo menos el recuadro central y
          // marca sus esquinas, para que quede claro dónde apuntar el QR en
          // vez de mostrar la cámara pelada a pantalla completa.
          IgnorePointer(
            child: CustomPaint(
              painter: _VisorEscaneoPainter(color: AppColors.limeGreen),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.42),
            child: Text(
              'Apunta la cámara al código QR del evento',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja el visor de escaneo: un recuadro central despejado (el resto de
/// la pantalla se oscurece) con sus 4 esquinas marcadas en el acento de la
/// marca — el patrón visual estándar de cualquier app de escaneo QR, en vez
/// de mostrar la cámara a pantalla completa sin ninguna referencia de dónde
/// apuntar.
class _VisorEscaneoPainter extends CustomPainter {
  _VisorEscaneoPainter({required this.color});

  final Color color;
  static const double _ladoRecuadro = 260;
  static const double _radioEsquinas = 24;
  static const double _largoMarca = 32;
  static const double _grosorMarca = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2 - 24);
    final recuadro = Rect.fromCenter(
      center: centro,
      width: _ladoRecuadro,
      height: _ladoRecuadro,
    );
    final recuadroRedondeado =
        RRect.fromRectAndRadius(recuadro, const Radius.circular(_radioEsquinas));

    final velo = Path()
      ..addRect(Rect.largest)
      ..addRRect(recuadroRedondeado)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(velo, Paint()..color = Colors.black.withValues(alpha: 0.55));

    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _grosorMarca
      ..strokeCap = StrokeCap.round;

    void esquina(Offset esquinaPunto, Offset haciaX, Offset haciaY) {
      canvas.drawLine(esquinaPunto, esquinaPunto + haciaX * _largoMarca, trazo);
      canvas.drawLine(esquinaPunto, esquinaPunto + haciaY * _largoMarca, trazo);
    }

    final izq = recuadro.left;
    final der = recuadro.right;
    final arr = recuadro.top;
    final abj = recuadro.bottom;
    esquina(Offset(izq, arr), const Offset(1, 0), const Offset(0, 1));
    esquina(Offset(der, arr), const Offset(-1, 0), const Offset(0, 1));
    esquina(Offset(izq, abj), const Offset(1, 0), const Offset(0, -1));
    esquina(Offset(der, abj), const Offset(-1, 0), const Offset(0, -1));
  }

  @override
  bool shouldRepaint(covariant _VisorEscaneoPainter oldDelegate) =>
      oldDelegate.color != color;
}

extension on List<Barcode> {
  Barcode? get firstOrNull => isEmpty ? null : first;
}
