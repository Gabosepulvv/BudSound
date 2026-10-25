import 'dart:convert';
import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_routes.dart';
import '../models/event_model.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/colorblind_mode_service.dart';
import '../services/event_service.dart';
import '../services/mp_connect_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../utils/image_data_url.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/glow_logo.dart';
import '../widgets/neon_gradient_button.dart';
import 'participant_history_screen.dart';

/// Perfil de sesión: foto, editar nombre/apellido, y cerrar sesión.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final _auth = AuthService();
  final _picker = ImagePicker();
  final _mpConnect = MpConnectService();
  final _eventService = EventService();
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _nombreArtisticoController;

  bool _subiendoFoto = false;
  bool _guardandoDatos = false;
  bool _editando = false;
  bool _eliminandoCuenta = false;

  MpConexionEstado? _mpEstado;
  bool _cargandoMp = false;

  // Resumen de toda la carrera del DJ (no solo un evento puntual) — vivía
  // en la pestaña "Inicio" (ya eliminada para el DJ, ver ShellScreen), se
  // movió acá porque Perfil es el lugar natural para ver tu historial
  // acumulado, no algo que cambie evento a evento.
  Map<String, dynamic>? _statsGeneral;
  bool _cargandoStats = false;

  // Eventos cerrados del DJ, más reciente primero — vivía como "Historial"
  // dentro de "En vivo" (`DjEventsScreen`); se movió acá junto con las
  // estadísticas, ya que ambos son resumen histórico, no algo del momento.
  List<EventModel>? _eventosPasados;
  // Solo se listan los 2 más recientes por defecto — el historial completo
  // de un DJ con muchos eventos haría la tarjeta de estadísticas
  // interminable; "Ver más eventos" lo despliega entero sin navegar a otra
  // pantalla.
  bool _verTodosLosPasados = false;
  static const _pasadosVisiblesPorDefecto = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final usuario = SessionService.instance.usuario;
    _nombreController = TextEditingController(text: usuario?.nombre ?? '');
    _apellidoController = TextEditingController(text: usuario?.apellido ?? '');
    _nombreArtisticoController =
        TextEditingController(text: usuario?.nombreArtistico ?? '');
    if (SessionService.instance.rol == UserRole.dj) {
      _cargarEstadoMp();
      _cargarStats();
    }
  }

  Future<void> _cargarStats() async {
    setState(() => _cargandoStats = true);
    try {
      final resultados = await Future.wait([
        _eventService.resumenGeneral(),
        _eventService.misEventos(),
      ]);
      if (!mounted) return;
      final eventos = resultados[1] as List<EventModel>;
      final pasados = eventos.where((e) => !e.activo).toList()
        ..sort((a, b) =>
            (b.closedAt ?? b.createdAt).compareTo(a.closedAt ?? a.createdAt));
      setState(() {
        _statsGeneral = resultados[0] as Map<String, dynamic>;
        _eventosPasados = pasados;
      });
    } catch (_) {
      // "Mejor esfuerzo": si falla, la sección simplemente no se muestra
      // en vez de tumbar el resto de Perfil.
    } finally {
      if (mounted) setState(() => _cargandoStats = false);
    }
  }

  // Conectar MercadoPago manda al DJ al navegador del sistema (ver
  // _conectarMp) — cuando vuelve a la app, Android la retoma en vez de
  // recrearla, así que sin esto el estado de "Cobros" se queda mostrando
  // "no conectado" hasta que la persona toque el botón de refrescar a
  // mano. `resumed` es el momento exacto en que la app vuelve a quedar
  // visible, tanto al volver del navegador como de cualquier otra app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        SessionService.instance.rol == UserRole.dj) {
      _cargarEstadoMp();
    }
  }

  Future<void> _cargarEstadoMp() async {
    setState(() => _cargandoMp = true);
    try {
      final estado = await _mpConnect.estado();
      if (!mounted) return;
      setState(() => _mpEstado = estado);
    } catch (_) {
      // Si falla, se deja el estado anterior (o null) — el botón de
      // refrescar permite reintentar sin bloquear el resto de la pantalla.
    } finally {
      if (mounted) setState(() => _cargandoMp = false);
    }
  }

  // Antes de abrir MercadoPago, se le avisa a la persona que si el
  // navegador del celular ya tiene una sesión guardada de OTRA cuenta (ej.
  // probando con varios DJ seguidos en el mismo dispositivo), MercadoPago
  // va a entrar directo con esa cuenta sin preguntar — no hay ningún
  // parámetro de la URL de autorización que fuerce un selector de cuentas
  // (se investigó, no existe). La única forma real de elegir otra cuenta es
  // abrir el link en un navegador distinto o en una pestaña de incógnito.
  Future<bool?> _confirmarCuentaMp() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Con qué cuenta vas a conectar?',
            style: TextStyle(color: AppColors.white)),
        content: Text(
          Platform.isAndroid
              ? 'Si este celular ya tiene una sesión de MercadoPago iniciada con otra cuenta, en el siguiente paso elige "Abrir con" un navegador distinto (o uno en modo incógnito) para poder entrar con la cuenta correcta — MercadoPago no pregunta, entra directo con la sesión que ya esté guardada.'
              : 'Si este dispositivo ya tiene una sesión de MercadoPago iniciada con otra cuenta, abre una pestaña privada en Safari antes de continuar — MercadoPago no pregunta, entra directo con la sesión que ya esté guardada.',
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
            child: const Text('Entendido, continuar'),
          ),
        ],
      ),
    );
  }

  Future<void> _conectarMp() async {
    final continuar = await _confirmarCuentaMp();
    if (continuar != true) return;

    setState(() => _cargandoMp = true);
    try {
      final authUrl = await _mpConnect.iniciarConexion();
      // En Android se fuerza el selector de apps ("Abrir con") en vez de
      // ir directo al navegador predeterminado — si ese navegador ya tiene
      // una sesión de MercadoPago guardada (de otra cuenta, ej. la del DJ
      // anterior), no hay forma de elegir "entra con otra cuenta" sin
      // cambiar de navegador. `launchUrl` normal no deja forzar esto: abre
      // directo en el predeterminado si hay uno configurado. iOS no tiene
      // este concepto (Safari es el único navegador real del sistema), así
      // que ahí se sigue usando url_launcher de siempre.
      if (Platform.isAndroid) {
        await AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: authUrl,
        ).launchChooser('Abrir con');
      } else {
        final uri = Uri.parse(authUrl);
        final abrio =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!abrio && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo abrir el navegador.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('No se pudo iniciar la conexión con MercadoPago.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoMp = false);
    }
  }

  Future<void> _desconectarMp() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Desconectar MercadoPago?',
            style: TextStyle(color: AppColors.white)),
        content: const Text(
          'Las propinas de tus próximos eventos van a volver a cobrarse en la cuenta central de BudSound hasta que conectes tu cuenta de nuevo.',
          style: TextStyle(color: AppColors.lavender),
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
                Text('Desconectar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cargandoMp = true);
    try {
      await _mpConnect.desconectar();
      if (!mounted) return;
      setState(() => _mpEstado = const MpConexionEstado(conectado: false));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo desconectar la cuenta.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoMp = false);
    }
  }

  void _empezarEdicion() {
    final usuario = SessionService.instance.usuario;
    _nombreController.text = usuario?.nombre ?? '';
    _apellidoController.text = usuario?.apellido ?? '';
    _nombreArtisticoController.text = usuario?.nombreArtistico ?? '';
    setState(() => _editando = true);
  }

  void _cancelarEdicion() {
    final usuario = SessionService.instance.usuario;
    _nombreController.text = usuario?.nombre ?? '';
    _apellidoController.text = usuario?.apellido ?? '';
    _nombreArtisticoController.text = usuario?.nombreArtistico ?? '';
    setState(() => _editando = false);
  }

  /// Días que faltan para poder volver a cambiar el nombre artístico (ver
  /// auth.controller.js, cooldown de 30 días) — null si nunca lo cambió o
  /// si el cooldown ya pasó. Se calcula acá mismo (sin pedirle nada al
  /// backend) porque ya tenemos la fecha en la sesión.
  int? get _diasRestantesCooldownNombreArtistico {
    final cambiadoAt = SessionService.instance.usuario?.nombreArtisticoCambiadoAt;
    if (cambiadoAt == null) return null;
    const cooldownDias = 30;
    final diasPasados = DateTime.now().difference(cambiadoAt).inDays;
    final restantes = cooldownDias - diasPasados;
    return restantes > 0 ? restantes : null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nombreController.dispose();
    _apellidoController.dispose();
    _nombreArtisticoController.dispose();
    super.dispose();
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    await SessionService.instance.cerrarSesion();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  /// Pide confirmación (y, si la cuenta tiene contraseña, que la repita) y
  /// borra la cuenta del lado del backend — irreversible, ver
  /// `auth.controller.js` → `eliminarCuenta`. No sabemos de antemano si la
  /// cuenta tiene contraseña (se creó con Google o no), así que el campo
  /// siempre se muestra como opcional; el backend es quien decide si la
  /// exige.
  Future<void> _confirmarEliminarCuenta(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('¿Eliminar tu cuenta?',
            style: TextStyle(color: AppColors.danger)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción no se puede deshacer. Se borran tu perfil, tus eventos y solicitudes asociadas.',
              style: TextStyle(color: AppColors.lavender),
            ),
            const SizedBox(height: 16),
            BudsoundTextField(
              controller: passwordController,
              label: 'Contraseña (si tu cuenta tiene una)',
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar cuenta',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    if (!mounted) return;

    setState(() => _eliminandoCuenta = true);
    final password = passwordController.text;
    final resultado = await _auth.eliminarCuenta(
      password: password.isEmpty ? null : password,
    );
    if (!mounted) return;
    setState(() => _eliminandoCuenta = false);

    if (!resultado.exito) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.error ?? 'No se pudo eliminar la cuenta.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    await SessionService.instance.cerrarSesion();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  Future<void> _guardarDatos() async {
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    if (nombre.isEmpty || apellido.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nombre y apellido no pueden quedar vacíos.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final usuario = SessionService.instance.usuario;
    final esDj = SessionService.instance.rol == UserRole.dj;
    final nombreArtistico = _nombreArtisticoController.text.trim();
    // Solo se manda si de verdad cambió — si está en cooldown el campo
    // queda de solo lectura (ver `_tarjetaDatos`), así que acá nunca
    // debería diferir del valor guardado, pero por las dudas no se
    // manda sin necesidad (evita gastar el único cambio del mes en un
    // "cambio" que en realidad dejó el mismo texto).
    final nombreArtisticoCambio = esDj &&
            _diasRestantesCooldownNombreArtistico == null &&
            nombreArtistico.isNotEmpty &&
            nombreArtistico != (usuario?.nombreArtistico ?? '')
        ? nombreArtistico
        : null;

    setState(() => _guardandoDatos = true);
    final resultado = await _auth.actualizarPerfil(
      nombre: nombre,
      apellido: apellido,
      nombreArtistico: nombreArtisticoCambio,
    );
    if (!mounted) return;
    setState(() {
      _guardandoDatos = false;
      if (resultado.exito) _editando = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado.mensaje ?? resultado.error ?? ''),
        backgroundColor:
            resultado.exito ? AppColors.limeDark : AppColors.danger,
      ),
    );
  }

  Future<void> _elegirFoto() async {
    final tieneFoto = SessionService.instance.usuario?.avatarDataUrl != null;
    final opcion = await showModalBottomSheet<_OpcionFoto>(
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
              onTap: () => Navigator.of(context).pop(_OpcionFoto.camara),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.limeGreen),
              title: const Text('Elegir de la galería',
                  style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.of(context).pop(_OpcionFoto.galeria),
            ),
            if (tieneFoto)
              ListTile(
                leading:
                    Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: Text('Quitar foto',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.of(context).pop(_OpcionFoto.quitar),
              ),
          ],
        ),
      ),
    );
    if (opcion == null) return;

    if (opcion == _OpcionFoto.quitar) {
      await _subirFoto(quitar: true);
      return;
    }

    final esCamara = opcion == _OpcionFoto.camara;
    final XFile? archivo;
    try {
      archivo = await _picker.pickImage(
        source: esCamara ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 75,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No se pudo abrir la ${esCamara ? 'cámara' : 'galería'}: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    await _subirFoto(dataUrl: imagenABase64DataUrl(bytes));
  }

  Future<void> _subirFoto({String? dataUrl, bool quitar = false}) async {
    setState(() => _subiendoFoto = true);
    final resultado = await _auth.actualizarPerfil(
        avatarDataUrl: dataUrl, quitarFoto: quitar);
    if (!mounted) return;
    setState(() => _subiendoFoto = false);
    if (!resultado.exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(resultado.error ?? 'No se pudo actualizar la foto.'),
            backgroundColor: AppColors.danger),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final sesion = SessionService.instance;
    final usuario = sesion.usuario;
    final esDj = sesion.rol == UserRole.dj;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _banner(usuario?.avatarDataUrl),
          const SizedBox(height: 52), // espacio para el avatar que sobresale
          Text(
            sesion.nombreVisible ?? 'Usuario Budsound',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sesion.email ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Center(
            child: Chip(
              backgroundColor: AppColors.background,
              side: BorderSide(color: AppColors.limeGreen),
              label: Text(
                esDj ? 'Perfil DJ' : 'Perfil público',
                style: const TextStyle(color: AppColors.lavender),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            child: Column(
              children: [
                _tarjetaDatos(esDj, usuario?.nombreArtistico),
                if (esDj) ...[
                  const SizedBox(height: 16),
                  _tarjetaCobros(),
                  if (_cargandoStats ||
                      (_statsGeneral != null && _statsGeneral!.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    _tarjetaEstadisticasDj(),
                  ],
                ],
                if (!esDj) ...[
                  const SizedBox(height: 16),
                  _tarjetaHistorial(),
                ],
                const SizedBox(height: 16),
                _tarjetaAccesibilidad(),
                const SizedBox(height: 16),
                _fila(
                  'Sesión',
                  sesion.hasSession
                      ? 'JWT restaurado en este dispositivo'
                      : '—',
                ),
                const SizedBox(height: 12),
                Text(
                  esDj
                      ? 'Desde En vivo puedes crear un evento, mostrar el QR y gestionar la cola de solicitudes.'
                      : 'Escanea el QR de un evento desde En vivo para pedir canciones al DJ.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 28),
                NeonGradientButton(
                  label: 'Cerrar sesión',
                  onPressed: () => _cerrarSesion(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Historial de propinas del Participante a través de todos sus eventos —
  /// solo tiene sentido para ese rol (el DJ ya ve su recaudación por evento
  /// en `DjQueueScreen._tarjetaResumen`).
  Widget _tarjetaHistorial() {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const ParticipantHistoryScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.limeGreen),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Historial de propinas',
                        style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text(
                      'Revisa las canciones que has pedido y cuánto has aportado.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  /// Portada estilo "banner de canal" con el avatar sobresaliendo desde
  /// abajo — reemplaza la tarjeta plana que había antes.
  Widget _banner(String? avatarDataUrl) {
    return SizedBox(
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surface, AppColors.background],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -20,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.glow.withValues(alpha: 0.5),
                          AppColors.glow.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(child: _avatar(avatarDataUrl)),
          ),
        ],
      ),
    );
  }

  /// Datos de perfil: muestra texto de solo lectura hasta que la persona
  /// toque "Editar" — el botón "Guardar cambios" solo aparece mientras
  /// está editando, no todo el tiempo.
  Widget _tarjetaDatos(bool esDj, String? nombreArtistico) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tus datos',
                  style: TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w700),
                ),
              ),
              if (!_editando)
                TextButton.icon(
                  onPressed: _empezarEdicion,
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.limeGreen),
                  label: Text('Editar',
                      style: TextStyle(color: AppColors.limeGreen)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_editando) ...[
            BudsoundTextField(controller: _nombreController, label: 'Nombre'),
            const SizedBox(height: 10),
            BudsoundTextField(
                controller: _apellidoController, label: 'Apellido'),
            if (esDj) ...[
              const SizedBox(height: 10),
              _campoNombreArtistico(),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardandoDatos ? null : _cancelarEdicion,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(color: AppColors.lavender)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeonGradientButton(
                    label: 'Guardar cambios',
                    loading: _guardandoDatos,
                    onPressed: _guardarDatos,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: _eliminandoCuenta
                    ? null
                    : () => _confirmarEliminarCuenta(context),
                icon: _eliminandoCuenta
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.danger),
                      )
                    : Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.danger),
                label: Text('Eliminar cuenta',
                    style: TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            ),
          ] else ...[
            _filaDato('Nombre completo',
                '${_nombreController.text} ${_apellidoController.text}'
                    .trim()),
            if (esDj && nombreArtistico != null) ...[
              const SizedBox(height: 14),
              _filaDato('Nombre artístico', nombreArtistico),
            ],
          ],
        ],
      ),
    );
  }

  /// Resumen de toda la carrera del DJ (no solo un evento puntual) — a
  /// diferencia de las métricas en vivo que se ven en "En vivo", estas
  /// cifras no desaparecen entre un evento y el siguiente.
  Widget _tarjetaEstadisticasDj() {
    final stats = _statsGeneral ?? const {};
    final eventos = stats['eventos_totales'] ?? 0;
    final aceptadas = stats['solicitudes_aceptadas'] ?? 0;
    final recaudado = stats['recaudacion_neta_clp'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _cargandoStats && _statsGeneral == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: AppColors.limeGreen),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estadísticas y eventos pasados',
                  style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Historial de todos tus eventos, no solo el de ahora.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _estadisticaTile(
                        icono: Icons.event_available_rounded,
                        valor: '$eventos',
                        etiqueta: 'Eventos',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _estadisticaTile(
                        icono: Icons.library_music_rounded,
                        valor: '$aceptadas',
                        etiqueta: 'Canciones',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _estadisticaTile(
                        icono: Icons.savings_rounded,
                        valor: '\$$recaudado',
                        etiqueta: 'Recaudado',
                      ),
                    ),
                  ],
                ),
                if (_eventosPasados != null && _eventosPasados!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  const Text(
                    'Eventos pasados',
                    style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    final hayMas = _eventosPasados!.length >
                        _pasadosVisiblesPorDefecto;
                    final visibles = _verTodosLosPasados || !hayMas
                        ? _eventosPasados!
                        : _eventosPasados!
                            .take(_pasadosVisiblesPorDefecto)
                            .toList();
                    return Column(
                      children: [
                        for (final evento in visibles) ...[
                          _filaEventoPasado(evento),
                          if (evento != visibles.last)
                            const Divider(color: AppColors.border, height: 20),
                        ],
                        if (hayMas) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() =>
                                  _verTodosLosPasados = !_verTodosLosPasados),
                              child: Text(
                                _verTodosLosPasados
                                    ? 'Ver menos'
                                    : 'Ver más eventos (${_eventosPasados!.length - _pasadosVisiblesPorDefecto})',
                                style: TextStyle(color: AppColors.limeGreen),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ],
            ),
    );
  }

  Widget _filaEventoPasado(EventModel evento) {
    final imagen = decodificarImagenDataUrl(evento.imagenDataUrl);

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            image: imagen != null
                ? DecorationImage(image: imagen, fit: BoxFit.cover)
                : null,
          ),
          child: imagen == null
              ? const Icon(Icons.lock_outline_rounded,
                  color: AppColors.muted, size: 18)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                evento.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              Text(
                evento.fechaVisible,
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _estadisticaTile({
    required IconData icono,
    required String valor,
    required String etiqueta,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icono, color: AppColors.limeGreen, size: 18),
          const SizedBox(height: 6),
          Text(
            valor,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  /// Conexión con MercadoPago para recibir propinas directo en la cuenta
  /// del DJ (menos la comisión de BudSound) — ver CLAUDE.md, "¿A quién le
  /// llega la plata primero?". Sin conectar, las propinas se siguen
  /// cobrando en la cuenta central, como hasta ahora.
  Widget _tarjetaCobros() {
    final conectado = _mpEstado?.conectado ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cobros',
                  style: TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _cargandoMp ? null : _cargarEstadoMp,
                icon: const Icon(Icons.refresh_rounded,
                    size: 20, color: AppColors.muted),
                tooltip: 'Actualizar estado',
              ),
            ],
          ),
          const SizedBox(height: 10),
          conectado ? _tarjetaMpConectada() : _tarjetaMpVacia(),
        ],
      ),
    );
  }

  /// Tarjeta de cobro conectada — imita una tarjeta bancaria real (chip,
  /// nombre del titular, identificador) en vez de una línea de texto plana,
  /// para que el DJ reconozca de un vistazo "esto es mi cuenta de cobro" y
  /// pueda verificar que es la correcta sin tener que leer con atención.
  Widget _tarjetaMpConectada() {
    final nombre = _mpEstado?.nickname ?? 'Cuenta conectada';
    final email = _mpEstado?.email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.glow, Color(0xFF241737)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // El "chip" de la tarjeta — puramente decorativo, para
                  // que de lejos se lea como una tarjeta y no como una
                  // notificación más.
                  Container(
                    width: 34,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8D28C), Color(0xFFC2A258)],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'CONECTADA',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              if (email != null) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.bolt_rounded,
                      size: 14, color: Colors.white.withValues(alpha: 0.65)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Las propinas de tus eventos llegan directo acá',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _cargandoMp ? null : _desconectarMp,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.danger),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _cargandoMp
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.danger),
                )
              : Text('Desconectar',
                  style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }

  /// Estado vacío — invita a conectar en vez de solo avisar que falta algo.
  /// El borde punteado imita el "agrega una tarjeta" de apps de billetera,
  /// un patrón que cualquier DJ ya reconoce de otras apps.
  Widget _tarjetaMpVacia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomPaint(
          painter: const _BordePunteadoPainter(color: AppColors.border),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            child: Column(
              children: [
                Icon(Icons.add_card_rounded,
                    size: 34, color: AppColors.limeGreen),
                const SizedBox(height: 12),
                const Text(
                  'Registra tu cuenta para empezar a recibir pagos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Conecta tu MercadoPago y las propinas de tus eventos van a llegar directo a tu cuenta, sin pasar por la de BudSound.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        NeonGradientButton(
          label: 'Conectar MercadoPago',
          loading: _cargandoMp,
          onPressed: _conectarMp,
        ),
      ],
    );
  }

  /// Reemplaza el verde lima y el rojo de error por azul/naranja — ver
  /// app_colors.dart. Se guarda en el dispositivo y aplica a toda la app de
  /// inmediato (ListenableBuilder en main.dart), sin reiniciar.
  Widget _tarjetaAccesibilidad() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 20, color: AppColors.limeGreen),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modo daltónico',
                    style: TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(
                  'Cambia el verde y el rojo de la app por azul y naranja, más fáciles de distinguir.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: ColorblindModeService.instance.enabled,
            activeThumbColor: AppColors.limeGreen,
            onChanged: (valor) {
              ColorblindModeService.instance.establecer(valor);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  /// El nombre artístico solo se puede cambiar sin un evento activo y
  /// máximo 1 vez cada 30 días (ver auth.controller.js) — el cooldown se
  /// calcula acá mismo (ya está en la sesión), pero el de "sin evento
  /// activo" lo valida el backend al guardar (no vale la pena pedirle la
  /// lista de eventos a esta pantalla solo para eso).
  Widget _campoNombreArtistico() {
    final diasRestantes = _diasRestantesCooldownNombreArtistico;
    final enCooldown = diasRestantes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BudsoundTextField(
          controller: _nombreArtisticoController,
          label: 'Nombre artístico',
          readOnly: enCooldown,
        ),
        const SizedBox(height: 6),
        Text(
          enCooldown
              ? 'Ya lo cambiaste hace poco — podrás volver a hacerlo en $diasRestantes día${diasRestantes == 1 ? '' : 's'}.'
              : 'Solo se puede cambiar sin un evento activo, y como máximo una vez cada 30 días.',
          style: TextStyle(
            color: enCooldown ? AppColors.danger : AppColors.muted,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  /// Etiqueta chica arriba, valor abajo — más liviano que una tabla de dos
  /// columnas "etiqueta: valor", y es el mismo lenguaje visual que ya usan
  /// las estadísticas del DJ (`_estadisticaTile`).
  Widget _filaDato(String etiqueta, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          valor.isEmpty ? '—' : valor,
          style: const TextStyle(
              color: AppColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _avatar(String? avatarDataUrl) {
    ImageProvider? imagen;
    if (avatarDataUrl != null && avatarDataUrl.contains(',')) {
      try {
        imagen = MemoryImage(base64Decode(avatarDataUrl.split(',').last));
      } catch (_) {
        imagen = null;
      }
    }

    return GestureDetector(
      onTap: _subiendoFoto ? null : _elegirFoto,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (imagen != null)
              CircleAvatar(radius: 44, backgroundImage: imagen)
            else
              const GlowLogo(size: 72),
            if (_subiendoFoto)
              CircularProgressIndicator(color: AppColors.limeGreen)
            else
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.limeGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded,
                      size: 14, color: AppColors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OpcionFoto { camara, galeria, quitar }

/// Borde punteado con esquinas redondeadas — usado en el estado vacío de
/// "Cobros" (ver `_tarjetaMpVacia`) para imitar el "agrega una tarjeta" de
/// apps de billetera. Flutter no trae esto de fábrica; se dibuja a mano
/// recorriendo el perímetro del `RRect` en tramos fijos de línea/espacio.
class _BordePunteadoPainter extends CustomPainter {
  const _BordePunteadoPainter({required this.color});

  final Color color;

  static const _radio = 16.0;
  static const _largoTrazo = 6.0;
  static const _largoHueco = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(_radio),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metric.length) {
        final siguiente = (distancia + _largoTrazo).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distancia, siguiente), paint);
        distancia += _largoTrazo + _largoHueco;
      }
    }
  }

  @override
  bool shouldRepaint(_BordePunteadoPainter oldDelegate) =>
      oldDelegate.color != color;
}
