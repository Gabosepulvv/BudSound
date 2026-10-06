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
  bool _mostrarUnirse = false;
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
      setState(() => _cargandoEventoActual = false);
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
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
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

  @override
  Widget build(BuildContext context) {
    if (_cargandoEventoActual) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.limeGreen),
      );
    }

    if (_eventoActual != null && !_mostrarUnirse) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tarjetaEventoActual(_eventoActual!),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _mostrarUnirse = true),
                child: const Text('¿No es tu evento? Unirse a otro'),
              ),
            ],
          ),
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
                size: 72, color: AppColors.limeGreen),
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
              child: const Text('Unirse con el código'),
            ),
            if (_eventoActual != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _mostrarUnirse = false),
                child: const Text('Volver a mi evento actual'),
              ),
            ],
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
        border: Border.all(color: AppColors.limeGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.limeGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ESTÁS AQUÍ',
              style: TextStyle(
                  color: AppColors.onLime,
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
          const SizedBox(height: 16),
          NeonGradientButton(
            label: 'Pedir una canción',
            onPressed: _abrirEventoActual,
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Escanea el QR del evento'),
        actions: [
          ValueListenableBuilder<TorchState>(
            valueListenable: _controller.torchState,
            builder: (context, estado, _) => IconButton(
              onPressed: _controller.toggleTorch,
              icon: Icon(
                estado == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
              ),
              tooltip: 'Linterna',
            ),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          final valor = capture.barcodes.firstOrNull?.rawValue;
          if (valor != null && valor.isNotEmpty) {
            Navigator.of(context).pop(valor);
          }
        },
      ),
    );
  }
}

extension on List<Barcode> {
  Barcode? get firstOrNull => isEmpty ? null : first;
}
