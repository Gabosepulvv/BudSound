import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Ubicación del backend de BudSound.
///
/// En desarrollo apunta a localhost (o 10.0.2.2 en el emulador Android,
/// que es como el emulador ve la máquina host). Cuando el backend esté
/// desplegado en Railway, reemplazar por esa URL fija.
class ApiConfig {
  ApiConfig._();

  static const String _hostDesarrollo = 'localhost';
  static const int _puerto = 3000;

  static String get baseUrl => 'http://$_host:$_puerto/api';

  static String get socketUrl => 'http://$_host:$_puerto';

  static String get _host {
    if (kIsWeb) return _hostDesarrollo;
    if (Platform.isAndroid) return '10.0.2.2';
    return _hostDesarrollo;
  }
}
