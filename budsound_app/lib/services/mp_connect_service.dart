import 'api_client.dart';

/// Estado de la conexión del DJ con su propia cuenta de MercadoPago (OAuth
/// marketplace) — ver CLAUDE.md, "¿A quién le llega la plata primero?".
class MpConexionEstado {
  const MpConexionEstado({required this.conectado, this.collectorId});

  final bool conectado;
  final int? collectorId;

  factory MpConexionEstado.fromJson(Map<String, dynamic> json) {
    return MpConexionEstado(
      conectado: json['conectado'] as bool? ?? false,
      collectorId: json['collectorId'] as int?,
    );
  }
}

/// Conecta/desconecta la cuenta de MercadoPago del DJ. El login y la
/// autorización ocurren en el navegador del sistema (nunca en un WebView
/// propio) — no se le pide la contraseña de MercadoPago a una pantalla que
/// controla BudSound, ver DECISIONES_TECNICAS.md.
class MpConnectService {
  MpConnectService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<MpConexionEstado> estado() async {
    final data = await _api.get('/dj/mercadopago/status');
    return MpConexionEstado.fromJson(data);
  }

  /// Devuelve la URL que hay que abrir en el navegador del sistema para
  /// iniciar la conexión.
  Future<String> iniciarConexion() async {
    final data = await _api.get('/dj/mercadopago/connect');
    return data['authUrl'] as String;
  }

  Future<void> desconectar() async {
    await _api.delete('/dj/mercadopago/connection');
  }
}
