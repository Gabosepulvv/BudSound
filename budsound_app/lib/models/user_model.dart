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
    this.nombreArtisticoCambiadoAt,
    this.id,
    this.avatarDataUrl,
  });

  /// Id real asignado por el backend (null mientras solo existe en el form).
  final String? id;
  final String nombre;
  final String apellido;
  final String email;
  final DateTime fechaNacimiento;
  final UserRole rol;

  /// Solo aplica cuando [rol] es [UserRole.dj].
  final String? nombreArtistico;

  /// Último cambio de [nombreArtistico] — el backend lo exige para aplicar
  /// el cooldown de 30 días entre cambios (ver CLAUDE.md /
  /// auth.controller.js). Null si nunca lo cambió desde que se registró.
  final DateTime? nombreArtisticoCambiadoAt;

  /// Data URL (`data:image/...;base64,...`) de la foto de perfil, o null.
  final String? avatarDataUrl;

  /// [clearAvatar] en true fuerza [avatarDataUrl] a null (quitar la foto);
  /// de lo contrario, un [avatarDataUrl] null significa "no lo cambies".
  UserModel copyWith({
    String? nombre,
    String? apellido,
    String? avatarDataUrl,
    bool clearAvatar = false,
  }) {
    return UserModel(
      id: id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      email: email,
      fechaNacimiento: fechaNacimiento,
      rol: rol,
      nombreArtistico: nombreArtistico,
      avatarDataUrl: clearAvatar ? null : (avatarDataUrl ?? this.avatarDataUrl),
    );
  }

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
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'fechaNacimiento': fechaNacimiento.toIso8601String(),
        'rol': rol.name,
        'nombreArtistico': nombreArtistico,
        'nombreArtisticoCambiadoAt':
            nombreArtisticoCambiadoAt?.toIso8601String(),
        'avatarDataUrl': avatarDataUrl,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String?,
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
      nombreArtisticoCambiadoAt: DateTime.tryParse(
          json['nombreArtisticoCambiadoAt'] as String? ?? ''),
      avatarDataUrl: json['avatarDataUrl'] as String?,
    );
  }
}
