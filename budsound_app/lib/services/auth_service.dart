import '../models/user_model.dart';
import '../models/user_role.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Resultado unificado de un intento de autenticación.
class AuthResult {
  const AuthResult.ok({this.mensaje}) : exito = true, error = null;

  const AuthResult.fail(this.error) : exito = false, mensaje = null;

  final bool exito;
  final String? mensaje;
  final String? error;
}

/// Autenticación real contra el backend de BudSound (JWT).
class AuthService {
  AuthService({SessionService? session, ApiClient? api})
      : _session = session ?? SessionService.instance,
        _api = api ?? ApiClient();

  final SessionService _session;
  final ApiClient _api;

  Future<AuthResult> iniciarSesion({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return const AuthResult.fail('Completa correo y contraseña.');
    }

    try {
      final data = await _api.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
        autenticado: false,
      );
      await _guardarSesionDesdeRespuesta(data);
      return const AuthResult.ok(mensaje: 'Sesión iniciada');
    } on ApiException catch (e) {
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }
  }

  /// El backend aún no expone OAuth con Google; se deja como aviso explícito
  /// en vez de simular un login que no existe de verdad.
  Future<AuthResult> iniciarSesionConGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const AuthResult.fail(
      'El inicio de sesión con Google todavía no está disponible.',
    );
  }

  Future<AuthResult> registrar({
    required UserModel usuario,
    required String password,
  }) async {
    if (usuario.nombre.trim().isEmpty || usuario.apellido.trim().isEmpty) {
      return const AuthResult.fail('Nombre y apellido son obligatorios.');
    }
    if (usuario.rol == UserRole.dj &&
        (usuario.nombreArtistico == null ||
            usuario.nombreArtistico!.trim().isEmpty)) {
      return const AuthResult.fail('El nombre de DJ es obligatorio.');
    }

    try {
      final data = await _api.post(
        '/auth/register',
        body: {
          'email': usuario.email.trim(),
          'password': password,
          'role': usuario.rol.backendValue,
          'nombre': usuario.nombre.trim(),
          'apellido': usuario.apellido.trim(),
          if (usuario.rol == UserRole.dj)
            'nombreArtistico': usuario.nombreArtistico!.trim(),
        },
        autenticado: false,
      );
      await _guardarSesionDesdeRespuesta(
        data,
        fechaNacimiento: usuario.fechaNacimiento,
      );
      return const AuthResult.ok(mensaje: 'Cuenta creada');
    } on ApiException catch (e) {
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }
  }

  /// El backend aún no expone recuperación de contraseña por correo.
  Future<AuthResult> solicitarRecuperacion(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!_emailValido(email)) {
      return const AuthResult.fail('El correo electrónico no es válido.');
    }
    return const AuthResult.fail(
      'La recuperación por correo todavía no está disponible.',
    );
  }

  Future<void> _guardarSesionDesdeRespuesta(
    Map<String, dynamic> data, {
    DateTime? fechaNacimiento,
  }) async {
    final token = data['token'] as String;
    final userJson = data['user'] as Map<String, dynamic>;
    final rol = UserRoleX.desdeBackend(userJson['role'] as String?);
    final correo = userJson['email'] as String? ?? '';

    final usuario = UserModel(
      id: userJson['id'] as String?,
      nombre: userJson['nombre'] as String? ?? '',
      apellido: userJson['apellido'] as String? ?? '',
      email: correo,
      fechaNacimiento: fechaNacimiento ??
          (_session.usuario?.email == correo
              ? _session.usuario!.fechaNacimiento
              : DateTime(2000, 1, 1)),
      rol: rol,
      nombreArtistico: userJson['nombreArtistico'] as String?,
    );

    await _session.guardarSesion(
      token: token,
      email: correo,
      rol: rol,
      nombreVisible: usuario.nombreVisible,
      usuario: usuario,
    );
  }

  bool _emailValido(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }
}
