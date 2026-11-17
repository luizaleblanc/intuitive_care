import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Exceção padronizada para erros HTTP/JSON retornados pela API Flask.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Cliente HTTP centralizado para comunicação exclusiva em JSON com a API Flask.
class ApiClient {
  final http.Client _httpClient;
  String? _authToken;
  VoidCallback? onUnauthorized;

  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('${ApiConfig.baseUrl}$normalizedPath');
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }
    final filtered = <String, String>{};
    queryParams.forEach((key, value) {
      if (value.isNotEmpty) {
        filtered[key] = value;
      }
    });
    return uri.replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _send(() => _httpClient.get(_buildUri(path, query), headers: _headers()));
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    return _send(
      () => _httpClient.post(
        _buildUri(path),
        headers: _headers(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    return _send(
      () => _httpClient.put(
        _buildUri(path),
        headers: _headers(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    return _send(
      () => _httpClient.patch(
        _buildUri(path),
        headers: _headers(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  /// GET que devolve o corpo como texto (ex.: exportação CSV gerada pela API).
  Future<String> getText(String path, {Map<String, String>? query}) async {
    final response = await _httpClient
        .get(_buildUri(path, query), headers: _headers())
        .timeout(const Duration(seconds: 60));
    if (response.statusCode == 401) onUnauthorized?.call();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(statusCode: response.statusCode, message: 'Erro HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) async {
    return _send(() => _httpClient.delete(_buildUri(path, query), headers: _headers()));
  }

  Future<dynamic> _send(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn().timeout(const Duration(seconds: 30));
      dynamic decoded;
      if (response.body.isNotEmpty) {
        try {
          decoded = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          decoded = {'erro': response.body};
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      final message = decoded is Map<String, dynamic>
          ? (decoded['erro'] ?? decoded['mensagem'] ?? 'Erro na requisição HTTP ${response.statusCode}')
              .toString()
          : 'Erro HTTP ${response.statusCode}';

      final details = decoded is Map<String, dynamic> && decoded['detalhes'] is Map<String, dynamic>
          ? decoded['detalhes'] as Map<String, dynamic>
          : null;

      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        details: details,
      );
    } on ApiException {
      rethrow;
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        message: 'Não foi possível conectar à API Flask. Verifique se o servidor está ativo.',
      );
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Falha de comunicação com o servidor: $e',
      );
    }
  }
}

typedef VoidCallback = void Function();
