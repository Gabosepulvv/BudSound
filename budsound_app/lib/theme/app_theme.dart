import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Transición propia (fade + deslizamiento sutil hacia arriba) para que
/// cambiar de pantalla se sienta más vivo que el slide plano por defecto —
/// se aplica igual en todas las plataformas para que la sensación sea
/// consistente sin importar dónde corra la app.
class _FadeThroughTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curva =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curva),
        child: child,
      ),
    );
  }
}

/// Tema Material 3 de Budsound — oscuro, único (sin modo claro).
///
/// Tipografía de dos voces, no una sola fuente de sistema repetida en todo
/// tamaño (lo que hacía que la app se sintiera "plantilla"): [fontDisplay]
/// (Unbounded, geométrica y con carácter — pensada para carteles de
/// festival/flyer, no para párrafos) en nombres de evento, títulos y
/// números grandes; el resto del texto usa Inter, que es más neutra y se
/// lee mejor en párrafos largos.
class AppTheme {
  AppTheme._();

  /// Fuente de títulos/branding/números destacados — úsala explícitamente
  /// con `AppTheme.fontDisplay(...)` en vez de `TextStyle` directo en
  /// cualquier texto que sea un nombre de evento, un título de pantalla, el
  /// logo "budsound", o una cifra grande (temporizador, recaudación). El
  /// resto del texto (cuerpo, hints, botones) se queda con Inter vía
  /// `textTheme` — no hace falta tocarlo widget por widget.
  static TextStyle fontDisplay({
    required Color color,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.unbounded(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
      );

  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.limeGreen,
      secondary: AppColors.limeDark,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: AppColors.onLime,
      onSecondary: AppColors.onLime,
      onSurface: AppColors.white,
      onError: AppColors.onLime,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme:
          GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme)
              .copyWith(
        headlineMedium: fontDisplay(
          color: AppColors.white,
          fontSize: 24,
          letterSpacing: 0.2,
        ),
        bodyLarge: GoogleFonts.inter(color: AppColors.lavender),
        bodyMedium: GoogleFonts.inter(color: AppColors.muted),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionsBuilder(),
          TargetPlatform.iOS: _FadeThroughTransitionsBuilder(),
          TargetPlatform.macOS: _FadeThroughTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionsBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.limeGreen.withValues(alpha: 0.28),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.lavender),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.limeGreen, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
    );
  }
}
