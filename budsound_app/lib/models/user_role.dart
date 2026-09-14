/// Perfiles disponibles al crear una cuenta.
enum UserRole {
  /// Usuario oyente / público general.
  publico,

  /// Artista DJ con nombre artístico.
  dj,
}

extension UserRoleX on UserRole {
  /// Etiqueta visible en el selector de perfil.
  String get label {
    switch (this) {
      case UserRole.publico:
        return 'Público';
      case UserRole.dj:
        return 'DJ';
    }
  }
}
