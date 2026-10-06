import '../models/itunes_track.dart';
import 'api_client.dart';

/// Búsqueda de canciones a través del backend (proxy de iTunes Search API).
///
/// Solo se usa para metadatos (título, artista, portada) — la app nunca
/// reproduce un preview de la canción, solo la búsqueda para armar la
/// solicitud (ver CLAUDE.md, "Decisión legal").
class SongService {
  SongService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<ItunesTrack>> buscar(String termino) async {
    final limpio = termino.trim();
    if (limpio.isEmpty) return [];

    final data = await _api.get('/songs/search', query: {'q': limpio});
    return _mapear(data);
  }

  /// Canciones populares (top chart) para mostrar algo apenas se abre la
  /// búsqueda, en vez de una pantalla vacía hasta que la persona escriba.
  Future<List<ItunesTrack>> top() async {
    final data = await _api.get('/songs/top');
    return _mapear(data);
  }

  List<ItunesTrack> _mapear(Map<String, dynamic> data) {
    final resultados =
        (data['resultados'] as List).cast<Map<String, dynamic>>();

    return resultados
        .map(
          (r) => ItunesTrack(
            trackId: (r['itunesTrackId'] as num).toInt(),
            trackName: r['titulo'] as String? ?? 'Sin título',
            artistName: r['artista'] as String? ?? 'Artista desconocido',
            collectionName: '',
            artworkUrl: r['artworkUrl'] as String? ?? '',
            genre: '',
            previewUrl: r['previewUrl'] as String?,
          ),
        )
        .toList();
  }
}
