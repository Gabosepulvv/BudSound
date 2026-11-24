import 'api_client.dart';

/// Tarjeta guardada en MercadoPago (ver tarjetas.controller.js) — solo los
/// datos que MercadoPago expone de una tarjeta ajena: nunca el número
/// completo.
class TarjetaGuardada {
  const TarjetaGuardada({
    required this.id,
    required this.ultimosDigitos,
    required this.franquicia,
    required this.vencimiento,
  });

  final String id;
  final String? ultimosDigitos;
  final String? franquicia;
  final String vencimiento;

  factory TarjetaGuardada.fromJson(Map<String, dynamic> json) {
    return TarjetaGuardada(
      id: json['id'] as String,
      ultimosDigitos: json['ultimosDigitos'] as String?,
      franquicia: json['franquicia'] as String?,
      vencimiento: json['vencimiento'] as String? ?? '',
    );
  }
}

/// Lista/borra las tarjetas guardadas del Participante — se guardan solas
/// la primera vez que paga con tarjeta nueva (ver checkout.controller.js,
/// mp_checkout_screen.dart) para que la próxima propina solo pida el CVV.
class TarjetasService {
  TarjetasService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<TarjetaGuardada>> listar() async {
    final data = await _api.get('/auth/me/tarjetas');
    final lista = data['tarjetas'] as List? ?? const [];
    return lista
        .map((e) => TarjetaGuardada.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> borrar(String cardId) async {
    await _api.delete('/auth/me/tarjetas/$cardId');
  }
}
