/// Sesión de DJ en vivo (catálogo local hasta conectar el backend).
class LiveSession {
  const LiveSession({
    required this.id,
    required this.djName,
    required this.titulo,
    required this.ciudad,
    required this.genero,
    required this.oyentes,
    required this.enVivo,
    this.venue,
  });

  final String id;
  final String djName;
  final String titulo;
  final String ciudad;
  final String genero;
  final int oyentes;
  final bool enVivo;
  final String? venue;
}
