import '../models/song_request_model.dart';
import '../models/transaction_model.dart';
import 'api_client.dart';

/// Solicitudes de canciones: crear, ver la cola, aceptar/rechazar y pagos.
class RequestService {
  RequestService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Recibe los campos de la pista directamente (en vez de un [ItunesTrack])
  /// para poder reintentar una solicitud guardada en [PendingRequestsStore]
  /// sin reconstruir un objeto de pista falso.
  ///
  /// [terminosAceptados] es obligatorio cuando [montoClp] > 0 — el backend
  /// rechaza la propina si no viene en true (ver CLAUDE.md, riesgo "El
  /// participante pide la devolución del dinero").
  ///
  /// [cardToken]/[paymentMethodId]/[installments] vienen del Card Payment
  /// Brick de MercadoPago (tokenizado en el WebView de
  /// `McpCheckoutScreen`); [tokenCheckout], cuando viene, autentica con el
  /// token acotado de 15 minutos en vez del JWT de sesión completo — ver
  /// `McpCheckoutScreen._onMensajeDePagina` y CLAUDE.md, revisión de
  /// seguridad.
  Future<SongRequestModel> crear({
    required String eventId,
    required int itunesTrackId,
    required String titulo,
    required String artista,
    required String artworkUrl,
    required int montoClp,
    bool terminosAceptados = false,
    String? cardToken,
    String? paymentMethodId,
    int? installments,
    String? tokenCheckout,
  }) async {
    final data = await _api.post(
      '/events/$eventId/requests',
      tokenPropio: tokenCheckout,
      body: {
        'itunesTrackId': itunesTrackId,
        'titulo': titulo,
        'artista': artista,
        'artworkUrl': artworkUrl,
        'montoClp': montoClp,
        'terminosAceptados': terminosAceptados,
        if (cardToken != null) 'cardToken': cardToken,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (installments != null) 'installments': installments,
      },
    );
    return SongRequestModel.fromJson(data['request'] as Map<String, dynamic>);
  }

  /// Token de corta duración (15 min, válido solo para este evento) que usa
  /// el WebView de pago en vez del JWT de sesión completo — ver
  /// `McpCheckoutScreen` y CLAUDE.md, revisión de seguridad.
  Future<String> obtenerTokenCheckout(String eventId) async {
    final data = await _api.post('/events/$eventId/checkout-token');
    return data['checkoutToken'] as String;
  }

  Future<List<SongRequestModel>> listarPorEvento(
    String eventId, {
    String? status,
  }) async {
    final data = await _api.get(
      '/events/$eventId/requests',
      query: status != null ? {'status': status} : null,
    );
    return (data['requests'] as List)
        .cast<Map<String, dynamic>>()
        .map(SongRequestModel.fromJson)
        .toList();
  }

  /// Las solicitudes que el propio Participante hizo en ese evento.
  Future<List<SongRequestModel>> misSolicitudes(String eventId) async {
    final data = await _api.get('/events/$eventId/requests/mine');
    return (data['requests'] as List)
        .cast<Map<String, dynamic>>()
        .map(SongRequestModel.fromJson)
        .toList();
  }

  /// Historial completo del Participante a través de TODOS sus eventos —
  /// ver Perfil → "Historial de propinas". A diferencia de [misSolicitudes],
  /// no está acotado a un evento puntual.
  Future<List<SongRequestModel>> misSolicitudesGlobal() async {
    final data = await _api.get('/requests/mine');
    return (data['requests'] as List)
        .cast<Map<String, dynamic>>()
        .map(SongRequestModel.fromJson)
        .toList();
  }

  Future<SongRequestModel> aceptar(String id) async {
    final data = await _api.patch('/requests/$id/accept');
    return SongRequestModel.fromJson(data['request'] as Map<String, dynamic>);
  }

  Future<SongRequestModel> rechazar(String id) async {
    final data = await _api.patch('/requests/$id/reject');
    return SongRequestModel.fromJson(data['request'] as Map<String, dynamic>);
  }

  /// Evidencia con timestamp de que la canción sonó — ver CLAUDE.md, riesgo
  /// "Contracargo".
  Future<SongRequestModel> marcarReproducida(String id) async {
    final data = await _api.patch('/requests/$id/played');
    return SongRequestModel.fromJson(data['request'] as Map<String, dynamic>);
  }

  /// Estado de la transacción de una solicitud propia (null si no tiene propina).
  Future<TransactionModel?> estadoPago(String requestId) async {
    final data = await _api.get('/requests/$requestId/payment');
    final transaction = data['transaction'] as Map<String, dynamic>?;
    return transaction != null ? TransactionModel.fromJson(transaction) : null;
  }

  /// Solo funciona mientras el backend no tenga credenciales reales de
  /// MercadoPago (ver mercadopago.service.js) — demuestra el flujo completo.
  Future<TransactionModel> simularAprobacionDePago(String requestId) async {
    final data =
        await _api.post('/requests/$requestId/payment/simulate-approval');
    return TransactionModel.fromJson(
        data['transaction'] as Map<String, dynamic>);
  }
}
