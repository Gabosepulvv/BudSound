import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Activa una paleta alternativa (ver [AppColors]) para daltonismo rojo-verde
/// (protanopia/deuteranopia — el tipo más común, con mucha diferencia) en
/// vez de la paleta lima/rojo normal, que es justo la combinación más
/// difícil de distinguir para esas personas.
///
/// `ChangeNotifier` para que un solo toggle en Perfil reconstruya toda la
/// app (ver `main.dart`) y los colores —definidos como getters estáticos en
/// `AppColors`— se re-lean con el valor nuevo en cada widget.
class ColorblindModeService extends ChangeNotifier {
  ColorblindModeService._();
  static final ColorblindModeService instance = ColorblindModeService._();

  static const _kPrefKey = 'budsound.modoDaltonico';

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Carga la preferencia guardada. Llamar en [main] antes de [runApp], para
  /// que el primer frame ya salga con la paleta correcta (sin parpadeo).
  Future<void> cargarDesdeDisco() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kPrefKey) ?? false;
  }

  Future<void> establecer(bool valor) async {
    if (_enabled == valor) return;
    _enabled = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, valor);
  }
}
