import 'package:flutter_test/flutter_test.dart';
import 'package:intuitive_care_app/models/despesa_model.dart';
import 'package:intuitive_care_app/models/estatistica_model.dart';
import 'package:intuitive_care_app/models/operadora_model.dart';
import 'package:intuitive_care_app/models/user_model.dart';

void main() {
  group('Models JSON Serialization', () {
    test('UserModel.fromJson deve parsear corretamente os campos', () {
      final user = UserModel.fromJson({
        'id': 1,
        'nome': 'Luiza Leblanc',
        'email': 'admin@intuitivecare.com.br',
        'perfil': 'ADMIN',
        'ativo': 1,
      });

      expect(user.id, 1);
      expect(user.nome, 'Luiza Leblanc');
      expect(user.email, 'admin@intuitivecare.com.br');
      expect(user.perfil, 'ADMIN');
      expect(user.ativo, true);
    });

    test('OperadoraModel.fromJson deve aceitar registro_ans ou reg_ans', () {
      final op = OperadoraModel.fromJson({
        'reg_ans': '359017',
        'cnpj': '33444555000181',
        'razao_social': 'UNIMED JOAO PESSOA',
        'uf': 'PB',
        'total_despesas': 93541281.35,
      });

      expect(op.registroAns, '359017');
      expect(op.uf, 'PB');
      expect(op.totalDespesas, closeTo(93541281.35, 0.01));
      expect(op.toJson()['registro_ans'], '359017');
    });

    test('DespesaModel.fromJson e EstatisticaDashboardModel.fromJson', () {
      final desp = DespesaModel.fromJson({
        'id': 10,
        'reg_ans': '359017',
        'ano': 2025,
        'trimestre': 1,
        'valor_despesa': 33890710.15,
        'categoria': 'Despesa Assistencial',
        'faixa_porte': 'Pequeno Porte',
      });

      expect(desp.id, 10);
      expect(desp.trimestre, 1);
      expect(desp.faixaPorte, 'Pequeno Porte');

      final stats = EstatisticaDashboardModel.fromJson({
        'total_geral': 1000000.0,
        'media_despesa': 250000.0,
        'total_lancamentos': 4,
        'total_operadoras': 2,
        'crescimento_periodo_pct': 12.5,
        'top_ufs': [
          {'uf': 'SP', 'total': 700000.0, 'qtd_operadoras': 1},
        ],
        'serie_trimestral': [
          {'ano': 2025, 'trimestre': 1, 'periodo': '2025-T1', 'total': 1000000.0},
        ],
        'top_operadoras': [],
      });

      expect(stats.topUfs.first.uf, 'SP');
      expect(stats.crescimentoPeriodoPct, 12.5);
    });
  });
}
