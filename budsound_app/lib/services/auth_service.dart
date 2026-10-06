import 'package:google_sign_in/google_sign_in.dart';

import '../core/google_auth_config.dart';
import '../models/google_perfil_pendiente.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Resultado unificado de un intento de autenticación. [necesitaRolGoogle]
/// es el único caso especial: Google confirmó la identidad, pero la cuenta
/// todavía no existe en BudSound y hace falta elegir rol (Participante/DJ)
/// antes de poder crearla — ver [AuthService.completarRegistroGoogle].
class AuthResult {
  const AuthResult.ok({this.mensaje})
      : exito = true,
        error = null,
        necesitaRolGoogle = false,
        perfilGoogle = null,
        idTokenGoogle = null;

  const AuthResult.fail(this.error)
      : exito = false,
        mensaje = null,
        necesitaRolGoogle = false,
        perfilGoogle = null,
        idTokenGoogle = null;

  const AuthResult.necesitaRolGoogle({
    required this.perfilGoogle,
    required this.idTokenGoogle,
  })  : exito = false,
        mensaje = null,
        error = null,
        necesitaRolGoogle = true;

  final bool exito;
  final String? mensaje;
  final String? error;
  final bool necesitaRolGoogle;
  final GooglePerfilPendiente? perfilGoogle;
  final String? idTokenGoogle;
}

/// Autenticación real contra el backend de BudSound (JWT).
class AuthService {
  AuthService({SessionService? session, ApiClient? api})
      : _session = session ?? SessionService.instance,
        _api = api ?? ApiClient();

  final SessionService _session;
  final ApiClient _api;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: GoogleAuthConfig.serverClientId.isEmpty
        ? null
        : GoogleAuthConfig.serverClientId,
  );

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

  /// Primer paso del login con Google: abre el selector de cuenta nativo,
  /// consigue un idToken y lo manda al backend sin `role`. Si la cuenta ya
  /// existe, vuelve logueado (igual que [iniciarSesion]). Si es nueva,
  /// vuelve con [AuthResult.necesitaRolGoogle] — hay que llamar a
  /// [completarRegistroGoogle] con el rol elegido para terminar.
  Future<AuthResult> iniciarSesionConGoogle() async {
    if (!GoogleAuthConfig.configurado) {
      return const AuthResult.fail(
        'El inicio de sesión con Google todavía no está configurado en esta app.',
      );
    }

    try {
      final cuenta = await _googleSignIn.signIn();
      if (cuenta == null) {
        return const AuthResult.fail('Inicio de sesión cancelado.');
      }
      final auth = await cuenta.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        return const AuthResult.fail('Google no entregó un token válido.');
      }

      final data = await _api.post(
        '/auth/google',
        body: {'idToken': idToken},
        autenticado: false,
      );

      if (data['nuevo'] == true) {
        return AuthResult.necesitaRolGoogle(
          idTokenGoogle: idToken,
          perfilGoogle: GooglePerfilPendiente.fromJson(
            data['perfil'] as Map<String, dynamic>,
          ),
        );
      }

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

  /// Segundo paso: reenvía el mismo idToken ya verificado una vez, más el
  /// rol que la persona eligió en el selector que muestra la pantalla de
  /// login. Recién acá el backend crea la cuenta.
  Future<AuthResult> completarRegistroGoogle({
    required String idToken,
    required UserRole role,
    String? nombreArtistico,
  }) async {
    try {
      final data = await _api.post(
        '/auth/google',
        body: {
          'idToken': idToken,
          'role': role.backendValue,
          if (role == UserRole.dj) 'nombreArtistico': nombreArtistico?.trim(),
        },
        autenticado: false,
      );
      await _guardarSesionDesdeRespuesta(data);
      return const AuthResult.ok(mensaje: 'Cuenta creada');
    } on ApiException catch (e) {
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }
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
      avatarDataUrl: userJson['avatarDataUrl'] as String?,
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

  /// Edita nombre/apellido y/o la foto de perfil. [quitarFoto] en true
  /// borra la foto actual (manda `avatarDataUrl: null` al backend); si es
  /// false y [avatarDataUrl] viene null, la foto actual no se toca.
  Future<AuthResult> actualizarPerfil({
    String? nombre,
    String? apellido,
    String? avatarDataUrl,
    bool quitarFoto = false,
  }) async {
    final body = <String, dynamic>{};
    if (nombre != null) body['nombre'] = nombre.trim();
    if (apellido != null) body['apellido'] = apellido.trim();
    if (quitarFoto) {
      body['avatarDataUrl'] = null;
    } else if (avatarDataUrl != null) {
      body['avatarDataUrl'] = avatarDataUrl;
    }

    if (body.isEmpty) return const AuthResult.ok();

    try {
      final data = await _api.patch('/auth/me', body: body);
      final userJson = data['user'] as Map<String, dynamic>;
      final actual = _session.usuario;

      final actualizado = UserModel(
        id: userJson['id'] as String?,
        nombre: userJson['nombre'] as String? ?? actual?.nombre ?? '',
        apellido: userJson['apellido'] as String? ?? actual?.apellido ?? '',
        email: userJson['email'] as String? ?? actual?.email ?? '',
        fechaNacimiento: actual?.fechaNacimiento ?? DateTime(2000, 1, 1),
        rol: UserRoleX.desdeBackend(userJson['role'] as String?),
        nombreArtistico: userJson['nombreArtistico'] as String?,
        avatarDataUrl: userJson['avatarDataUrl'] as String?,
      );

      await _session.actualizarUsuario(actualizado);
      return const AuthResult.ok(mensaje: 'Perfil actualizado');
    } on ApiException catch (e) {
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }
  }
}
