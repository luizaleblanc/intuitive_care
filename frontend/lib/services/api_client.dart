import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

export 'package:flutter/foundation.dart' show VoidCallback;
export 'api_exception.dart';

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

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _send(
      () => _httpClient.post(
        _buildUri(path),
        headers: _headers(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      timeout: timeout,
    );
  }

  /// POST que devolve arquivo binário (ex.: planilha XLSX ou CSV gerada pela API).
  Future<({Uint8List bytes, String? filename})> postBytes(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final http.Response response;
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': '*/*',
        if (_authToken != null && _authToken!.isNotEmpty) 'Authorization': 'Bearer $_authToken',
      };
      response = await _httpClient
          .post(
            _buildUri(path),
            headers: headers,
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const ApiException(statusCode: 0, message: mensagemTempoEsgotado);
    } catch (e) {
      debugPrint('[ApiClient] Falha de rede (postBytes): $e');
      throw const ApiException(statusCode: 0, message: mensagemSemConexao);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (
        bytes: response.bodyBytes,
        filename: extrairNomeArquivo(response.headers['content-disposition']),
      );
    }

    _throwHttpError(response, _decodeJsonOrNull(response.bodyBytes));
  }

  /// Extrai o nome de arquivo do cabeçalho HTTP `Content-Disposition`.
  static String? extrairNomeArquivo(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.isEmpty) return null;
    final utf8Match = RegExp(r"filename\*=UTF-8''([^;\r\n]+)", caseSensitive: false).firstMatch(contentDisposition);
    if (utf8Match != null) {
      try {
        return Uri.decodeComponent(utf8Match.group(1)!.trim());
      } catch (_) {}
    }
    final quoted = RegExp(r'filename="([^"]+)"', caseSensitive: false).firstMatch(contentDisposition);
    if (quoted != null) return quoted.group(1)!.trim();
    final plain = RegExp(r'filename=([^;\r\n]+)', caseSensitive: false).firstMatch(contentDisposition);
    return plain?.group(1)?.trim();
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
      throw ApiException(statusCode: response.statusCode, message: mensagemPorStatus(response.statusCode));
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) async {
    return _send(() => _httpClient.delete(_buildUri(path, query), headers: _headers()));
  }

  Future<dynamic> _send(
    Future<http.Response> Function() requestFn, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final http.Response response;
    try {
      response = await requestFn().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(statusCode: 0, message: mensagemTempoEsgotado);
    } catch (e) {
      debugPrint('[ApiClient] Falha de rede: $e');
      throw const ApiException(statusCode: 0, message: mensagemSemConexao);
    }

    final decoded = _decodeJsonOrNull(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded == null && response.bodyBytes.isNotEmpty) {
        debugPrint('[ApiClient] Resposta sem JSON de ${response.request?.url}');
        throw const ApiException(statusCode: 0, message: mensagemServidorIndisponivel);
      }
      return decoded;
    }

    _throwHttpError(response, decoded);
  }

  dynamic _decodeJsonOrNull(Uint8List bodyBytes) {
    if (bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bodyBytes));
    } catch (_) {
      return null; // Resposta que não é JSON (ex.: página HTML de erro).
    }
  }

  Never _throwHttpError(http.Response response, dynamic decoded) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    // Mensagens da própria API já são escritas para o usuário; o resto vira texto amigável.
    final mensagemApi = decoded is Map<String, dynamic> ? (decoded['erro'] ?? decoded['mensagem']) : null;
    if (mensagemApi == null) {
      debugPrint('[ApiClient] HTTP ${response.statusCode} sem mensagem da API em ${response.request?.url}');
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: mensagemApi?.toString() ?? mensagemPorStatus(response.statusCode),
      details: decoded is Map<String, dynamic> && decoded['detalhes'] is Map<String, dynamic>
          ? decoded['detalhes'] as Map<String, dynamic>
          : null,
    );
  }
}
