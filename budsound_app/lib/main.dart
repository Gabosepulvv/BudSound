import 'package:flutter/material.dart';

import 'core/app_routes.dart';
import 'screens/login_screen.dart';
import 'screens/recover_password_screen.dart';
import 'screens/register_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restaura JWT y perfil antes de decidir splash → login/home.
  await SessionService.instance.cargarDesdeDisco();
  runApp(const BudsoundApp());
}

class BudsoundApp extends StatelessWidget {
  const BudsoundApp({super.key});

  @override
  Widget build(BuildContext context) {
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
  }
}
