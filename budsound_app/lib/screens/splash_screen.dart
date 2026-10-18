import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/dark_neon_scaffold.dart';
import '../widgets/glow_logo.dart';

/// Pantalla de arranque: verifica un JWT simulado y decide la ruta.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Pulso suave del isotipo para el efecto glow.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    _verificarSesion();
  }

  /// Simula la lectura/validación del token y redirige.
  Future<void> _verificarSesion() async {
    // Simula I/O de almacenamiento seguro + validación JWT.
    final haySesion = await SessionService.instance.verificarTokenSesion();
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      haySesion ? AppRoutes.home : AppRoutes.login,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `Center` + `mainAxisSize: min` en vez de dos `Spacer` iguales
    // arriba/abajo del logo: con dos Spacer, el bloque de texto de abajo
    // (que no tiene ningún Spacer después) corre todo el contenido hacia
    // arriba — el logo terminaba centrado respecto al espacio ENTRE el
    // borde superior y el texto, no respecto a la pantalla completa. Así
    // sí queda centrado de verdad, como un solo bloque.
    return DarkNeonScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: const GlowLogo(size: 120),
            ),
            const SizedBox(height: 28),
            Text(
              'budsound',
              style: AppTheme.fontDisplay(
                color: AppColors.white,
                fontSize: 22,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Verificando sesión…',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
