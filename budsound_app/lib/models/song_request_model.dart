/// Solicitud de canción hecha por un Participante dentro de un evento.
/// [montoClp] es una propina/incentivo opcional al DJ, nunca una garantía
/// de reproducción.
class SongRequestModel {
  const SongRequestModel({
    required this.id,
    required this.eventId,
    required this.participanteId,
    required this.itunesTrackId,
    required this.titulo,
    required this.artista,
    required this.montoClp,
    required this.status,
    required this.createdAt,
    this.artworkUrl,
    this.resolvedAt,
    this.reproducidaAt,
    this.participanteNombre,
    this.participanteApellido,
  });

  final String id;
  final String eventId;
  final String participanteId;
  final int itunesTrackId;
  final String titulo;
  final String artista;
  final String? artworkUrl;
  final int montoClp;
  final String status; // 'PENDIENTE' | 'ACEPTADA' | 'RECHAZADA' | 'CANCELADA'
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? reproducidaAt;
  final String? participanteNombre;
  final String? participanteApellido;

  bool get tienePropina => montoClp > 0;
  bool get pendiente => status == 'PENDIENTE';
  bool get aceptada => status == 'ACEPTADA';
  bool get rechazada => status == 'RECHAZADA';
  bool get reproducida => reproducidaAt != null;

  /// El sistema la canceló sola (evento cerrado o venció el plazo sin
  /// respuesta del DJ) — distinto de [rechazada], que es una decisión
  /// activa del DJ. Ver CLAUDE.md, riesgo "Autorización de pago vs. captura".
  bool get cancelada => status == 'CANCELADA';

  String get participanteNombreCompleto {
    final nombre = [participanteNombre, participanteApellido]
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .join(' ');
    return nombre.isEmpty ? 'Participante' : nombre;
  }

  factory SongRequestModel.fromJson(Map<String, dynamic> json) {
    return SongRequestModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      participanteId: json['participante_id'] as String,
      itunesTrackId: int.parse(json['itunes_track_id'].toString()),
      titulo: json['titulo'] as String,
      artista: json['artista'] as String,
      artworkUrl: json['artwork_url'] as String?,
      montoClp: (json['monto_clp'] as num).toInt(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      reproducidaAt: json['reproducida_at'] != null
          ? DateTime.parse(json['reproducida_at'] as String)
          : null,
      participanteNombre: json['participante_nombre'] as String?,
      participanteApellido: json['participante_apellido'] as String?,
    );
  }
}
