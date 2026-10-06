import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../models/google_perfil_pendiente.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/dark_neon_scaffold.dart';
import '../widgets/glow_logo.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/neon_gradient_button.dart';
import '../widgets/role_segmented_control.dart';

/// Inicio de sesión con correo/contraseña y Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();

  /// Controla el icono de ojo del campo contraseña.
  bool _ocultarPassword = true;
  bool _cargando = false;
  bool _cargandoGoogle = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);
    final result = await _auth.iniciarSesion(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _cargando = false);
    _trasAuth(result);
  }

  Future<void> _iniciarConGoogle() async {
    setState(() => _cargandoGoogle = true);
    final result = await _auth.iniciarSesionConGoogle();
    if (!mounted) return;
    setState(() => _cargandoGoogle = false);

    if (result.necesitaRolGoogle) {
      final eleccion = await _elegirRolGoogle(result.perfilGoogle!);
      if (eleccion == null || !mounted) return;

      setState(() => _cargandoGoogle = true);
      final resultFinal = await _auth.completarRegistroGoogle(
        idToken: result.idTokenGoogle!,
        role: eleccion.$1,
        nombreArtistico: eleccion.$2,
      );
      if (!mounted) return;
      setState(() => _cargandoGoogle = false);
      _trasAuth(resultFinal);
      return;
    }

    _trasAuth(result);
  }

  /// Google ya confirmó quién es la persona, pero no sabe si va a usar
  /// BudSound como Participante o como DJ — se pregunta acá antes de crear
  /// la cuenta. Devuelve (rol, nombreArtistico) o null si canceló.
  Future<(UserRole, String?)?> _elegirRolGoogle(GooglePerfilPendiente perfil) {
    var rol = UserRole.publico;
    final djController = TextEditingController();
    return showModalBottomSheet<(UserRole, String?)>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¡Hola, ${perfil.nombre}!',
                style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Antes de entrar, dinos cómo vas a usar BudSound.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              RoleSegmentedControl(
                value: rol,
                onChanged: (v) => setState(() => rol = v),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: rol == UserRole.dj
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: BudsoundTextField(
                          controller: djController,
                          label: 'Nombre de DJ (Nombre Artístico)',
                          hint: 'Ej. DJ Neon',
                          prefixIcon: const Icon(Icons.headphones_outlined,
                              color: AppColors.muted),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              NeonGradientButton(
                label: 'Continuar',
                onPressed: () {
                  if (rol == UserRole.dj &&
                      djController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ingresa tu nombre artístico.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    (rol, rol == UserRole.dj ? djController.text.trim() : null),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _trasAuth(AuthResult result) {
    _mostrarResultado(result.exito, result.mensaje ?? result.error);
    if (!result.exito) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
    );
  }

  void _mostrarResultado(bool ok, String? texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto ?? (ok ? 'Listo' : 'Error')),
        backgroundColor: ok ? AppColors.cobalt : AppColors.danger,
      ),
    );
  }

  void _olvidoPassword() {
    Navigator.of(context).pushNamed(AppRoutes.recover);
  }

  @override
  Widget build(BuildContext context) {
    return DarkNeonScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GlowLogo(size: 78, showWordmark: true),
                  const SizedBox(height: 8),
                  const Text(
                    'Entra a la escena',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 36),
                  BudsoundTextField(
                    controller: _emailController,
                    label: 'Correo Electrónico',
                    hint: 'tunombre@email.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.muted,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu correo electrónico';
                      }
                      if (!value.contains('@')) {
                        return 'Correo no válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  // Campo de contraseña con toggle de visibilidad (ojo).
                  BudsoundTextField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    hint: '••••••••',
                    obscureText: _ocultarPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.muted,
                    ),
                    suffixIcon: IconButton(
                      tooltip: _ocultarPassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _olvidoPassword,
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: AppColors.lavender),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  NeonGradientButton(
                    label: 'Iniciar Sesión',
                    loading: _cargando,
                    onPressed: _iniciarSesion,
                  ),
                  const SizedBox(height: 14),
                  GoogleSignInButton(
                    loading: _cargandoGoogle,
                    onPressed: _iniciarConGoogle,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿Aún no tienes cuenta? ',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.register);
                        },
                        child: const Text(
                          'Crear cuenta',
                          style: TextStyle(
                            color: AppColors.neonBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
