/// Evento en vivo creado por un DJ. [code] es lo que se codifica en el QR.
class EventModel {
  const EventModel({
    required this.id,
    required this.djId,
    required this.code,
    required this.nombre,
    required this.status,
    required this.createdAt,
    this.closedAt,
  });

  final String id;
  final String djId;
  final String code;
  final String nombre;
  final String status; // 'ACTIVO' | 'CERRADO'
  final DateTime createdAt;
  final DateTime? closedAt;

  bool get activo => status == 'ACTIVO';

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      djId: json['dj_id'] as String,
      code: json['code'] as String,
      nombre: json['nombre'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
    );
  }
}
