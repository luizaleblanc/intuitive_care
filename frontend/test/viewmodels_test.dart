import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intuitive_care_app/repositories/analitico_repository.dart';
import 'package:intuitive_care_app/repositories/auth_repository.dart';
import 'package:intuitive_care_app/repositories/operadora_repository.dart';
import 'package:intuitive_care_app/services/analitico_service.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/services/auth_service.dart';
import 'package:intuitive_care_app/services/operadora_service.dart';
import 'package:intuitive_care_app/services/session_storage_service.dart';
import 'package:intuitive_care_app/viewmodels/auth_viewmodel.dart';
import 'package:intuitive_care_app/viewmodels/contas_viewmodel.dart';
import 'package:intuitive_care_app/viewmodels/operadoras_viewmodel.dart';
import 'package:intuitive_care_app/viewmodels/painel_viewmodel.dart';

class _MemoriaSessao extends SessionStorageService {
  String? _token;
  @override
  Future<void> saveToken(String token) async => _token = token;
  @override
  Future<String?> readToken() async => _token;
  @override
  Future<void> clearToken() async => _token = null;
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _painel(int ano, int tri) => {
      'periodo': {'ano': ano, 'trimestre': tri},
      'periodos': [
        {'ano': 2026, 'trimestre': 2},
        {'ano': 2026, 'trimestre': 1},
        {'ano': 2025, 'trimestre': 4},
      ],
      'admin': {
        'total_despesas': 1.0,
        'registros_extraidos': 10,
        'operadoras_ativas': 1,
        'operadoras_com_demonstracao': 1,
        'serie': [],
        'modalidades': [],
      },
      'colaborador': {'despesas_mh': 1.0, 'beneficiarios': 1, 'ranking': [], 'serie': []},
    };

void main() {
  test('AuthViewModel faz login com Bearer, atualiza perfil e encerra sessão', () async {
    final headers = <String, String?>{};
    Map<String, dynamic>? corpoPerfil;
    final client = ApiClient(
      httpClient: MockClient((req) async {
        headers[req.url.path] = req.headers['Authorization'];
        if (req.url.path.endsWith('/auth/login')) {
          return _json({
            'token': 'jwt-demo',
            'usuario': {'id': 1, 'nome': 'Luiza Leblanc', 'email': 'admin@intuitivecare.com.br', 'perfil': 'ADMIN'},
          });
        }
        if (req.url.path.endsWith('/auth/me') && req.method == 'PUT') {
          corpoPerfil = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({
            'usuario': {
              'id': 1,
              'nome': corpoPerfil!['nome'],
              'email': 'admin@intuitivecare.com.br',
              'perfil': 'ADMIN',
              'telefone': corpoPerfil!['telefone'],
            },
          });
        }
        return _json({'mensagem': 'ok'});
      }),
    );
    final vm = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: _MemoriaSessao()),
    );

    expect(await vm.login(email: 'admin@intuitivecare.com.br', senha: 'Admin@2025'), isTrue);
    expect(vm.currentUser!.isAdmin, isTrue);

    expect(await vm.updateProfile({'nome': 'Luiza L.', 'telefone': '(83) 99999-0000'}), isTrue);
    expect(vm.currentUser!.nome, 'Luiza L.');
    expect(vm.currentUser!.telefone, '(83) 99999-0000');
    expect(headers['/api/auth/me'], 'Bearer jwt-demo');

    await vm.logout();
    expect(vm.status, AuthStatus.unauthenticated);
  });

  test('Cadastro não abre sessão e expõe e-mail duplicado (409)', () async {
    Map<String, dynamic>? corpo;
    var status = 201;
    final client = ApiClient(
      httpClient: MockClient((req) async {
        corpo = jsonDecode(req.body) as Map<String, dynamic>;
        return status == 201
            ? _json({'mensagem': 'ok', 'token': 'ignorado'}, 201)
            : _json({'erro': 'Já existe um usuário cadastrado com este e-mail.'}, status);
      }),
    );
    final sessao = _MemoriaSessao();
    final vm = AuthViewModel(AuthRepository(apiClient: client, authService: AuthService(client), storageService: sessao));

    expect(await vm.register(nome: 'Ana', email: 'ana@x.com', senha: 'Teste@123', cargo: 'Analista'), isTrue);
    expect(corpo!['cargo'], 'Analista');
    expect(vm.isAuthenticated, isFalse);
    expect(await sessao.readToken(), isNull);

    status = 409;
    expect(await vm.register(nome: 'Ana', email: 'ana@x.com', senha: 'Teste@123'), isFalse);
    expect(vm.errorMessage, contains('Já existe'));
  });

  test('Redefinição envia token e nova senha', () async {
    late http.Request pedido;
    final client = ApiClient(
      httpClient: MockClient((req) async {
        pedido = req;
        return _json({'mensagem': 'ok'});
      }),
    );
    final vm = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: _MemoriaSessao()),
    );
    expect(await vm.confirmPasswordReset(token: 'abc', novaSenha: 'Teste@123'), isTrue);
    expect(pedido.url.path, endsWith('/auth/redefinir-senha'));
    expect(jsonDecode(pedido.body), {'token': 'abc', 'nova_senha': 'Teste@123'});
  });

  test('PainelViewModel envia Ano + Trimestre e ajusta o trimestre ao trocar de ano', () async {
    final consultas = <Map<String, String>>[];
    final client = ApiClient(
      httpClient: MockClient((req) async {
        consultas.add(req.url.queryParameters);
        final ano = int.tryParse(req.url.queryParameters['ano'] ?? '') ?? 2026;
        final tri = int.tryParse(req.url.queryParameters['trimestre'] ?? '') ?? 2;
        return _json(_painel(ano, tri));
      }),
    );
    final vm = PainelViewModel(AnaliticoRepository(AnaliticoService(client)));

    await vm.carregar();
    expect(vm.anosDisponiveis, [2026, 2025]);
    expect(vm.trimestresDoAno(2026), [1, 2]);

    await vm.carregar(ano: 2025);
    expect(consultas.last['ano'], '2025');
    expect(consultas.last['trimestre'], '4');

    await vm.carregar(uf: 'SP');
    expect(consultas.last['uf'], 'SP');

    await vm.carregar(
      anos: {2025, 2026},
      trimestres: {1, 2},
      ufs: {'SP', 'RJ'},
      modalidades: {'Medicina de Grupo', 'Autogestão'},
    );
    expect(consultas.last['ano'], '2025,2026');
    expect(consultas.last['trimestre'], '1,2');
    expect(consultas.last['uf'], 'RJ,SP');
    expect(consultas.last['modalidade'], 'Autogestão,Medicina de Grupo');

    await vm.carregar(escopo: 'admin');
    expect(consultas.last['escopo'], 'admin');
    await vm.carregar(ano: 2026);
    expect(consultas.last['escopo'], 'admin');
  });

  test('OperadorasViewModel carrega lista + resumo e envia busca', () async {
    String? busca;
    final client = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/resumo')) {
          return _json({'ativas': 1101, 'em_analise': 0, 'inativadas_12m': 43, 'beneficiarios': 90491206,
            'modalidades': ['Medicina de Grupo'], 'ufs': ['SP']});
        }
        busca = req.url.queryParameters['search'];
        return _json({
          'data': [
            {'registro_ans': '326305', 'cnpj': '29309127000179', 'razao_social': 'AMIL', 'uf': 'SP', 'status': 'Ativa'},
          ],
          'total': 1,
          'page': 1,
          'limit': 15,
          'total_pages': 1,
        });
      }),
    );
    final vm = OperadorasViewModel(OperadoraRepository(OperadoraService(client)));

    await vm.carregar(search: '29.309.127/0001-79', resumo: true);
    expect(busca, '29.309.127/0001-79');
    expect(vm.items.single.registroAns, '326305');
    expect(vm.resumo.ativas, 1101);
    expect(vm.resumo.modalidades, ['Medicina de Grupo']);

    await vm.carregar(modalidades: {'Medicina de Grupo', 'Autogestão'});
    expect(vm.modalidade, 'Autogestão,Medicina de Grupo');

    final vmResumo = OperadorasViewModel(OperadoraRepository(OperadoraService(
      ApiClient(
        httpClient: MockClient((req) async {
          expect(req.url.path, endsWith('/operadoras/resumo'));
          return _json({'ativas': 10, 'em_analise': 1, 'inativadas_12m': 0, 'beneficiarios': 100,
            'modalidades': ['Autogestão'], 'ufs': ['PB']});
        }),
      ),
    )));
    await vmResumo.carregarResumo();
    expect(vmResumo.resumo.ufs, ['PB']);
    expect(vmResumo.items, isEmpty);
  });

  test('ContasViewModel expõe erro 403 ao auditar lote sem permissão', () async {
    final client = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path.contains('/auditar')) {
          return _json({'erro': 'Ação permitida apenas para o perfil Administrador.'}, 403);
        }
        return _json({
          'periodo': {'ano': 2026, 'trimestre': 2},
          'periodo_anterior': {'ano': 2026, 'trimestre': 1},
          'periodos': [
            {'ano': 2026, 'trimestre': 2},
          ],
          'grupos': [],
          'kpis': {},
          'contas': [],
          'composicao': [],
          'destaques': [],
          'lote': {'auditado': false},
        });
      }),
    );
    final vm = ContasViewModel(AnaliticoRepository(AnaliticoService(client)));
    await vm.carregar();
    expect(vm.contas, isNotNull);
    expect(await vm.auditarLote(), isNull);
    expect(vm.error, contains('Administrador'));

    await vm.carregar(anos: {2025, 2026}, trimestres: {1, 2}, grupos: {'41', '46'});
    expect(vm.grupo, '41,46');
  });
}
