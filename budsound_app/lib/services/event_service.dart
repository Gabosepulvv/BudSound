import '../models/event_model.dart';
import 'api_client.dart';

/// Eventos del DJ: creación con código para QR, listado y cierre.
class EventService {
  EventService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<EventModel> crear(String nombre) async {
    final data = await _api.post('/events', body: {'nombre': nombre});
    return EventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  Future<List<EventModel>> misEventos() async {
    final data = await _api.get('/events/mine');
    return (data['events'] as List)
        .cast<Map<String, dynamic>>()
        .map(EventModel.fromJson)
        .toList();
  }

  /// Resuelve el código que el Participante escaneó o escribió.
  Future<EventModel> buscarPorCodigo(String code) async {
    final data = await _api.get('/events/code/${code.trim().toUpperCase()}');
    return EventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  Future<EventModel> cerrar(String id) async {
    final data = await _api.patch('/events/$id/close');
    return EventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> resumen(String id) async {
    final data = await _api.get('/events/$id/summary');
    return data['resumen'] as Map<String, dynamic>;
  }
}
