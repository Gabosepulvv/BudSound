import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Ubicación del backend de BudSound.
///
/// En desarrollo apunta a localhost (o 10.0.2.2 en el emulador Android, que
/// es como el emulador ve la máquina host). [_usarProduccion] cambia todo a
/// la URL fija de Railway de una sola vez — ver "Guía de despliegue a
/// Railway" en CLAUDE.md para cuándo y cómo activarlo.
class ApiConfig {
  ApiConfig._();

  /// Cambiar a `true` (y completar [_hostProduccion]) antes de compilar un
  /// build para repartir a gente fuera de la red local del equipo.
  static const bool _usarProduccion = true;

  /// Dominio que asigna Railway al desplegar, SIN `https://` ni `/` al
  /// final — ej. `budsound-backend-production.up.railway.app`.
  static const String _hostProduccion = 'budsound-production.up.railway.app';

  static const String _hostDesarrollo = 'localhost';
  static const int _puerto = 3000;

  /// IP de la red local del equipo (ej. `192.168.1.50`) para probar en un
  /// celular/tablet físico conectado a la misma WiFi — `10.0.2.2` de abajo
  /// SOLO funciona dentro del emulador de Android, un dispositivo real no
  /// lo resuelve. Se pasa por `--dart-define=API_HOST=...` al compilar;
  /// sin este define, el emulador sigue funcionando igual que siempre.
  static const String _hostLan = String.fromEnvironment('API_HOST');

  static String get baseUrl => '$_esquema://$_host$_sufijoPuerto/api';

  static String get socketUrl => '$_esquema://$_host$_sufijoPuerto';

  /// Página HTML (no JSON) que arma el formulario de tarjeta de MercadoPago
  /// para pagar una propina — se abre en un WebView, nunca en la API.
  static String get checkoutUrl => '$socketUrl/pay/checkout';

  static String get _esquema => _usarProduccion ? 'https' : 'http';

  /// Railway expone el backend en el puerto 443 (https) por detrás de su
  /// proxy, nunca en `_puerto` — solo en desarrollo local hace falta
  /// indicarlo en la URL.
  static String get _sufijoPuerto => _usarProduccion ? '' : ':$_puerto';

  static String get _host {
    if (_usarProduccion) return _hostProduccion;
    if (_hostLan.isNotEmpty) return _hostLan;
    if (kIsWeb) return _hostDesarrollo;
    if (Platform.isAndroid) return '10.0.2.2';
    return _hostDesarrollo;
  }
}
