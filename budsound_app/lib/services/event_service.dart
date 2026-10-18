import '../models/event_model.dart';
import 'api_client.dart';

/// Eventos del DJ: creación con código para QR, listado y cierre.
class EventService {
  EventService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<EventModel> crear(
    String nombre, {
    required String horaInicio,
    required String horaFin,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<String> generos,
    String? imagenDataUrl,
  }) async {
    String aFechaIso(DateTime f) =>
        '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

    final data = await _api.post('/events', body: {
      'nombre': nombre,
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'fechaInicio': aFechaIso(fechaInicio),
      'fechaFin': aFechaIso(fechaFin),
      'generos': generos,
      if (imagenDataUrl != null) 'imagenDataUrl': imagenDataUrl,
    });
    return EventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  /// [quitarImagen] en true borra la imagen actual (manda
  /// `imagenDataUrl: null`); si es false y [imagenDataUrl] viene null, la
  /// imagen actual no se toca — mismo patrón que `AuthService.actualizarPerfil`
  /// con la foto de perfil.
  Future<EventModel> actualizarImagen(
    String id, {
    String? imagenDataUrl,
    bool quitarImagen = false,
  }) async {
    final data = await _api.patch('/events/$id/image', body: {
      'imagenDataUrl': quitarImagen ? null : imagenDataUrl,
    });
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

  /// Resumen de TODA la carrera del DJ (todos sus eventos), para la
  /// sección "Tus estadísticas" de Inicio — distinto de [resumen], que es
  /// de un solo evento.
  Future<Map<String, dynamic>> resumenGeneral() async {
    final data = await _api.get('/events/stats/mine');
    return data['resumen'] as Map<String, dynamic>;
  }
}
