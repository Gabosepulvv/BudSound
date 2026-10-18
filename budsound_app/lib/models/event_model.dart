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
    this.horaInicio,
    this.horaFin,
    this.fechaInicio,
    this.fechaFin,
    this.generos = const [],
    this.imagenDataUrl,
    this.djNombreArtistico,
    this.djAvatarDataUrl,
  });

  final String id;
  final String djId;
  final String code;
  final String nombre;
  final String status; // 'ACTIVO' | 'CERRADO'
  final DateTime createdAt;
  final DateTime? closedAt;
  // "HH:MM:SS" tal como lo devuelve Postgres (columna TIME) — informativas,
  // no cierran el evento solas al llegar la hora (ver schema.sql).
  final String? horaInicio;
  final String? horaFin;
  // Fecha(s) real(es) del evento (no cuándo se creó el registro) — el DJ
  // las declara al crear el evento, para poder saber meses después qué
  // día fue tal evento al revisar su historial (ver schema.sql). Null en
  // eventos creados antes de que existiera este campo.
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  // Géneros que el DJ declaró al crear el evento — ver GENEROS_VALIDOS en
  // event.controller.js.
  final List<String> generos;
  // Imagen opcional del evento (data URL) — ver event.controller.js,
  // `actualizarImagen`. Null si el DJ nunca le puso una.
  final String? imagenDataUrl;
  // Nombre artístico y foto del DJ dueño del evento — vienen con un JOIN
  // desde el backend (ver event.model.js, `SELECT_CON_DJ`) solo en
  // `buscarPorCodigo`/`buscarPorId`, para la tarjeta de "evento actual" del
  // Participante en Inicio. Null en los eventos que vienen de `misEventos`
  // /`crear`/`cerrar` (el propio DJ no necesita ver su nombre ahí).
  final String? djNombreArtistico;
  final String? djAvatarDataUrl;

  bool get activo => status == 'ACTIVO';

  /// "HH:MM" para mostrar en pantalla, o null si falta alguna de las dos.
  String? get horarioVisible {
    if (horaInicio == null || horaFin == null) return null;
    return '${horaInicio!.substring(0, 5)} - ${horaFin!.substring(0, 5)}';
  }

  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// Fecha real del evento para mostrar en pantalla — un solo día ("15 oct
  /// 2026") si `fechaInicio`/`fechaFin` son iguales, o un rango ("15–17
  /// oct 2026", "28 oct – 2 nov 2026") si no. Cae de vuelta a `createdAt`
  /// (o `closedAt` si ya cerró) para eventos creados antes de que
  /// existiera este campo — nunca deja el historial sin ninguna fecha.
  String get fechaVisible {
    final inicio = fechaInicio ?? closedAt ?? createdAt;
    final fin = fechaFin ?? fechaInicio ?? closedAt ?? createdAt;

    if (inicio.year == fin.year &&
        inicio.month == fin.month &&
        inicio.day == fin.day) {
      return '${inicio.day} ${_meses[inicio.month - 1]} ${inicio.year}';
    }
    if (inicio.year == fin.year && inicio.month == fin.month) {
      return '${inicio.day}–${fin.day} ${_meses[inicio.month - 1]} ${inicio.year}';
    }
    final mismoAno = inicio.year == fin.year;
    final finTexto = '${fin.day} ${_meses[fin.month - 1]} ${fin.year}';
    return '${inicio.day} ${_meses[inicio.month - 1]}'
        '${mismoAno ? '' : ' ${inicio.year}'} – $finTexto';
  }

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
      horaInicio: json['hora_inicio'] as String?,
      horaFin: json['hora_fin'] as String?,
      fechaInicio: json['fecha_inicio'] != null
          ? DateTime.parse(json['fecha_inicio'] as String)
          : null,
      fechaFin: json['fecha_fin'] != null
          ? DateTime.parse(json['fecha_fin'] as String)
          : null,
      generos: (json['generos'] as List?)?.cast<String>() ?? const [],
      imagenDataUrl: json['imagen_data_url'] as String?,
      djNombreArtistico: json['dj_nombre_artistico'] as String?,
      djAvatarDataUrl: json['dj_avatar_data_url'] as String?,
    );
  }
}
