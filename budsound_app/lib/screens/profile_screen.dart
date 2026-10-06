import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_routes.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/colorblind_mode_service.dart';
import '../services/mp_connect_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/glow_logo.dart';
import '../widgets/neon_gradient_button.dart';

/// Perfil de sesión: foto, editar nombre/apellido, y cerrar sesión.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _picker = ImagePicker();
  final _mpConnect = MpConnectService();
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;

  bool _subiendoFoto = false;
  bool _guardandoDatos = false;
  bool _editando = false;

  MpConexionEstado? _mpEstado;
  bool _cargandoMp = false;

  @override
  void initState() {
    super.initState();
    final usuario = SessionService.instance.usuario;
    _nombreController = TextEditingController(text: usuario?.nombre ?? '');
    _apellidoController = TextEditingController(text: usuario?.apellido ?? '');
    if (SessionService.instance.rol == UserRole.dj) {
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

  Future<void> _conectarMp() async {
    setState(() => _cargandoMp = true);
    try {
      final authUrl = await _mpConnect.iniciarConexion();
      final uri = Uri.parse(authUrl);
      final abrio = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abrio && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo abrir el navegador.'),
            backgroundColor: AppColors.danger,
          ),
        );
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
    setState(() => _editando = true);
  }

  void _cancelarEdicion() {
    final usuario = SessionService.instance.usuario;
    _nombreController.text = usuario?.nombre ?? '';
    _apellidoController.text = usuario?.apellido ?? '';
    setState(() => _editando = false);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
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

    setState(() => _guardandoDatos = true);
    final resultado =
        await _auth.actualizarPerfil(nombre: nombre, apellido: apellido);
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
    final dataUrl =
        'data:${_detectarMime(bytes)};base64,${base64Encode(bytes)}';
    await _subirFoto(dataUrl: dataUrl);
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

  /// image_picker no garantiza el formato de salida (puede ser JPEG, PNG o
  /// WEBP según la plataforma) — se detecta por los primeros bytes en vez
  /// de asumirlo, para no mandarle al backend un content-type incorrecto.
  String _detectarMime(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              children: [
                _tarjetaDatos(esDj, usuario?.nombreArtistico),
                if (esDj) ...[
                  const SizedBox(height: 16),
                  _tarjetaCobros(),
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
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.limeGreen.withOpacity(0.28),
                          blurRadius: 90,
                          spreadRadius: 30,
                        ),
                      ],
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
        border: Border.all(color: AppColors.border),
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
          ] else ...[
            _filaDato('Nombre', _nombreController.text),
            const SizedBox(height: 10),
            _filaDato('Apellido', _apellidoController.text),
            if (esDj && nombreArtistico != null) ...[
              const SizedBox(height: 10),
              _filaDato('Nombre artístico', nombreArtistico),
            ],
          ],
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
        border: Border.all(color: AppColors.border),
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
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                conectado
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 18,
                color: conectado ? AppColors.limeGreen : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  conectado
                      ? 'MercadoPago conectado — las propinas de tus eventos llegan directo a tu cuenta.'
                      : 'Todavía no conectas tu cuenta de MercadoPago — las propinas se cobran en la cuenta central de BudSound.',
                  style:
                      const TextStyle(color: AppColors.lavender, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (conectado)
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
            )
          else
            NeonGradientButton(
              label: 'Conectar MercadoPago',
              loading: _cargandoMp,
              onPressed: _conectarMp,
            ),
        ],
      ),
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
        border: Border.all(color: AppColors.border),
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

  Widget _filaDato(String etiqueta, String valor) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(etiqueta,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            valor.isEmpty ? '—' : valor,
            style: const TextStyle(
                color: AppColors.white, fontWeight: FontWeight.w600),
          ),
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
          border: Border.all(color: AppColors.border),
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
