import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_song_request.dart';

/// Cola local (en disco, sobrevive a cerrar la app) de solicitudes que no se
/// pudieron enviar por un corte de conexión en el evento. Una lista por
/// evento, para no mezclar colas de distintos eventos en el mismo celular.
class PendingRequestsStore {
  PendingRequestsStore._();
  static final PendingRequestsStore instance = PendingRequestsStore._();

  static const _kPrefix = 'budsound.pendingRequests.';

  Future<List<PendingSongRequest>> todas(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_kPrefix$eventId') ?? const [];
    return raw
        .map((e) =>
            PendingSongRequest.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> agregar(PendingSongRequest solicitud) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPrefix${solicitud.eventId}';
    final actuales = prefs.getStringList(key) ?? const [];
    await prefs.setStringList(key, [
      ...actuales,
      jsonEncode(solicitud.toJson()),
    ]);
  }

  Future<void> eliminar(String eventId, String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPrefix$eventId';
    final actuales = prefs.getStringList(key) ?? const [];
    actuales.removeWhere(
      (e) => (jsonDecode(e) as Map<String, dynamic>)['localId'] == localId,
    );
    await prefs.setStringList(key, actuales);
  }
}
