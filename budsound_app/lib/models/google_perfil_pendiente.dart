/// Datos que Google ya confirmó (nombre, apellido, correo) cuando alguien
/// inicia sesión con una cuenta que todavía no existe en BudSound. Falta
/// completar el rol (Participante/DJ) antes de poder crear la cuenta —
/// Google no sabe eso.
class GooglePerfilPendiente {
  const GooglePerfilPendiente({
    required this.email,
    required this.nombre,
    required this.apellido,
    this.avatarDataUrl,
  });

  final String email;
  final String nombre;
  final String apellido;
  final String? avatarDataUrl;

  factory GooglePerfilPendiente.fromJson(Map<String, dynamic> json) {
    return GooglePerfilPendiente(
      email: json['email'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      avatarDataUrl: json['avatarDataUrl'] as String?,
    );
  }
}
