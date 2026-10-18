import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/event_model.dart';
import '../models/song_request_model.dart';
import '../services/event_service.dart';
import '../services/request_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/image_data_url.dart';
import '../widgets/avatar_encabezado.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/dj_timer_chip.dart';
import '../widgets/event_banner_image.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/neon_gradient_button.dart';
import 'dj_queue_screen.dart';

/// Vista del DJ en la pestaña "En vivo": sus eventos y crear uno nuevo.
class DjEventsScreen extends StatefulWidget {
  const DjEventsScreen({super.key});

  @override
  State<DjEventsScreen> createState() => _DjEventsScreenState();
}

/// Misma lista y mismo orden que `GENEROS_VALIDOS` en event.controller.js
/// — el backend rechaza cualquier valor que no esté ahí, así que si se
/// agrega un género acá hay que agregarlo también del lado del backend.
const _generosDisponibles = [
  'Reggaetón',
  'Pop',
  'Rock',
  'Electrónica',
  'Cumbia',
  'Hip-Hop/Rap',
  'Salsa',
  'Bachata',
  'Techno/House',
  'Indie',
  'Trap',
  'Variado',
];

/// Combos rápidos de los géneros de arriba — un toque para marcar varios a
/// la vez en vez de ir chip por chip. Son temáticas, no géneros nuevos: al
/// tocar uno se seleccionan sus géneros en `_generosDisponibles`, nada más.
/// (Un filtro por idioma, ej. "solo en inglés", no es posible: la Search
/// API de iTunes no expone ningún parámetro de idioma — ver
/// itunes.service.js.)
const _temasPredefinidos = <String, List<String>>{
  'Solo géneros latinos': ['Reggaetón', 'Cumbia', 'Salsa', 'Bachata'],
  'Urbano/Trap': ['Reggaetón', 'Hip-Hop/Rap', 'Trap'],
  'Rock/Indie': ['Rock', 'Indie'],
  'Electrónica/House': ['Electrónica', 'Techno/House'],
};

class _DjEventsScreenState extends State<DjEventsScreen> {
  final _eventService = EventService();
  final _requestService = RequestService();
  final _picker = ImagePicker();
  late Future<List<EventModel>> _eventosFuture;

  @override
  void initState() {
    super.initState();
    _eventosFuture = _eventService.misEventos();
  }

  void _recargar() {
    // Cuerpo de bloque a propósito: `setState(() => _eventosFuture = ...)`
    // hace que el closure "devuelva" el Future de la asignación, y
    // setState lanza un assert en tiempo de ejecución si su callback
    // devuelve un Future (piensa que olvidaste un await).
    setState(() {
      _eventosFuture = _eventService.misEventos();
    });
  }

  Future<void> _crearEvento() async {
    final controller = TextEditingController();
    TimeOfDay? horaInicio;
    TimeOfDay? horaFin;
    DateTime? fechaInicio;
    DateTime? fechaFin;
    // La mayoría de los eventos son de un solo día — con esto activado,
    // un solo selector de fecha alcanza y `fechaFin` se mantiene igual a
    // `fechaInicio` sola; se desactiva solo para festivales/eventos que
    // cruzan más de un día.
    var unSoloDia = true;
    final generosElegidos = <String>{};
    String? imagenDataUrl;

    String formatear(TimeOfDay? hora) {
      if (hora == null) return 'Elegir';
      final h = hora.hour.toString().padLeft(2, '0');
      final m = hora.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    String formatearFecha(DateTime? fecha) {
      if (fecha == null) return 'Elegir';
      final d = fecha.day.toString().padLeft(2, '0');
      final m = fecha.month.toString().padLeft(2, '0');
      return '$d/$m/${fecha.year}';
    }

    final datos = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> elegirHora({required bool esInicio}) async {
            final elegida = await showTimePicker(
              context: context,
              initialTime: (esInicio ? horaInicio : horaFin) ??
                  TimeOfDay.now(),
            );
            if (elegida == null) return;
            setDialogState(() {
              if (esInicio) {
                horaInicio = elegida;
              } else {
                horaFin = elegida;
              }
            });
          }

          Future<void> elegirFecha({required bool esInicio}) async {
            final ahora = DateTime.now();
            final elegida = await showDatePicker(
              context: context,
              initialDate: (esInicio ? fechaInicio : fechaFin) ??
                  fechaInicio ??
                  ahora,
              firstDate: DateTime(ahora.year - 1),
              lastDate: DateTime(ahora.year + 2),
            );
            if (elegida == null) return;
            setDialogState(() {
              if (esInicio || unSoloDia) {
                fechaInicio = elegida;
                if (unSoloDia) fechaFin = elegida;
              } else {
                fechaFin = elegida;
              }
            });
          }

          Future<void> elegirImagen() async {
            final opcion = await showModalBottomSheet<_OpcionImagenEvento>(
              context: context,
              backgroundColor: AppColors.surface,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.photo_camera_outlined,
                          color: AppColors.limeGreen),
                      title: const Text('Tomar foto',
                          style: TextStyle(color: AppColors.white)),
                      onTap: () => Navigator.of(context)
                          .pop(_OpcionImagenEvento.camara),
                    ),
                    ListTile(
                      leading: Icon(Icons.photo_library_outlined,
                          color: AppColors.limeGreen),
                      title: const Text('Elegir de la galería',
                          style: TextStyle(color: AppColors.white)),
                      onTap: () => Navigator.of(context)
                          .pop(_OpcionImagenEvento.galeria),
                    ),
                    if (imagenDataUrl != null)
                      ListTile(
                        leading: Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger),
                        title: Text('Quitar imagen',
                            style: TextStyle(color: AppColors.danger)),
                        onTap: () => Navigator.of(context)
                            .pop(_OpcionImagenEvento.quitar),
                      ),
                  ],
                ),
              ),
            );
            if (opcion == null) return;
            if (opcion == _OpcionImagenEvento.quitar) {
              setDialogState(() => imagenDataUrl = null);
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
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('No se pudo abrir la imagen: $e'),
                    backgroundColor: AppColors.danger),
              );
              return;
            }
            if (archivo == null) return;
            final bytes = await archivo.readAsBytes();
            setDialogState(
                () => imagenDataUrl = imagenABase64DataUrl(bytes));
          }

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Nuevo evento',
              style: TextStyle(color: AppColors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BudsoundTextField(
                      controller: controller,
                      label: 'Nombre del evento',
                      hint: 'Ej. Noche Neon',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Imagen del evento (opcional)',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _selectorImagenEvento(
                      imagenDataUrl: imagenDataUrl,
                      onTap: elegirImagen,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _botonHora(
                            etiqueta: 'Hora de inicio',
                            valor: formatear(horaInicio),
                            onPressed: () => elegirHora(esInicio: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _botonHora(
                            etiqueta: 'Hora de término',
                            valor: formatear(horaFin),
                            onPressed: () => elegirHora(esInicio: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // "¿Qué día es?", no "¿cuándo lo creaste?" — sirve
                    // para que el DJ pueda ubicar el evento en su
                    // historial (Perfil) meses después, no para nada en
                    // tiempo real.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Evento de un solo día',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        Switch(
                          value: unSoloDia,
                          activeThumbColor: AppColors.limeGreen,
                          onChanged: (valor) => setDialogState(() {
                            unSoloDia = valor;
                            if (valor) fechaFin = fechaInicio;
                          }),
                        ),
                      ],
                    ),
                    if (unSoloDia)
                      _botonHora(
                        etiqueta: 'Fecha del evento',
                        valor: formatearFecha(fechaInicio),
                        onPressed: () => elegirFecha(esInicio: true),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _botonHora(
                              etiqueta: 'Fecha de inicio',
                              valor: formatearFecha(fechaInicio),
                              onPressed: () => elegirFecha(esInicio: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _botonHora(
                              etiqueta: 'Fecha de término',
                              valor: formatearFecha(fechaFin),
                              onPressed: () => elegirFecha(esInicio: false),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Temáticas rápidas (opcional)',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _temasPredefinidos.entries.map((tema) {
                        return ActionChip(
                          label: Text(tema.key),
                          onPressed: () {
                            setDialogState(() {
                              generosElegidos
                                ..clear()
                                ..addAll(tema.value);
                            });
                          },
                          backgroundColor: AppColors.background,
                          labelStyle: const TextStyle(
                              color: AppColors.lavender, fontSize: 12),
                          side: const BorderSide(color: AppColors.border),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Géneros que sonarán',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _generosDisponibles.map((genero) {
                        final elegido = generosElegidos.contains(genero);
                        return FilterChip(
                          label: Text(genero),
                          selected: elegido,
                          onSelected: (valor) {
                            setDialogState(() {
                              if (valor) {
                                generosElegidos.add(genero);
                              } else {
                                generosElegidos.remove(genero);
                              }
                            });
                          },
                          backgroundColor: AppColors.background,
                          selectedColor: AppColors.limeGreen.withValues(alpha: 0.22),
                          checkmarkColor: AppColors.limeGreen,
                          labelStyle: TextStyle(
                            color: elegido
                                ? AppColors.limeGreen
                                : AppColors.lavender,
                            fontSize: 12.5,
                          ),
                          side: BorderSide(
                            color: elegido
                                ? AppColors.limeGreen
                                : AppColors.border,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  final nombre = controller.text.trim();
                  if (nombre.isEmpty) return;
                  if (horaInicio == null || horaFin == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Elige la hora de inicio y de término del evento.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  if (fechaInicio == null || fechaFin == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Elige la fecha del evento.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  if (generosElegidos.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Elige al menos un género para el evento.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop({
                    'nombre': nombre,
                    'horaInicio': horaInicio!,
                    'horaFin': horaFin!,
                    'fechaInicio': fechaInicio!,
                    'fechaFin': fechaFin!,
                    'generos': generosElegidos.toList(),
                    'imagenDataUrl': imagenDataUrl,
                  });
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );

    if (datos == null) return;

    String aHHmm(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    try {
      final evento = await _eventService.crear(
        datos['nombre'] as String,
        horaInicio: aHHmm(datos['horaInicio'] as TimeOfDay),
        horaFin: aHHmm(datos['horaFin'] as TimeOfDay),
        fechaInicio: datos['fechaInicio'] as DateTime,
        fechaFin: datos['fechaFin'] as DateTime,
        generos: (datos['generos'] as List).cast<String>(),
        imagenDataUrl: datos['imagenDataUrl'] as String?,
      );
      if (!mounted) return;
      _recargar();
      _abrirCola(evento);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Widget _botonHora({
    required String etiqueta,
    required String valor,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta,
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(valor),
        ),
      ],
    );
  }

  /// Caja de 72px con la imagen elegida (o un ícono de cámara si todavía no
  /// hay ninguna) — el mismo toque abre el selector tanto para poner una
  /// imagen nueva como para cambiar la que ya había.
  Widget _selectorImagenEvento({
    required String? imagenDataUrl,
    required VoidCallback onTap,
  }) {
    final imagen = decodificarImagenDataUrl(imagenDataUrl);
    if (imagen == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.muted, size: 22),
              SizedBox(height: 4),
              Text(
                'Agregar imagen',
                style: TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            EventBannerImage(image: imagen, height: 72),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded,
                    color: AppColors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cuando no hay evento activo pero el DJ sí tiene historial (eventos
  /// cerrados) — distinto del estado totalmente vacío de `_tarjetaVacia`.
  /// El historial en sí vive en Perfil → Estadísticas, no acá.
  Widget _tarjetaSinActivo() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nightlife_rounded, size: 32, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'No tienes un evento activo ahora mismo',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              'Tu historial de eventos pasados está en Perfil → Estadísticas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  /// Saludo del DJ — vivía en la pestaña "Inicio" (ya eliminada para el
  /// DJ, ver ShellScreen); se movió acá porque "En vivo" es lo primero que
  /// un DJ ve ahora al entrar a la app.
  Widget _encabezado() {
    final sesion = SessionService.instance;
    final saludo = sesion.nombreVisible ?? sesion.email ?? 'DJ';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AvatarEncabezado(
            fondoColor: AppColors.limeGreen,
            icono: Icons.headphones_rounded,
            iconoColor: AppColors.onLime,
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
                Text(
                  'Panel de control de tu evento',
                  style: TextStyle(
                    color: AppColors.limeGreen,
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

  /// Estado vacío cuando el DJ nunca ha creado ningún evento — mismo
  /// lugar de donde vivía antes en "Inicio" (`_tarjetaVaciaDj`), sin el
  /// botón "Crear evento" propio porque el encabezado de arriba ya tiene
  /// uno (evita duplicarlo).
  Widget _tarjetaVacia() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.limeGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.podcasts_rounded,
                  size: 32, color: AppColors.limeGreen),
            ),
            const SizedBox(height: 16),
            const Text(
              'Todavía no has creado ningún evento',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Crea un evento para generar tu QR, abrir tu cola en vivo y empezar a recibir solicitudes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// Solo el evento activo (a lo más uno, por la regla de "un DJ, un
  /// evento a la vez" — ver event.controller.js). Los cerrados ya no se
  /// listan acá — su historial vive en Perfil → Estadísticas.
  Widget _listaEventos(EventModel activo) {
    return RefreshIndicator(
      onRefresh: () async => _recargar(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [_tarjeta(activo)],
      ),
    );
  }

  void _abrirCola(EventModel evento) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DjQueueScreen(evento: evento)))
        .then((_) => _recargar());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventModel>>(
      future: _eventosFuture,
      builder: (context, snapshot) {
        final cargando = snapshot.connectionState == ConnectionState.waiting;
        final eventos = snapshot.data ?? [];
        // Un DJ no puede tener dos eventos activos a la vez (ver
        // event.controller.js) — mientras tenga uno, el botón "Crear
        // evento" se reemplaza por un aviso con acceso directo a ese
        // evento, en vez de dejar que la persona lo intente y recién ahí
        // se entere con un error.
        EventModel? activo;
        for (final e in eventos) {
          if (e.activo) {
            activo = e;
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlideIn(child: _encabezado()),
                  const SizedBox(height: 18),
                  const Text(
                    'Tus eventos',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (cargando || activo == null) ...[
                    const Text(
                      'Crea un evento para generar el QR y recibir solicitudes en vivo.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    NeonGradientButton(
                      label: 'Crear evento',
                      onPressed: cargando ? null : _crearEvento,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: cargando
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.limeGreen),
                    )
                  : snapshot.hasError
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${snapshot.error}',
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextButton(
                                    onPressed: _recargar,
                                    child: const Text('Reintentar')),
                              ],
                            ),
                          ),
                        )
                      : eventos.isEmpty
                          ? _tarjetaVacia()
                          : activo != null
                              ? _listaEventos(activo)
                              : _tarjetaSinActivo(),
            ),
          ],
        );
      },
    );
  }

  // Colores "sobre blanco" de la tarjeta del evento activo — el resto de
  // la app usa AppColors.white/lavender/muted pensados para texto claro
  // sobre fondo oscuro, que quedan invisibles o lavados sobre una tarjeta
  // blanca (ver _tarjeta más abajo). Locales a este archivo porque es la
  // única tarjeta clara en una app que es oscura por todos lados.
  static const _textoSobreBlanco = Color(0xFF17151F);
  static const _textoSecundarioSobreBlanco = Color(0xFF5B5868);

  /// Esta pantalla ya solo muestra el evento activo acá (ver
  /// `_listaEventos`) — con el aviso de "ya tienes un evento activo" de
  /// arriba eliminado, esta tarjeta es lo único que dice "esto es lo que
  /// está pasando ahora", así que se le da trato de protagonista: fondo
  /// blanco (en vez del mismo tono oscuro de toda la app) para que
  /// destaque de un vistazo, con banner de imagen completo arriba si
  /// tiene una.
  Widget _tarjeta(EventModel evento) {
    final imagen = decodificarImagenDataUrl(evento.imagenDataUrl);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _abrirCola(evento),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imagen != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: EventBannerImage(image: imagen, height: 130),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.limeGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTIVO',
                          style: TextStyle(
                            color: AppColors.onLime,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          color: _textoSecundarioSobreBlanco, size: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    evento.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.fontDisplay(
                      color: _textoSobreBlanco,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Código ${evento.code} · ${evento.fechaVisible}'
                    '${evento.horarioVisible != null ? ' · ${evento.horarioVisible}' : ''}',
                    style: const TextStyle(
                        color: _textoSecundarioSobreBlanco, fontSize: 12.5),
                  ),
                  if (evento.generos.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      evento.generos.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.limeGreen, fontSize: 11.5),
                    ),
                  ],
                  DjTimerChip(eventoId: evento.id),
                  _previaSolicitudes(evento),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista previa de las solicitudes que van llegando, directo en la
  /// tarjeta del evento activo — para que el DJ vea de un vistazo si hay
  /// algo nuevo sin tener que entrar a "Ver cola en vivo" cada vez.
  /// "Mejor esfuerzo": se pide una sola vez por build de la tarjeta (no
  /// hay socket acá, esta pantalla es la lista de eventos, no la cola en
  /// vivo en sí) — para algo en tiempo real de verdad está
  /// `DjQueueScreen`, a un toque de distancia.
  Widget _previaSolicitudes(EventModel evento) {
    return FutureBuilder<List<SongRequestModel>>(
      future: _requestService.listarPorEvento(evento.id, status: 'PENDIENTE'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.limeGreen),
            ),
          );
        }

        final solicitudes = snapshot.data!;
        if (solicitudes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
              'Sin solicitudes pendientes todavía.',
              style: TextStyle(
                  color: _textoSecundarioSobreBlanco, fontSize: 12.5),
            ),
          );
        }

        const maxVisibles = 3;
        final visibles = solicitudes.take(maxVisibles).toList();
        final restantes = solicitudes.length - visibles.length;

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 1, color: AppColors.border.withValues(alpha: 0.15)),
              const SizedBox(height: 12),
              Text(
                'Llegando ahora',
                style: TextStyle(
                  color: AppColors.limeGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              for (final s in visibles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded,
                          size: 13, color: _textoSecundarioSobreBlanco),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${s.titulo} — ${s.artista}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _textoSecundarioSobreBlanco,
                              fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '\$${s.montoClp}',
                        style: const TextStyle(
                            color: _textoSobreBlanco,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              if (restantes > 0)
                Text(
                  '+$restantes más',
                  style: const TextStyle(
                      color: _textoSecundarioSobreBlanco, fontSize: 11.5),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _OpcionImagenEvento { camara, galeria, quitar }
