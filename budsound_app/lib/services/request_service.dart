import '../models/itunes_track.dart';
import '../models/song_request_model.dart';
import '../models/transaction_model.dart';
import 'api_client.dart';

/// Solicitudes de canciones: crear, ver la cola, aceptar/rechazar y pagos.
class RequestService {
  RequestService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<SongRequestModel> crear({
    required String eventId,
    required ItunesTrack pista,
    required int montoClp,
  }) async {
    final data = await _api.post('/events/$eventId/requests', body: {
      'itunesTrackId': pista.trackId,
      'titulo': pista.trackName,
      'artista': pista.artistName,
      'artworkUrl': pista.artworkUrl,
      'montoClp': montoClp,
    });
    return SongRequestModel.fromJson(data['request'] as Map<String, dynamic>);
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

  Future<SongRequestModel> aceptar(String id) async {
    final data = await _api.patch('/requests/$id/accept');
    return SongRequestModel.fromJson(data['request'] as Map<String, dynamic>);
  }

  Future<SongRequestModel> rechazar(String id) async {
    final data = await _api.patch('/requests/$id/reject');
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
    final data = await _api.post('/requests/$requestId/payment/simulate-approval');
    return TransactionModel.fromJson(data['transaction'] as Map<String, dynamic>);
  }
}
