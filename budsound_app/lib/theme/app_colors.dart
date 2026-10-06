import 'package:flutter/material.dart';

/// Paleta oficial de Budsound.
/// El modo oscuro es el predeterminado de la app.
class AppColors {
  AppColors._();

  /// Verde lima principal (CTAs, glow, acentos, bordes activos).
  static const Color limeGreen = Color(0xFFB4FF39);

  /// Verde lima oscuro (degradados y estados secundarios) — lo bastante
  /// oscuro para que el texto blanco siga siendo legible encima.
  static const Color limeDark = Color(0xFF3C7D1E);

  /// Texto/ícono oscuro para usar sobre [limeGreen] a opacidad plena, donde
  /// el blanco perdería contraste contra un verde tan claro.
  static const Color onLime = Color(0xFF0B1403);

  /// Lavanda claro (textos secundarios y hints).
  static const Color lavender = Color(0xFFF0F4FF);

  /// Blanco puro (títulos y texto principal).
  static const Color white = Color(0xFFFFFFFF);

  /// Fondo azul marino casi negro para contraste cinematográfico.
  static const Color background = Color(0xFF070B14);

  /// Superficie de tarjetas e inputs.
  static const Color surface = Color(0xFF0D1626);

  /// Borde sutil de campos en reposo.
  static const Color border = Color(0xFF1E2C44);

  /// Texto atenuado sobre fondos oscuros.
  static const Color muted = Color(0xFF93A2BE);

  /// Error de validación.
  static const Color danger = Color(0xFFFF5C7A);
}
