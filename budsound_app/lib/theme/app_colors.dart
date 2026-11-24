import 'package:flutter/material.dart';

import '../services/colorblind_mode_service.dart';

/// Paleta oficial de BudSound — ruta "Cabina minimal" (2026-11-24): negro
/// mate, acento azul y ámbar reservado para "en vivo"/dinero. Plana, sin
/// degradados ni glow por defecto en tarjetas/botones.
///
/// [limeGreen]/[limeDark]/[success]/[danger] siguen siendo getters (en vez
/// de `const`) por el enganche con [ColorblindModeService.enabled] — ver
/// DECISIONES_TECNICAS.md, "colores como getters, no const". Con la paleta
/// nueva, azul y ámbar ya se distinguen bien en protanopia, deuteranopia y
/// tritanopia, así que ambas ramas devuelven el mismo valor: el modo
/// daltónico queda como propuesta de eliminación (ver DECISIONES_TECNICAS.md)
/// en vez de borrarse de una, para no decidirlo unilateralmente.
class AppColors {
  AppColors._();

  static bool get _daltonico => ColorblindModeService.instance.enabled;

  /// Acento principal (botones, selección, progreso, CTA de ambos roles).
  /// Nombre histórico [limeGreen] — pasó de lima a violeta a rosa y ahora a
  /// azul sin que el nombre cambiara nunca, para no tocar los ~50 usos que
  /// ya lo referencian como "el color de acento" (ver DECISIONES_TECNICAS.md
  /// — el rename a nombres semánticos, ej. `accent`, queda como paso
  /// aparte con refactor del IDE).
  static Color get limeGreen =>
      _daltonico ? const Color(0xFF3D8BFF) : const Color(0xFF3D8BFF);

  /// Acento presionado/fondos sólidos con texto encima.
  static Color get limeDark =>
      _daltonico ? const Color(0xFF3378E6) : const Color(0xFF3378E6);

  /// Texto/ícono sobre [limeGreen]/[limeDark] a opacidad plena. Ahora OSCURO
  /// (antes blanco) — el azul de la paleta nueva es claro, así que el
  /// contraste correcto es con el fondo casi negro, no con blanco.
  static const Color onLime = Color(0xFF0B0C0E);

  /// Links y texto en azul sobre fondo oscuro (nunca como fondo de botón:
  /// para eso está [limeGreen]).
  static const Color accentText = Color(0xFF5B9CFF);

  /// Texto secundario/hints.
  static const Color lavender = Color(0xFFB4B9C2);

  /// Texto principal/títulos.
  static const Color white = Color(0xFFF2F3F5);

  /// Fondo de pantalla — negro mate (sin tinte de color ni glow).
  static const Color background = Color(0xFF0B0C0E);

  /// Superficie plana de tarjetas, inputs y barra inferior.
  static const Color surface = Color(0xFF17191D);

  /// Superficie "alta" — botones secundarios (Rechazar, chips −/+), un
  /// escalón más clara que [surface] para distinguirse de una tarjeta.
  static const Color surfaceHigh = Color(0xFF23262B);

  /// Borde sutil — solo en inputs y pistas de progreso (las tarjetas no
  /// llevan borde).
  static const Color border = Color(0xFF2A2D33);

  /// Texto atenuado (terciario, etiquetas).
  static const Color muted = Color(0xFF9BA1AB);

  /// Error de validación / solicitud por vencer.
  static Color get danger =>
      _daltonico ? const Color(0xFFFF5C5C) : const Color(0xFFFF5C5C);

  /// Ámbar — reservado para "en vivo", "aceptada" y dinero (propinas,
  /// recaudado). Nombre histórico [success] (ver nota de [limeGreen]).
  static Color get success =>
      _daltonico ? const Color(0xFFFFB020) : const Color(0xFFFFB020);

  /// Texto/ícono sobre [success] a opacidad plena.
  static const Color onSuccess = Color(0xFF0B0C0E);
}
