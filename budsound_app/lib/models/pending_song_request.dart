/// Solicitud de canción que no se pudo enviar al backend por un corte de
/// conexión y queda guardada en el celular para reintentarse sola (ver
/// CLAUDE.md, riesgo "Congestión de red y desconexión en el evento").
class PendingSongRequest {
  const PendingSongRequest({
    required this.localId,
    required this.eventId,
    required this.itunesTrackId,
    required this.titulo,
    required this.artista,
    required this.artworkUrl,
    required this.montoClp,
    required this.terminosAceptados,
  });

  final String localId;
  final String eventId;
  final int itunesTrackId;
  final String titulo;
  final String artista;
  final String artworkUrl;
  final int montoClp;
  final bool terminosAceptados;

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'eventId': eventId,
        'itunesTrackId': itunesTrackId,
        'titulo': titulo,
        'artista': artista,
        'artworkUrl': artworkUrl,
        'montoClp': montoClp,
        'terminosAceptados': terminosAceptados,
      };

  factory PendingSongRequest.fromJson(Map<String, dynamic> json) {
    return PendingSongRequest(
      localId: json['localId'] as String,
      eventId: json['eventId'] as String,
      itunesTrackId: json['itunesTrackId'] as int,
      titulo: json['titulo'] as String,
      artista: json['artista'] as String,
      artworkUrl: json['artworkUrl'] as String? ?? '',
      montoClp: json['montoClp'] as int? ?? 0,
      terminosAceptados: json['terminosAceptados'] as bool? ?? false,
    );
  }
}
