import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budsound/screens/login_screen.dart';
import 'package:budsound/theme/app_theme.dart';

void main() {
  testWidgets('El login muestra el CTA y el acceso con Google', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const LoginScreen(),
      ),
    );

    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Iniciar sesión con Google'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
