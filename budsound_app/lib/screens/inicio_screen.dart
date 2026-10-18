import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/api_client.dart';
import '../services/event_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/image_data_url.dart';
import '../widgets/avatar_encabezado.dart';
import '../widgets/event_banner_image.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/glow_logo.dart';
import '../widgets/neon_gradient_button.dart';
import 'participant_event_screen.dart';

/// Panel de inicio del Participante: acceso directo simple al evento que ya
/// escaneó, o una invitación a escanear uno si no tiene ninguno. El DJ no
/// usa esta pantalla — su equivalente (saludo + estado de su evento) vive
/// en "En vivo" (`DjEventsScreen`), y sus estadísticas en Perfil. Reemplaza
/// el catálogo de iTunes que había antes — ver CLAUDE.md, "Decisión legal":
/// nunca se reproduce un preview dentro de la app.
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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final evento = await _buscarUltimoEventoDelParticipante();
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
            builder: (_) => ParticipantEventScreen(evento: evento),
          ),
        )
        .then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
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
        child: _bodyParticipante(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Participante: panel simple, deliberadamente distinto al del DJ.
  // ---------------------------------------------------------------------

  Widget _bodyParticipante() {
    final sesion = SessionService.instance;
    final saludo = sesion.nombreVisible ?? sesion.email ?? 'tú';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        FadeSlideIn(child: _encabezadoParticipante(saludo)),
        const SizedBox(height: 18),
        if (_cargando)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.limeGreen)),
          )
        else if (_evento != null)
          FadeSlideIn(child: _tarjetaEventoActivoParticipante(_evento!))
        else
          FadeSlideIn(child: _tarjetaVaciaParticipante()),
      ],
    );
  }

  /// Mismo lenguaje visual que `_encabezadoDj` (ícono + saludo + subtítulo
  /// en una tarjeta), pero en tonos neutros en vez de lima — para que se
  /// note que es la misma app sin confundirse con el panel del DJ (ver
  /// CLAUDE.md).
  Widget _encabezadoParticipante(String saludo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const AvatarEncabezado(
            fondoColor: AppColors.background,
            icono: Icons.person_rounded,
            iconoColor: AppColors.muted,
            bordeColor: AppColors.border,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $saludo',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Pide canciones en los eventos a los que te unas',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// El acento es verde (`AppColors.success`) — un color de marca propio
  /// para el Participante, no el violeta del DJ ni el de "solicitud
  /// aprobada" que usa ese mismo verde en otras pantallas (son contextos
  /// distintos, no compiten entre sí).
  Widget _tarjetaEventoActivoParticipante(EventModel evento) {
    final imagen = decodificarImagenDataUrl(evento.imagenDataUrl);
    final djImagen = decodificarImagenDataUrl(evento.djAvatarDataUrl);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imagen != null) EventBannerImage(image: imagen),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ACTIVO',
                    style: TextStyle(
                        color: AppColors.onSuccess,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  evento.nombre,
                  style: AppTheme.fontDisplay(
                    color: AppColors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Código ${evento.code}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                if (evento.djNombreArtistico != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.background,
                        backgroundImage: djImagen,
                        child: djImagen == null
                            ? const Icon(Icons.headphones_rounded,
                                size: 14, color: AppColors.muted)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'DJ ${evento.djNombreArtistico}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.lavender,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                if (evento.horarioVisible != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        evento.horarioVisible!,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                NeonGradientButton(
                  label: 'Pedir una canción',
                  color: AppColors.success,
                  colorTexto: AppColors.onSuccess,
                  onPressed: _abrirEvento,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaVaciaParticipante() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_scanner_rounded, size: 48, color: AppColors.muted),
          const SizedBox(height: 14),
          const Text(
            'Todavía no has escaneado ningún código QR',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Escanea el QR del DJ desde la pestaña En vivo para empezar a pedir canciones.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          NeonGradientButton(
            label: 'Ir a En vivo',
            color: AppColors.success,
            colorTexto: AppColors.onSuccess,
            onPressed: widget.onIrAEnVivo,
          ),
        ],
      ),
    );
  }
}
