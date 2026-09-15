import '../models/user_model.dart';
import '../models/user_role.dart';
import 'session_service.dart';

/// Resultado unificado de un intento de autenticación.
class AuthResult {
  const AuthResult.ok({this.mensaje}) : exito = true, error = null;

  const AuthResult.fail(this.error) : exito = false, mensaje = null;

  final bool exito;
  final String? mensaje;
  final String? error;
}

/// Autenticación simulada que persiste JWT en [SessionService].
class AuthService {
  AuthService({SessionService? session})
      : _session = session ?? SessionService.instance;

  final SessionService _session;

  Future<AuthResult> iniciarSesion({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (email.trim().isEmpty || password.isEmpty) {
      return const AuthResult.fail('Completa correo y contraseña.');
    }
    if (!_emailValido(email)) {
      return const AuthResult.fail('El correo electrónico no es válido.');
    }
    if (password.length < 6) {
      return const AuthResult.fail('La contraseña debe tener al menos 6 caracteres.');
    }

    final correo = email.trim();
    await _session.guardarSesion(
      token: _tokenSimulado(correo),
      email: correo,
      rol: _session.usuario?.email == correo
          ? _session.usuario!.rol
          : UserRole.publico,
      nombreVisible: _session.usuario?.email == correo
          ? _session.usuario!.nombreVisible
          : correo,
    );
    return const AuthResult.ok(mensaje: 'Sesión iniciada');
  }

  Future<AuthResult> iniciarSesionConGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    const correo = 'google-user@budsound.app';
    await _session.guardarSesion(
      token: _tokenSimulado(correo),
      email: correo,
      nombreVisible: 'Cuenta Google',
    );
    return const AuthResult.ok(mensaje: 'Sesión con Google iniciada (simulado)');
  }

  Future<AuthResult> registrar({
    required UserModel usuario,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (usuario.nombre.trim().isEmpty || usuario.apellido.trim().isEmpty) {
      return const AuthResult.fail('Nombre y apellido son obligatorios.');
    }
    if (!_emailValido(usuario.email)) {
      return const AuthResult.fail('El correo electrónico no es válido.');
    }
    if (password.length < 6) {
      return const AuthResult.fail('La contraseña debe tener al menos 6 caracteres.');
    }
    if (usuario.rol == UserRole.dj &&
        (usuario.nombreArtistico == null ||
            usuario.nombreArtistico!.trim().isEmpty)) {
      return const AuthResult.fail('El nombre de DJ es obligatorio.');
    }

    await _session.guardarSesion(
      token: _tokenSimulado(usuario.email),
      email: usuario.email,
      rol: usuario.rol,
      nombreVisible: usuario.nombreVisible,
      usuario: usuario,
    );
    return const AuthResult.ok(mensaje: 'Cuenta creada');
  }

  Future<AuthResult> solicitarRecuperacion(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!_emailValido(email)) {
      return const AuthResult.fail('El correo electrónico no es válido.');
    }
    return const AuthResult.ok(
      mensaje: 'Enlace de recuperación enviado (simulado).',
    );
  }

  bool _emailValido(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }

  String _tokenSimulado(String subject) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'jwt.$stamp.${subject.hashCode}';
  }
}
