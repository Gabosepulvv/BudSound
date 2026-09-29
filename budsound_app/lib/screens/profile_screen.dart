import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../models/user_role.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glow_logo.dart';
import '../widgets/neon_gradient_button.dart';

/// Perfil de sesión y cierre de cuenta.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await SessionService.instance.cerrarSesion();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
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
                const GlowLogo(size: 72),
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
          if (usuario != null) ...[
            _fila('Nombre', usuario.nombreCompleto),
            if (esDj && usuario.nombreArtistico != null)
              _fila('Nombre artístico', usuario.nombreArtistico!),
          ],
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
