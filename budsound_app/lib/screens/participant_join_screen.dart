import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/event_service.dart';
import '../theme/app_colors.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/neon_gradient_button.dart';
import 'participant_event_screen.dart';

/// Punto de entrada del Participante: escanear el QR del DJ o escribir el
/// código a mano.
class ParticipantJoinScreen extends StatefulWidget {
  const ParticipantJoinScreen({super.key});

  @override
  State<ParticipantJoinScreen> createState() => _ParticipantJoinScreenState();
}

class _ParticipantJoinScreenState extends State<ParticipantJoinScreen> {
  final _eventService = EventService();
  final _codigoController = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _unirsePorCodigo(String codigo) async {
    if (codigo.trim().isEmpty || _cargando) return;
    setState(() => _cargando = true);
    try {
      final evento = await _eventService.buscarPorCodigo(codigo);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ParticipantEventScreen(evento: evento)),
      );
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 72, color: AppColors.neonBlue),
            const SizedBox(height: 16),
            const Text(
              'Únete a un evento',
              style: TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w700),
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
          ],
        ),
      ),
    );
  }
}

class _QrScannerScreen extends StatelessWidget {
  const _QrScannerScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Escanea el QR del evento'),
      ),
      body: MobileScanner(
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
