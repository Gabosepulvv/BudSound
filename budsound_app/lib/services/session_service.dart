import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../models/user_role.dart';

/// Persiste y verifica el JWT de sesión en disco (web: localStorage).
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _kJwt = 'budsound.jwt';
  static const _kEmail = 'budsound.email';
  static const _kRol = 'budsound.rol';
  static const _kNombre = 'budsound.nombre';
  static const _kUsuario = 'budsound.usuario';

  SharedPreferences? _prefs;
  String? _jwt;
  String? _email;
  String? _nombreVisible;
  UserRole _rol = UserRole.publico;
  UserModel? _usuario;

  String? get jwt => _jwt;
  String? get email => _email;
  String? get nombreVisible => _nombreVisible;
  UserRole get rol => _rol;
  UserModel? get usuario => _usuario;

  bool get hasSession => _jwt != null && _jwt!.isNotEmpty;

  /// Carga claves persistidas. Llamar en [main] antes de [runApp].
  Future<void> cargarDesdeDisco() async {
    _prefs = await SharedPreferences.getInstance();
    _jwt = _prefs?.getString(_kJwt);
    _email = _prefs?.getString(_kEmail);
    _nombreVisible = _prefs?.getString(_kNombre);
    final rolName = _prefs?.getString(_kRol);
    _rol = UserRole.values.firstWhere(
      (r) => r.name == rolName,
      orElse: () => UserRole.publico,
    );
    final rawUser = _prefs?.getString(_kUsuario);
    if (rawUser != null && rawUser.isNotEmpty) {
      _usuario = UserModel.fromJson(
        jsonDecode(rawUser) as Map<String, dynamic>,
      );
    }
  }

  /// Lee el token persistido (con delay de splash) y confirma si hay sesión.
  Future<bool> verificarTokenSesion() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (_prefs == null) {
      await cargarDesdeDisco();
    }
    final token = _prefs?.getString(_kJwt);
    _jwt = token;
    return token != null && token.isNotEmpty;
  }

  Future<void> guardarToken(String token) async {
    await guardarSesion(token: token, email: _email ?? '');
  }

  /// Guarda JWT + perfil mínimo para restaurar la sesión al reabrir la app.
  Future<void> guardarSesion({
    required String token,
    required String email,
    UserRole rol = UserRole.publico,
    String? nombreVisible,
    UserModel? usuario,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    _jwt = token;
    _email = email;
    _rol = rol;
    _nombreVisible = nombreVisible ?? usuario?.nombreVisible ?? email;
    _usuario = usuario;

    await _prefs!.setString(_kJwt, token);
    await _prefs!.setString(_kEmail, email);
    await _prefs!.setString(_kRol, rol.name);
    await _prefs!.setString(_kNombre, _nombreVisible ?? email);
    if (usuario != null) {
      await _prefs!.setString(_kUsuario, jsonEncode(usuario.toJson()));
    }
  }

  Future<void> cerrarSesion() async {
    _prefs ??= await SharedPreferences.getInstance();
    _jwt = null;
    _email = null;
    _nombreVisible = null;
    _rol = UserRole.publico;
    _usuario = null;
    await _prefs!.remove(_kJwt);
    await _prefs!.remove(_kEmail);
    await _prefs!.remove(_kRol);
    await _prefs!.remove(_kNombre);
    await _prefs!.remove(_kUsuario);
  }
}
