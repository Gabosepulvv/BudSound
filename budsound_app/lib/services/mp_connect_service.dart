import 'api_client.dart';

/// Estado de la conexión del DJ con su propia cuenta de MercadoPago (OAuth
/// marketplace) — ver CLAUDE.md, "¿A quién le llega la plata primero?".
class MpConexionEstado {
  const MpConexionEstado({
    required this.conectado,
    this.collectorId,
    this.nickname,
    this.email,
  });

  final bool conectado;
  final int? collectorId;
  // Nickname/correo de la cuenta conectada — se muestran en Perfil para
  // que el DJ pueda verificar que es la cuenta correcta, en vez de solo
  // ver un ID numérico sin significado.
  final String? nickname;
  final String? email;

  factory MpConexionEstado.fromJson(Map<String, dynamic> json) {
    // `collectorId` llega como String desde el backend — Postgres
    // serializa las columnas `bigint` así (ver DECISIONES_TECNICAS.md,
    // el mismo motivo por el que `resumenGeneralPorDj` usa strings).
    final collectorIdRaw = json['collectorId'];
    return MpConexionEstado(
      conectado: json['conectado'] as bool? ?? false,
      collectorId: collectorIdRaw is String
          ? int.tryParse(collectorIdRaw)
          : collectorIdRaw as int?,
      nickname: json['nickname'] as String?,
      email: json['email'] as String?,
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
