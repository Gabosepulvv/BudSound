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

/// Tema Material 3 de BudSound — oscuro, único (sin modo claro), ruta
/// "Cabina minimal" (ver DECISIONES_TECNICAS.md): una sola familia
/// tipográfica, Geist, en vez de la dupla Unbounded/Inter de antes.
/// [title] es la voz de títulos/branding (texto); [numeric] es la voz de
/// cifras (Geist Mono, con figuras tabulares para que los montos no
/// "salten" de ancho al cambiar). El resto del texto usa Geist normal vía
/// `textTheme`.
class AppTheme {
  AppTheme._();

  /// Título de pantalla, nombre de evento, título de tarjeta, etc. — texto,
  /// nunca cifras (para eso está [numeric]).
  static TextStyle title({
    required Color color,
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.geist(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Cifras destacadas: montos, tiempos, BPM, código de evento. Siempre con
  /// figuras tabulares (ancho fijo por dígito) para que un contador o un
  /// monto que cambia no desplace el resto del layout.
  static TextStyle numeric({
    required Color color,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.geistMono(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Wordmark "BudSound" (B y S mayúsculas) — Geist w600, tracking cerrado
  /// (-0.04em). Úsalo solo para el logotipo, nunca para títulos normales.
  static TextStyle wordmark({required Color color, double fontSize = 24}) =>
      GoogleFonts.geist(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: fontSize * -0.04,
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

    final base = GoogleFonts.geistTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.copyWith(
        // Título de pantalla / nombre de evento.
        headlineMedium: title(
          color: AppColors.white,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.96,
          height: 1.1,
        ),
        // Cuerpo.
        bodyLarge: GoogleFonts.geist(
          color: AppColors.lavender,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.geist(
          color: AppColors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        // Etiqueta — minúscula normal, sin tracking positivo ni mayúsculas
        // forzadas (antes se usaban `letterSpacing` positivo y
        // `toUpperCase()` en varias pantallas).
        labelSmall: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ).merge(GoogleFonts.geist()),
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
