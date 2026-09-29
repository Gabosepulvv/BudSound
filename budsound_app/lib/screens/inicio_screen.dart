import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';
import '../services/event_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glow_logo.dart';
import '../widgets/neon_gradient_button.dart';
import 'dj_queue_screen.dart';
import 'participant_event_screen.dart';

/// Panel de inicio: para el DJ, acceso directo a su evento activo (o crear
/// uno); para el Participante, acceso directo al evento que ya escaneó (o
/// aviso de que todavía no escanea ningún QR). Reemplaza el catálogo de
/// iTunes que había antes — ver CLAUDE.md, "Decisión legal": nunca se
/// reproduce un preview dentro de la app.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, required this.onIrAEnVivo});

  /// Cambia la pestaña activa del shell a "En vivo".
  final VoidCallback onIrAEnVivo;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final _eventService = EventService();

  bool _cargando = true;
  EventModel? _evento;

  bool get _esDj => SessionService.instance.rol == UserRole.dj;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final evento = _esDj
          ? await _buscarEventoActivoDelDj()
          : await _buscarUltimoEventoDelParticipante();
      if (!mounted) return;
      setState(() {
        _evento = evento;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _evento = null;
        _cargando = false;
      });
    }
  }

  Future<EventModel?> _buscarEventoActivoDelDj() async {
    final eventos = await _eventService.misEventos();
    for (final evento in eventos) {
      if (evento.activo) return evento;
    }
    return null;
  }

  Future<EventModel?> _buscarUltimoEventoDelParticipante() async {
    final code = SessionService.instance.ultimoEventoCode;
    if (code == null) return null;

    try {
      return await _eventService.buscarPorCodigo(code);
    } on ApiException {
      // El evento ya no existe o fue cerrado: el código guardado ya no sirve.
      await SessionService.instance.limpiarUltimoEventoCode();
      return null;
    }
  }

  void _abrirEvento() {
    final evento = _evento;
    if (evento == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => _esDj
                ? DjQueueScreen(evento: evento)
                : ParticipantEventScreen(evento: evento),
          ),
        )
        .then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
    final sesion = SessionService.instance;
    final saludo = sesion.nombreVisible ?? sesion.email ?? 'tú';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            GlowLogo(size: 34),
            SizedBox(width: 10),
            Text('Inicio'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Hola, $saludo',
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.neonBlue)),
              )
            else if (_evento != null)
              _tarjetaEventoActivo(_evento!)
            else
              _tarjetaVacia(),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEventoActivo(EventModel evento) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neonBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTIVO',
                  style: TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
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
            label: _esDj ? 'Ver cola en vivo' : 'Pedir una canción',
            onPressed: _abrirEvento,
          ),
        ],
      ),
    );
  }

  Widget _tarjetaVacia() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            _esDj ? Icons.podcasts_rounded : Icons.qr_code_scanner_rounded,
            size: 48,
            color: AppColors.muted,
          ),
          const SizedBox(height: 14),
          Text(
            _esDj
                ? 'Todavía no has creado ningún evento'
                : 'Todavía no has escaneado ningún código QR',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _esDj
                ? 'Crea un evento en la pestaña En vivo para generar tu QR y recibir solicitudes.'
                : 'Escanea el QR del DJ desde la pestaña En vivo para empezar a pedir canciones.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          NeonGradientButton(
            label: 'Ir a En vivo',
            onPressed: widget.onIrAEnVivo,
          ),
        ],
      ),
    );
  }
}
