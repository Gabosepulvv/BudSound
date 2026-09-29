import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_routes.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
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
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;

  bool _subiendoFoto = false;
  bool _guardandoDatos = false;

  @override
  void initState() {
    super.initState();
    final usuario = SessionService.instance.usuario;
    _nombreController = TextEditingController(text: usuario?.nombre ?? '');
    _apellidoController = TextEditingController(text: usuario?.apellido ?? '');
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
        const SnackBar(
          content: Text('Nombre y apellido no pueden quedar vacíos.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _guardandoDatos = true);
    final resultado =
        await _auth.actualizarPerfil(nombre: nombre, apellido: apellido);
    if (!mounted) return;
    setState(() => _guardandoDatos = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado.mensaje ?? resultado.error ?? ''),
        backgroundColor: resultado.exito ? AppColors.cobalt : AppColors.danger,
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
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.neonBlue),
              title: const Text('Tomar foto',
                  style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.of(context).pop(_OpcionFoto.camara),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.neonBlue),
              title: const Text('Elegir de la galería',
                  style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.of(context).pop(_OpcionFoto.galeria),
            ),
            if (tieneFoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                title: const Text('Quitar foto',
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
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            GlowLogo(size: 34),
            SizedBox(width: 10),
            Text('Perfil'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _avatar(usuario?.avatarDataUrl),
                const SizedBox(height: 16),
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
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Chip(
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.neonBlue),
                  label: Text(
                    esDj ? 'Perfil DJ' : 'Perfil público',
                    style: const TextStyle(color: AppColors.lavender),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Editar datos',
                  style: TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                BudsoundTextField(
                    controller: _nombreController, label: 'Nombre'),
                const SizedBox(height: 10),
                BudsoundTextField(
                    controller: _apellidoController, label: 'Apellido'),
                const SizedBox(height: 14),
                NeonGradientButton(
                  label: 'Guardar cambios',
                  loading: _guardandoDatos,
                  onPressed: _guardarDatos,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (esDj && usuario?.nombreArtistico != null)
            _fila('Nombre artístico', usuario!.nombreArtistico!),
          _fila(
            'Sesión',
            sesion.hasSession ? 'JWT restaurado en este dispositivo' : '—',
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (imagen != null)
            CircleAvatar(radius: 44, backgroundImage: imagen)
          else
            const GlowLogo(size: 72),
          if (_subiendoFoto)
            const CircularProgressIndicator(color: AppColors.neonBlue)
          else
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.neonBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded,
                    size: 14, color: AppColors.white),
              ),
            ),
        ],
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
