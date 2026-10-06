import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/dark_neon_scaffold.dart';
import '../widgets/glow_logo.dart';
import '../widgets/neon_gradient_button.dart';
import '../widgets/role_segmented_control.dart';

/// Registro con selector de rol Público / DJ.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _djController = TextEditingController();
  final _fechaController = TextEditingController();
  final _auth = AuthService();

  DateTime? _fechaNacimiento;
  UserRole _rol = UserRole.publico;
  bool _ocultarPassword = true;
  bool _cargando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _djController.dispose();
    _fechaController.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final seleccion = await showDatePicker(
      context: context,
      initialDate: DateTime(ahora.year - 18, ahora.month, ahora.day),
      firstDate: DateTime(1950),
      lastDate: ahora,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.limeGreen,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion == null) return;
    setState(() {
      _fechaNacimiento = seleccion;
      _fechaController.text = _formatearFecha(seleccion);
    });
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  Future<void> _ingresarCuenta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);
    final usuario = UserModel(
      nombre: _nombreController.text.trim(),
      apellido: _apellidoController.text.trim(),
      email: _emailController.text.trim(),
      fechaNacimiento: _fechaNacimiento!,
      rol: _rol,
      nombreArtistico:
          _rol == UserRole.dj ? _djController.text.trim() : null,
    );

    final result = await _auth.registrar(
      usuario: usuario,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _cargando = false);

    if (result.requiereVerificacion) {
      await _mostrarDialogoVerificacion(result.emailPendiente!);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.mensaje ?? result.error ?? ''),
        backgroundColor: result.exito ? AppColors.limeDark : AppColors.danger,
      ),
    );

    if (result.exito) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
      );
    }
  }

  /// La cuenta se creó pero no queda sesión iniciada hasta confirmar el
  /// correo (ver AuthService.registrar) — se avisa y se vuelve al login en
  /// vez de entrar directo a la app.
  Future<void> _mostrarDialogoVerificacion(String email) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: const Icon(Icons.mark_email_read_outlined,
            color: AppColors.limeGreen, size: 36),
        title: const Text('Revisa tu correo',
            style: TextStyle(color: AppColors.white)),
        content: Text(
          'Te enviamos un link a $email para confirmar tu cuenta. '
          'Tócalo y después vuelve a iniciar sesión acá.',
          style: const TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido',
                style: TextStyle(color: AppColors.limeGreen)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DarkNeonScaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.transparent,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GlowLogo(size: 64, showWordmark: true),
                  const SizedBox(height: 28),
                  BudsoundTextField(
                    controller: _nombreController,
                    label: 'Nombre',
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.muted,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  BudsoundTextField(
                    controller: _apellidoController,
                    label: 'Apellido',
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(
                      Icons.badge_outlined,
                      color: AppColors.muted,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa tu apellido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // Fecha de nacimiento: el campo es de solo lectura y abre el picker.
                  BudsoundTextField(
                    controller: _fechaController,
                    label: 'Fecha de nacimiento',
                    readOnly: true,
                    onTap: _elegirFecha,
                    prefixIcon: const Icon(
                      Icons.cake_outlined,
                      color: AppColors.muted,
                    ),
                    validator: (_) => _fechaNacimiento == null
                        ? 'Selecciona tu fecha de nacimiento'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  BudsoundTextField(
                    controller: _emailController,
                    label: 'Correo',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.muted,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa tu correo';
                      }
                      if (!v.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  BudsoundTextField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    obscureText: _ocultarPassword,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.muted,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _ocultarPassword = !_ocultarPassword);
                      },
                      icon: Icon(
                        _ocultarPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.lavender,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Crea una contraseña';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Selector de Perfil',
                    style: TextStyle(
                      color: AppColors.lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RoleSegmentedControl(
                    value: _rol,
                    onChanged: (rol) => setState(() => _rol = rol),
                  ),
                  // Campo extra solo visible cuando el perfil es DJ.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: _rol == UserRole.dj
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: BudsoundTextField(
                              controller: _djController,
                              label: 'Nombre de DJ (Nombre Artístico)',
                              hint: 'Ej. DJ Neon',
                              prefixIcon: const Icon(
                                Icons.headphones_outlined,
                                color: AppColors.muted,
                              ),
                              validator: (v) {
                                if (_rol != UserRole.dj) return null;
                                if (v == null || v.trim().isEmpty) {
                                  return 'Ingresa tu nombre artístico';
                                }
                                return null;
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 28),
                  NeonGradientButton(
                    label: 'Ingresar cuenta',
                    loading: _cargando,
                    onPressed: _ingresarCuenta,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
