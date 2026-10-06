/// Pista musical proveniente de la Search API de iTunes / Apple Music.
///
/// Documentación: https://performance-partners.apple.com/search-api
class ItunesTrack {
  const ItunesTrack({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    required this.collectionName,
    required this.artworkUrl,
    required this.genre,
    this.previewUrl,
    this.trackViewUrl,
    this.artistId,
    this.collectionId,
    this.durationMs,
  });

  final int trackId;
  final String trackName;
  final String artistName;
  final String collectionName;
  final String artworkUrl;
  final String genre;
  final String? previewUrl;
  final String? trackViewUrl;
  final int? artistId;
  final int? collectionId;
  final int? durationMs;

  /// Portada a mayor resolución (truco documentado sobre artworkUrl100).
  String get artworkGrande => artworkUrl.replaceAll('100x100bb', '400x400bb');

  factory ItunesTrack.fromJson(Map<String, dynamic> json) {
    return ItunesTrack(
      trackId: json['trackId'] as int? ?? 0,
      trackName: json['trackName'] as String? ?? 'Sin título',
      artistName: json['artistName'] as String? ?? 'Artista desconocido',
      collectionName: json['collectionName'] as String? ?? '',
      artworkUrl: json['artworkUrl100'] as String? ??
          json['artworkUrl60'] as String? ??
          '',
      genre: json['primaryGenreName'] as String? ?? '',
      previewUrl: json['previewUrl'] as String?,
      trackViewUrl: json['trackViewUrl'] as String?,
      artistId: json['artistId'] as int?,
      collectionId: json['collectionId'] as int?,
      durationMs: json['trackTimeMillis'] as int?,
    );
  }
}
