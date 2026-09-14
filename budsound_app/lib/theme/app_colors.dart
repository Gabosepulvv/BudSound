import 'package:flutter/material.dart';

/// Paleta oficial de Budsound.
/// El modo oscuro es el predeterminado de la app.
class AppColors {
  AppColors._();

  /// Azul neón principal (CTAs, glow, acentos).
  static const Color neonBlue = Color(0xFF2B58F0);

  /// Azul cobalto (degradados y estados secundarios).
  static const Color cobalt = Color(0xFF1E40AF);

  /// Lavanda claro (textos secundarios y hints).
  static const Color lavender = Color(0xFFF0F4FF);

  /// Blanco puro (títulos y texto principal).
  static const Color white = Color(0xFFFFFFFF);

  /// Fondo casi negro para contraste cinematográfico.
  static const Color background = Color(0xFF05070F);

  /// Superficie de tarjetas e inputs.
  static const Color surface = Color(0xFF0C1224);

  /// Borde sutil de campos en reposo.
  static const Color border = Color(0xFF1A2748);

  /// Texto atenuado sobre fondos oscuros.
  static const Color muted = Color(0xFF9AA8C7);

  /// Error de validación.
  static const Color danger = Color(0xFFFF5C7A);
}
