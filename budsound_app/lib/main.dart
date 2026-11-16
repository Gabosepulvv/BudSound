import 'package:flutter/material.dart';

import 'core/app_routes.dart';
import 'screens/login_screen.dart';
import 'screens/recover_password_screen.dart';
import 'screens/register_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'services/colorblind_mode_service.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Por defecto, si una pantalla falla al dibujarse, Flutter muestra un
  // cuadro gris sin ningún mensaje en el APK instalado (release) — así no
  // hay forma de saber qué falló sin conectar el celular al computador.
  // Esto muestra el error en texto, en cualquier modo, para poder
  // reportarlo con una simple captura de pantalla.
  ErrorWidget.builder = (details) => _ErrorVisible(details);
  // Restaura JWT y perfil antes de decidir splash → login/home.
  await SessionService.instance.cargarDesdeDisco();
  // Restaura si el modo daltónico estaba activo, antes del primer frame
  // (ver app_colors.dart) para que no haya un parpadeo de la paleta normal.
  await ColorblindModeService.instance.cargarDesdeDisco();
  runApp(const BudsoundApp());
}

class BudsoundApp extends StatelessWidget {
  const BudsoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AppColors.limeGreen/limeDark/danger dependen de
    // ColorblindModeService.enabled — este ListenableBuilder reconstruye
    // toda la app (tema incluido) cuando cambia, para que la paleta nueva
    // se vea de inmediato en cada pantalla.
    return ListenableBuilder(
      listenable: ColorblindModeService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'budsound',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.register: (_) => const RegisterScreen(),
            AppRoutes.recover: (_) => const RecoverPasswordScreen(),
            AppRoutes.home: (_) => const ShellScreen(),
          },
        );
      },
    );
  }
}

/// Reemplaza el cuadro gris/rojo por defecto de Flutter cuando un widget
/// falla al construirse — ver `ErrorWidget.builder` en [main].
class _ErrorVisible extends StatelessWidget {
  const _ErrorVisible(this.details);

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final pila = details.stack?.toString().split('\n').take(6).join('\n');
    return Material(
      color: const Color(0xFF17151F),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            'Ocurrió un error al mostrar esta pantalla.\n'
            'Sácale una captura y envíasela al equipo.\n\n'
            '${details.exceptionAsString()}\n\n${pila ?? ''}',
            style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
          ),
        ),
      ),
    );
  }
}
