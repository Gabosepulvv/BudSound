import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/budsound_mark.dart';
import '../widgets/dark_neon_scaffold.dart';

/// Pantalla de arranque: verifica si hay un JWT guardado y decide la ruta.
/// Las 6 barras del isotipo crecen escalonadas (~600ms) y recién cuando
/// terminan aparece el wordmark "BudSound" con un fade de 200ms — ver
/// `BudSoundMark.progresoEscalonado`.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _crecimiento = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController _wordmark = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _ajustadoPorMovimientoReducido = false;

  @override
  void initState() {
    super.initState();
    _crecimiento.addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _wordmark.forward();
    });
    _crecimiento.forward();
    _verificarSesion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "reducir movimiento" activo, se saltan directo al estado final
    // (barras completas + wordmark visible) en vez de animar.
    if (!_ajustadoPorMovimientoReducido && AppMotion.of(context).reducida) {
      _ajustadoPorMovimientoReducido = true;
      _crecimiento.value = 1;
      _wordmark.value = 1;
    }
  }

  /// Lee y valida el token guardado, y redirige según si hay sesión.
  Future<void> _verificarSesion() async {
    final haySesion = await SessionService.instance.verificarTokenSesion();
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      haySesion ? AppRoutes.home : AppRoutes.login,
    );
  }

  @override
  void dispose() {
    _crecimiento.dispose();
    _wordmark.dispose();
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
            AnimatedBuilder(
              animation: _crecimiento,
              builder: (context, _) => BudSoundMark(
                size: 120,
                progreso: BudSoundMark.progresoEscalonado(_crecimiento.value),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _wordmark,
              child: Text(
                'BudSound',
                style: AppTheme.wordmark(
                  color: AppColors.white,
                  fontSize: 22,
                ),
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
