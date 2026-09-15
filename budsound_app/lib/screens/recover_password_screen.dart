import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/dark_neon_scaffold.dart';
import '../widgets/glow_logo.dart';
import '../widgets/neon_gradient_button.dart';

/// Recuperación de contraseña (simulada hasta conectar el backend).
class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _auth = AuthService();
  bool _cargando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    final result = await _auth.solicitarRecuperacion(_emailController.text);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _enviado = result.exito;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.mensaje ?? result.error ?? ''),
        backgroundColor: result.exito ? AppColors.cobalt : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DarkNeonScaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        backgroundColor: Colors.transparent,
      ),
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
                  const GlowLogo(size: 64, showWordmark: true),
                  const SizedBox(height: 16),
                  Text(
                    _enviado
                        ? 'Si el correo existe, te enviaremos un enlace (flujo simulado).'
                        : 'Escribe el correo de tu cuenta y te guiaremos para restablecer el acceso.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 28),
                  BudsoundTextField(
                    controller: _emailController,
                    label: 'Correo Electrónico',
                    hint: 'tunombre@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.muted,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu correo electrónico';
                      }
                      if (!value.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  NeonGradientButton(
                    label: _enviado ? 'Reenviar enlace' : 'Enviar enlace',
                    loading: _cargando,
                    onPressed: _enviar,
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
