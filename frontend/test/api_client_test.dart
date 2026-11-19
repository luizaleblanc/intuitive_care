import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intuitive_care_app/services/api_client.dart';

Future<String> erroDe(http.Response Function() resposta) async {
  final client = ApiClient(httpClient: MockClient((_) async => resposta()));
  try {
    await client.post('/auth/login');
  } on ApiException catch (e) {
    return e.message;
  }
  fail('Deveria lançar ApiException');
}

void main() {
  test('404 de página HTML (API fora do ar) vira mensagem amigável', () async {
    final msg = await erroDe(() => http.Response('<html>The page could not be found</html>', 404));
    expect(msg, mensagemServidorIndisponivel);
    expect(msg, isNot(contains('404')));
  });

  test('mensagem da própria API é mantida', () async {
    final msg = await erroDe(() => http.Response.bytes(
        utf8.encode(jsonEncode({'erro': 'E-mail ou senha inválidos.'})), 401,
        headers: {'content-type': 'application/json'}));
    expect(msg, 'E-mail ou senha inválidos.');
  });

  test('erro 500 sem JSON e falha de rede não mostram detalhes técnicos', () async {
    expect(await erroDe(() => http.Response('Internal Server Error', 500)), contains('erro no servidor'));
    expect(await erroDe(() => throw http.ClientException('XMLHttpRequest error')), mensagemSemConexao);
  });

  test('resposta 200 que não é JSON (rota caiu no site) é tratada como indisponível', () async {
    expect(await erroDe(() => http.Response('<!doctype html><html></html>', 200)), mensagemServidorIndisponivel);
  });
}
