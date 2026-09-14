import 'user_role.dart';

/// Representa a un usuario autenticado o en proceso de registro.
class UserModel {
  const UserModel({
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.fechaNacimiento,
    required this.rol,
    this.nombreArtistico,
  });

  final String nombre;
  final String apellido;
  final String email;
  final DateTime fechaNacimiento;
  final UserRole rol;

  /// Solo aplica cuando [rol] es [UserRole.dj].
  final String? nombreArtistico;

  /// Nombre completo para mostrar en UI.
  String get nombreCompleto => '$nombre $apellido'.trim();

  /// Nombre que se muestra en la sesión (artístico si es DJ).
  String get nombreVisible {
    if (rol == UserRole.dj &&
        nombreArtistico != null &&
        nombreArtistico!.trim().isNotEmpty) {
      return nombreArtistico!.trim();
    }
    return nombreCompleto.isEmpty ? email : nombreCompleto;
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'fechaNacimiento': fechaNacimiento.toIso8601String(),
        'rol': rol.name,
        'nombreArtistico': nombreArtistico,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fechaNacimiento: DateTime.tryParse(
            json['fechaNacimiento'] as String? ?? '',
          ) ??
          DateTime(2000, 1, 1),
      rol: UserRole.values.firstWhere(
        (r) => r.name == json['rol'],
        orElse: () => UserRole.publico,
      ),
      nombreArtistico: json['nombreArtistico'] as String?,
    );
  }
}
