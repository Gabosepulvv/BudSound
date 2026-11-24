import 'package:flutter/material.dart';

/// Tokens de movimiento de la ruta "Cabina minimal" — nada de rebote
/// (`elasticOut`/`easeOutBack`): el movimiento es preciso, como el equipo
/// de un DJ. Úsalos en vez de números sueltos en cada widget.
class AppMotion {
  const AppMotion._({
    required this.fast,
    required this.base,
    required this.medium,
    required this.slow,
    required this.count,
  });

  /// Toques (feedback táctil de botones/tarjetas presionables).
  final Duration fast;

  /// Cambios de estado puntuales (un ícono, un color, un chip).
  final Duration base;

  /// Transiciones de pantalla y aparición de tarjetas.
  final Duration medium;

  /// Entradas de lista escalonadas.
  final Duration slow;

  /// Contadores (recaudado, estadísticas).
  final Duration count;

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve state = Curves.easeInOut;
  static const Curve progress = Curves.linear;

  static const Duration _fast = Duration(milliseconds: 120);
  static const Duration _base = Duration(milliseconds: 200);
  static const Duration _medium = Duration(milliseconds: 280);
  static const Duration _slow = Duration(milliseconds: 420);
  static const Duration _count = Duration(milliseconds: 600);

  static const AppMotion _normal = AppMotion._(
    fast: _fast,
    base: _base,
    medium: _medium,
    slow: _slow,
    count: _count,
  );

  static const AppMotion _reducida = AppMotion._(
    fast: Duration.zero,
    base: Duration.zero,
    medium: Duration.zero,
    slow: Duration.zero,
    count: Duration.zero,
  );

  /// Si el sistema tiene "reducir movimiento" activo
  /// (`MediaQuery.disableAnimations`), todas las duraciones quedan en cero
  /// — los loops (punto "en vivo", placeholders de carga) deben leer esto
  /// también para dejar de repetirse, no solo las transiciones puntuales.
  static AppMotion of(BuildContext context) {
    final reducida = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reducida ? _reducida : _normal;
  }

  bool get reducida => fast == Duration.zero;

  /// Escalonado para entradas de lista: 40ms por ítem, tope de 8 ítems
  /// escalonados — del 9° en adelante todos entran juntos con el mismo
  /// delay que el 8°, en vez de hacer esperar a los últimos de una lista
  /// larga.
  Duration escalonado(int indice) {
    if (reducida) return Duration.zero;
    return Duration(milliseconds: 40 * indice.clamp(0, 8));
  }
}
