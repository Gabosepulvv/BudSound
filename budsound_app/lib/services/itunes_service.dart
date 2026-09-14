import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/itunes_track.dart';

/// Cliente de la Search API pública de iTunes (no requiere API key).
///
/// Endpoints:
/// - Búsqueda: `https://itunes.apple.com/search`
/// - Lookup por ID: `https://itunes.apple.com/lookup`
///
/// Referencia: https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/
class ItunesService {
  ItunesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Búsqueda de canciones para el catálogo (Descubrir, sets, perfil).
  Future<List<ItunesTrack>> buscarCanciones(
    String termino, {
    int limite = 25,
    String pais = 'MX',
  }) async {
    final limpio = termino.trim();
    if (limpio.isEmpty) return [];

    final data = await _get('/search', {
      'term': limpio,
      'media': 'music',
      'entity': 'song',
      'limit': '$limite',
      'country': pais,
    });
    return _mapearPistas(data);
  }

  /// Álbumes (útil para fichas de artista / DJ).
  Future<List<Map<String, dynamic>>> buscarAlbumes(
    String termino, {
    int limite = 12,
    String pais = 'MX',
  }) async {
    final data = await _get('/search', {
      'term': termino.trim(),
      'media': 'music',
      'entity': 'album',
      'limit': '$limite',
      'country': pais,
    });
    return _resultados(data);
  }

  /// Artistas (útil para búsqueda de DJs en el catálogo de Apple).
  Future<List<Map<String, dynamic>>> buscarArtistas(
    String termino, {
    int limite = 12,
    String pais = 'MX',
  }) async {
    final data = await _get('/search', {
      'term': termino.trim(),
      'media': 'music',
      'entity': 'musicArtist',
      'limit': '$limite',
      'country': pais,
    });
    return _resultados(data);
  }

  /// Canciones de un álbum o artista por ID de iTunes.
  Future<List<ItunesTrack>> lookupCanciones(int itunesId) async {
    final data = await _get('/lookup', {
      'id': '$itunesId',
      'entity': 'song',
    });
    return _mapearPistas(data)
        .where((t) => t.trackId != itunesId || t.trackName.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.https('itunes.apple.com', path, query);
    final response = await _descargar(uri);

    if (response.statusCode != 200) {
      throw Exception('iTunes respondió ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> _descargar(Uri itunes) async {
    const headers = {'Accept': 'application/json'};
    if (!kIsWeb) {
      return _client.get(itunes, headers: headers);
    }

    // Chrome bloquea itunes.apple.com por CORS; se intenta proxy público.
    final proxies = [
      Uri.parse(
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(itunes.toString())}',
      ),
      Uri.parse(
        'https://corsproxy.io/?${Uri.encodeComponent(itunes.toString())}',
      ),
    ];
    http.Response? ultimo;
    for (final proxy in proxies) {
      try {
        ultimo = await _client.get(proxy, headers: headers);
        if (ultimo.statusCode == 200) return ultimo;
      } catch (_) {
        continue;
      }
    }
    if (ultimo != null) return ultimo;
    return _client.get(itunes, headers: headers);
  }

  List<Map<String, dynamic>> _resultados(Map<String, dynamic> data) {
    final raw = data['results'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  List<ItunesTrack> _mapearPistas(Map<String, dynamic> data) {
    return _resultados(data)
        .where((r) => r['wrapperType'] == 'track' || r['kind'] == 'song')
        .map(ItunesTrack.fromJson)
        .where((t) => t.trackId != 0)
        .toList();
  }
}
