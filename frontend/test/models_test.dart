import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intuitive_care_app/models/analitico_model.dart';
import 'package:intuitive_care_app/models/operadora_model.dart';
import 'package:intuitive_care_app/models/user_model.dart';
import 'package:intuitive_care_app/shared/utils/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Formatação (seção 10)', () {
    test('período por extenso e abreviado só para eixo', () {
      expect(fmtPeriodo(2025, 4), '4º trimestre de 2025');
      expect(fmtPeriodoCurto(2025, 4), '4º trimestre\n2025');
      expect(fmtTrimestre(2), '2º trimestre');
    });

    test('moeda, inteiros e variação em pt-BR', () {
      expect(fmtBi(79800000000), 'R\$ 79,80 bi');
      expect(fmtInt(2184906), '2.184.906');
      expect(fmtReais(351.4), 'R\$ 351');
      expect(fmtDelta(18.43), '+18,4%');
      expect(fmtDelta(-10.2), '-10,2%');
      expect(variation(110, 100), closeTo(10, 0.001));
      expect(variation(1, null), isNull);
    });

    test('CNPJ com máscara e iniciais', () {
      expect(fmtCnpj('29309127000179'), '29.309.127/0001-79');
      expect(iniciais('Luiza Leblanc'), 'LL');
    });
  });

  group('Modelos', () {
    test('UserModel lê perfil, cargo e preferências', () {
      final u = UserModel.fromJson({
        'id': 1,
        'nome': 'Luiza Leblanc',
        'email': 'admin@intuitivecare.com.br',
        'perfil': 'ADMIN',
        'cargo': 'Analista de Dados ANS',
        'membro_desde': '2024-08-01T10:00:00',
        'preferencias': {'formato_exportacao': 'PDF', 'uf_padrao': 'PB', 'trimestre_padrao': 2, 'tema': 'sistema'},
      });
      expect(u.isAdmin, isTrue);
      expect(u.cargo, 'Analista de Dados ANS');
      expect(u.preferencias.formatoExportacao, 'PDF');
      expect(u.preferencias.ufPadrao, 'PB');
      expect(u.preferencias.trimestrePadrao, 2);
      // Valor legado "sistema" é normalizado para "claro".
      expect(u.preferencias.tema, 'claro');
      expect(u.membroDesde?.year, 2024);

      final uEscuro = UserModel.fromJson({
        'id': 2,
        'nome': 'Ana',
        'email': 'ana@x.com',
        'preferencias': {'tema': 'escuro'},
      });
      expect(uEscuro.preferencias.tema, 'escuro');
    });

    test('OperadoraModel usa nome fantasia quando houver e expõe status', () {
      final op = OperadoraModel.fromJson({
        'registro_ans': '326305',
        'cnpj': '29309127000179',
        'razao_social': 'AMIL ASSISTÊNCIA MÉDICA INTERNACIONAL S.A.',
        'nome_fantasia': 'AMIL',
        'uf': 'SP',
        'status': 'Inativa',
        'beneficiarios': 3125480,
        'despesa_trimestre': 5910000000.0,
      });
      expect(op.nomeExibicao, 'AMIL');
      expect(op.isInativa, isTrue);
      expect(op.beneficiarios, 3125480);
      expect(op.toJson()['registro_ans'], '326305');
    });

    test('PainelModel lê visões Admin e Colaborador', () {
      final p = PainelModel.fromJson({
        'periodo': {'ano': 2026, 'trimestre': 2},
        'periodos': [
          {'ano': 2026, 'trimestre': 2},
          {'ano': 2026, 'trimestre': 1},
        ],
        'admin': {
          'total_despesas': 75.1e9,
          'total_despesas_anterior': 70.6e9,
          'registros_extraidos': 731372,
          'operadoras_ativas': 1101,
          'operadoras_com_demonstracao': 781,
          'serie': [
            {'ano': 2026, 'trimestre': 1, 'valor': 70.6e9},
            {'ano': 2026, 'trimestre': 2, 'valor': 75.1e9},
          ],
          'modalidades': [
            {'modalidade': 'Cooperativa Médica', 'valor': 23.6e9, 'pct': 31.4},
          ],
        },
        'colaborador': {
          'despesas_mh': 73.9e9,
          'sinistralidade': 0.752,
          'beneficiarios': 53004799,
          'ticket_medio': 1455.8,
          'ranking': [
            {'registro_ans': '005711', 'razao_social': 'BRADESCO SAUDE S.A.', 'nome_fantasia': null, 'uf': 'RJ', 'valor': 9.17e9},
          ],
          'serie': [],
        },
      });
      expect(p.periodo, const Periodo(2026, 2));
      expect(p.periodos, hasLength(2));
      expect(p.serieAdmin.last.valor, 75.1e9);
      expect(p.modalidades.single.pct, 31.4);
      expect(p.ranking.single.nome, 'BRADESCO SAUDE S.A.');
      expect(p.sinistralidade, 0.752);
    });

    test('ContasModel lê KPIs, contas, composição e lote', () {
      final c = ContasModel.fromJson({
        'periodo': {'ano': 2026, 'trimestre': 2},
        'periodo_anterior': {'ano': 2026, 'trimestre': 1},
        'periodos': [],
        'grupos': [
          {'codigo': '41', 'nome': 'Eventos indenizáveis'},
        ],
        'kpis': {
          '41': {'valor_atual': 75.1e9, 'valor_anterior': 70.6e9},
        },
        'contas': [
          {
            'codigo': '411',
            'descricao': 'EVENTOS',
            'grupo': 'Eventos indenizáveis',
            'nivel': 1,
            'valor_atual': 1.0,
            'valor_anterior': null,
          },
        ],
        'composicao': [
          {'forma': 'Por procedimento', 'valor': 4.2e10, 'pct': 58.4},
        ],
        'destaques': [],
        'lote': {'registros_extraidos': 731372, 'operadoras': 787, 'auditado': true, 'auditado_por': 'Luiza Leblanc'},
      });
      expect(c.kpis['41']!.$1, 75.1e9);
      expect(c.contas.single.valorAnterior, isNull);
      expect(c.composicao.single.forma, 'Por procedimento');
      expect(c.lote.auditado, isTrue);
    });
  });
}
