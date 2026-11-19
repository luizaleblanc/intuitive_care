import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

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
      throw ApiException(statusCode: response.statusCode, message: mensagemPorStatus(response.statusCode));
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) async {
    return _send(() => _httpClient.delete(_buildUri(path, query), headers: _headers()));
  }

  Future<dynamic> _send(Future<http.Response> Function() requestFn) async {
    final http.Response response;
    try {
      response = await requestFn().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException(statusCode: 0, message: mensagemTempoEsgotado);
    } catch (e) {
      debugPrint('[ApiClient] Falha de rede: $e');
      throw const ApiException(statusCode: 0, message: mensagemSemConexao);
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null; // Resposta que não é da API (ex.: página HTML de erro).
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded == null && response.body.isNotEmpty) {
        debugPrint('[ApiClient] Resposta sem JSON de ${response.request?.url}');
        throw const ApiException(statusCode: 0, message: mensagemServidorIndisponivel);
      }
      return decoded;
    }

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

const mensagemSemConexao = 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';
const mensagemTempoEsgotado = 'O servidor demorou para responder. Tente novamente em instantes.';
const mensagemServidorIndisponivel =
    'O serviço está indisponível no momento. Tente novamente em alguns minutos.';

/// Texto mostrado ao usuário quando a resposta não traz uma mensagem da API.
String mensagemPorStatus(int status) {
  if (status == 400 || status == 422) return 'Alguns dados não foram aceitos. Revise as informações e tente de novo.';
  if (status == 401) return 'Sua sessão expirou. Entre novamente.';
  if (status == 403) return 'Você não tem permissão para esta ação.';
  if (status == 404) return mensagemServidorIndisponivel;
  if (status == 429) return 'Muitas tentativas em pouco tempo. Aguarde alguns minutos.';
  if (status >= 500) return 'Ocorreu um erro no servidor. Tente novamente em instantes.';
  return 'Não foi possível concluir a ação. Tente novamente.';
}

typedef VoidCallback = void Function();
