import 'package:flutter/material.dart';

import '../services/colorblind_mode_service.dart';

/// Paleta oficial de Budsound.
/// El modo oscuro es el predeterminado de la app.
///
/// [limeGreen], [limeDark] y [danger] son getters (no `const`) porque
/// cambian según [ColorblindModeService.enabled] — ver "Modo daltónico" en
/// Perfil. El resto de la paleta no distingue estados por color (son solo
/// fondo/texto), así que se queda fija.
class AppColors {
  AppColors._();

  static bool get _daltonico => ColorblindModeService.instance.enabled;

  /// Verde lima principal (CTAs, glow, acentos, bordes activos). En modo
  /// daltónico se reemplaza por un azul vívido — para protanopia/
  /// deuteranopia (el daltonismo rojo-verde, el más común con diferencia)
  /// verde y rojo son justo los dos colores que más cuesta distinguir, pero
  /// el eje azul-amarillo se conserva casi intacto.
  static Color get limeGreen =>
      _daltonico ? const Color(0xFF3DA9FC) : const Color(0xFFB4FF39);

  /// Verde lima oscuro (degradados y estados secundarios) — lo bastante
  /// oscuro para que el texto blanco siga siendo legible encima. En modo
  /// daltónico, la versión oscura del azul de arriba.
  static Color get limeDark =>
      _daltonico ? const Color(0xFF1C5A8A) : const Color(0xFF3C7D1E);

  /// Texto/ícono oscuro para usar sobre [limeGreen] a opacidad plena, donde
  /// el blanco perdería contraste contra un verde (o azul) tan claro.
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

  /// Error de validación. En modo daltónico se reemplaza por un naranja
  /// vívido — se mantiene bien distinguible del azul de [limeGreen]
  /// cualquiera sea el tipo de daltonismo (rojo-verde o azul-amarillo).
  static Color get danger =>
      _daltonico ? const Color(0xFFFF8A1E) : const Color(0xFFFF5C7A);
}
