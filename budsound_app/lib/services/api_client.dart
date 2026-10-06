import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import 'session_service.dart';

/// Error de la API con el mensaje que ya viene traducido del backend.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente HTTP delgado hacia el backend de BudSound: agrega el JWT,
/// serializa JSON y traduce errores a [ApiException].
class ApiClient {
  ApiClient({http.Client? client, SessionService? session})
      : _client = client ?? http.Client(),
        _session = session ?? SessionService.instance;

  final http.Client _client;
  final SessionService _session;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool autenticado = true,
  }) async {
    final response = await _client.get(
      _uri(path, query),
      headers: _headers(autenticado: autenticado),
    );
    return _procesar(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool autenticado = true,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(autenticado: autenticado),
      body: body != null ? jsonEncode(body) : null,
    );
    return _procesar(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool autenticado = true,
  }) async {
    final response = await _client.patch(
      _uri(path),
      headers: _headers(autenticado: autenticado),
      body: body != null ? jsonEncode(body) : null,
    );
    return _procesar(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool autenticado = true,
  }) async {
    final response = await _client.delete(
      _uri(path),
      headers: _headers(autenticado: autenticado),
    );
    return _procesar(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  Map<String, String> _headers({required bool autenticado}) {
    final headers = {'Content-Type': 'application/json'};
    final token = _session.jwt;
    if (autenticado && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _procesar(http.Response response) {
    Map<String, dynamic> data = const {};
    if (response.bodyBytes.isNotEmpty) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw ApiException(
      data['error'] as String? ?? 'Error de servidor (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}
