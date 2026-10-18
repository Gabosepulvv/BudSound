import 'package:flutter/material.dart';

import '../services/colorblind_mode_service.dart';

/// Paleta oficial de Budsound — rosa/magenta neón sobre fondo casi negro,
/// plana (sin degradados ni glow por defecto en tarjetas/botones).
///
/// [limeGreen] y [danger] son getters porque cambian según
/// [ColorblindModeService.enabled] — ver DECISIONES_TECNICAS.md, "colores
/// como getters, no const".
class AppColors {
  AppColors._();

  static bool get _daltonico => ColorblindModeService.instance.enabled;

  /// Acento principal (botones, íconos activos, estados "en vivo"/"activo").
  /// Los nombres [limeGreen]/[limeDark]/[onLime] quedaron de la paleta
  /// original (verde lima) — se mantienen para no tener que tocar los
  /// ~50 lugares que ya los usan como "el color de acento", aunque pasó de
  /// lima a violeta y ahora a rosa/magenta neón sin que el nombre haya
  /// cambiado nunca. En modo daltónico se reemplaza por un azul saturado —
  /// un rosa/rojo fuerte queda demasiado cerca del eje rojo-verde que
  /// complica la paleta anterior (protanopia/deuteranopia), el azul no
  /// tiene ese problema.
  static Color get limeGreen =>
      _daltonico ? const Color(0xFF3DA9FC) : const Color(0xFFFF2D95);

  /// Variante oscura del acento — fondos de botón sólido (con texto blanco
  /// encima) y estados presionados/secundarios.
  static Color get limeDark =>
      _daltonico ? const Color(0xFF1C5A8A) : const Color(0xFFB8185E);

  /// Texto/ícono sobre [limeGreen]/[limeDark] a opacidad plena.
  static const Color onLime = Color(0xFFFFFFFF);

  /// Lavanda — texto secundario/hints.
  static const Color lavender = Color(0xFFE6E4F2);

  /// Texto principal/títulos.
  static const Color white = Color(0xFFFFFFFF);

  /// Fondo de pantalla — casi negro con tinte violeta.
  static const Color background = Color(0xFF0B0A10);

  /// Superficie plana de tarjetas e inputs — más clara que [background]
  /// para que las tarjetas "floten" sobre el fondo tintado.
  static const Color surface = Color(0xFF17151F);

  /// Borde sutil — hoy casi solo en inputs; las tarjetas ya no llevan
  /// borde por defecto (ver DECISIONES_TECNICAS.md, rediseño de UI).
  static const Color border = Color(0xFF242230);

  /// Texto atenuado (terciario).
  static const Color muted = Color(0xFF9D9BAE);

  /// Error de validación. En modo daltónico se reemplaza por un naranja
  /// vívido — se mantiene bien distinguible del azul de [limeGreen]
  /// cualquiera sea el tipo de daltonismo (rojo-verde o azul-amarillo). No
  /// cambia entre claro/oscuro, mismo motivo que [limeGreen].
  static Color get danger =>
      _daltonico ? const Color(0xFFFF8A1E) : const Color(0xFFFF6B6B);

  /// Verde — reservado para el estado "aprobada/aceptada" de una
  /// solicitud (tickets de la cola del DJ y del historial del
  /// Participante) y nada más. Con el acento de marca ahora violeta
  /// ([limeGreen]), hacía falta un color separado para esta señal
  /// semántica puntual que no debe compartir color con botones o acentos
  /// genéricos — es el mismo verde que tenía el acento de marca antes del
  /// rediseño (ver DECISIONES_TECNICAS.md). En modo daltónico se
  /// reemplaza por un amarillo dorado: el verde es justo el color que el
  /// modo daltónico existe para evitar, y un amarillo se mantiene bien
  /// distinguible tanto del azul de [limeGreen] como del naranja de
  /// [danger] en protanopia/deuteranopia.
  static Color get success =>
      _daltonico ? const Color(0xFFF2C94C) : const Color(0xFFB4FF39);

  /// Texto/ícono sobre [success] a opacidad plena.
  static const Color onSuccess = Color(0xFF0B1403);

  /// Glow rosa/magenta de las pantallas de acceso (ver `DarkNeonScaffold`)
  /// — separado de [limeGreen] porque es puramente decorativo (una sola
  /// mancha fija en una esquina, no un color de estado) y así puede quedar
  /// fijo sin importar el modo daltónico.
  static const Color glow = Color(0xFFC2186E);
}
