import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intuitive_care_app/models/relatorio_config_model.dart';
import 'package:intuitive_care_app/repositories/analitico_repository.dart';
import 'package:intuitive_care_app/services/analitico_service.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/shared/utils/exporter.dart';
import 'package:intuitive_care_app/viewmodels/explorar_viewmodel.dart';

void main() {
  group('Exporter client-side XLSX estilizado e tipado', () {
    test('grava números como IntCellValue/DoubleCellValue, preserva identificadores, aplica estilo Forest e remove Sheet1', () {
      final bytes = Exporter.gerarXlsxBytes(const [
        ExportTable(
          titulo: 'Operadoras ANS',
          subtitulo: 'Recorte 2025 · 2 operadoras',
          colunas: ['Registro ANS', 'Operadora', 'Despesas (R\$)', 'Sinistralidade', 'Beneficiários'],
          linhas: [
            ['326305', 'AMIL SAUDE', '2000000000.50', '80,5%', '120.500'],
            ['000515', 'UNIMED JP', '32.500.000,25', '64.00%', '55000'],
          ],
        ),
        ExportTable(
          titulo: 'Plano de Contas',
          colunas: ['Conta', 'Descrição', 'Valor'],
          linhas: [
            ['41111', 'Eventos MH', 'R\$ 1.500,75'],
          ],
        ),
      ]);

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys.toList(), ['Operadoras ANS', 'Plano de Contas']);
      expect(excel.tables.containsKey('Sheet1'), isFalse);

      final sheet = excel['Operadoras ANS'];
      // Linha 0 = banner título, Linha 1 = subtítulo, Linha 2 = espaço, Linha 3 = cabeçalho, Linha 4..5 = dados
      final headCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3));
      expect(headCell.value, isA<TextCellValue>());
      expect(headCell.cellStyle?.isBold, isTrue);
      expect(headCell.cellStyle?.backgroundColor.colorHex.toUpperCase(), endsWith('113E32'));

      // Linha 4 (primeira linha de dados)
      final regAns = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4));
      final desp = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 4));
      final sin = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 4));
      final benef = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 4));
      expect(regAns.value, isA<TextCellValue>());
      expect((regAns.value as TextCellValue).value.text, '326305');
      expect(desp.value, isA<DoubleCellValue>());
      expect((desp.value as DoubleCellValue).value, closeTo(2000000000.50, 0.001));
      expect(sin.value, isA<DoubleCellValue>());
      expect((sin.value as DoubleCellValue).value, closeTo(0.805, 0.0001));
      expect(benef.value, isA<IntCellValue>());
      expect((benef.value as IntCellValue).value, 120500);

      // Linha 5 (zebra + número pt-BR + código com zero à esquerda)
      final regZero = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5));
      final despPtBr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 5));
      expect(regZero.value, isA<TextCellValue>());
      expect((regZero.value as TextCellValue).value.text, '000515');
      expect(despPtBr.value, isA<DoubleCellValue>());
      expect((despPtBr.value as DoubleCellValue).value, closeTo(32500000.25, 0.001));
      expect(despPtBr.cellStyle?.backgroundColor.colorHex.toUpperCase(), endsWith('F3F7F5'));

      // Segunda aba: coluna "Conta" permanece texto, moeda vira double
      final contasSheet = excel['Plano de Contas'];
      expect(contasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value, isA<TextCellValue>());
      final valMoeda = contasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value;
      expect(valMoeda, isA<DoubleCellValue>());
      expect((valMoeda as DoubleCellValue).value, closeTo(1500.75, 0.001));

      // Helper salvarBytes retorna o nome do arquivo
      expect(Exporter.salvarBytes(bytes, 'teste.xlsx', Exporter.mimeXlsx), 'teste.xlsx');
    });

    test('Exporter.exportar gera arquivo com extensão correta em CSV, XLSX e PDF', () async {
      const tabela = ExportTable(
        titulo: 'Resumo',
        colunas: ['Indicador', 'Valor'],
        linhas: [
          ['Despesas', '1000.00'],
        ],
      );
      expect(await Exporter.exportar(tabela, nomeBase: 'out', formato: 'XLSX'), 'out.xlsx');
      expect(await Exporter.exportar(tabela, nomeBase: 'out', formato: 'CSV'), 'out.csv');
      expect(await Exporter.exportar(tabela, nomeBase: 'out', formato: 'PDF'), 'out.pdf');
    });
  });

  group('ApiClient.postBytes e payload de /relatorios/exportar', () {
    test('ConfigRelatorio.toApiPayload serializa todas as 8 seções, filtros avançados e ordenação', () {
      const cfg = ConfigRelatorio(
        anos: {2025, 2024},
        trimestres: {4, 1},
        granularidade: 'trimestre',
        ufs: {'SP', 'PB'},
        modalidades: {'Medicina de Grupo'},
        portes: {'grande'},
        statuses: {'Ativa'},
        consolidacoes: {'consolidado'},
        secoes: {
          SecaoRelatorio.resumo,
          SecaoRelatorio.ufs,
          SecaoRelatorio.contasSetor,
          SecaoRelatorio.baseDemonstracoes,
          SecaoRelatorio.lotesCadastro,
        },
        ordenarRelatorio: OrdemRelatorio.resultado,
        limiteOperadoras: 100,
        formato: 'XLSX',
        formatoData: 'AAAA-MM-DD',
      );

      final payload = cfg.toApiPayload();
      expect(payload['anos'], [2024, 2025]);
      expect(payload['trimestres'], [1, 4]);
      expect(payload['granularidade'], 'trimestre');
      expect(payload['ufs'], ['PB', 'SP']);
      expect(payload['portes'], ['grande']);
      expect(payload['consolidacoes'], ['consolidado']);
      expect(payload['secoes'], ['resumo', 'ufs', 'contas_setor', 'base_demonstracoes', 'lotes_cadastro']);
      expect(payload['ordenar_por'], 'resultado');
      expect(payload['limite_operadoras'], 100);
      expect(payload['formato'], 'XLSX');
      expect(payload['formato_data'], 'AAAA-MM-DD');
    });

    test('postBytes envia Bearer token, extrai Content-Disposition e decodifica erro 403 JSON', () async {
      final requisicoes = <http.Request>[];
      final fakeXlsx = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]);

      final client = ApiClient(
        httpClient: MockClient((req) async {
          requisicoes.add(req);
          if (req.headers['Authorization'] == 'Bearer token-colab') {
            return http.Response.bytes(
              utf8.encode(jsonEncode({'erro': 'Ação permitida apenas para o perfil Administrador.'})),
              403,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response.bytes(
            fakeXlsx,
            200,
            headers: {
              'content-type': Exporter.mimeXlsx,
              'content-disposition': 'attachment; filename="relatorio_etl_ans_2025.xlsx"',
            },
          );
        }),
      );

      client.setAuthToken('token-admin');
      final vm = ExplorarViewModel(AnaliticoRepository(AnaliticoService(client)));
      final res = await vm.exportarRelatorioBytes({'anos': [2025], 'formato': 'XLSX'});
      expect(res.filename, 'relatorio_etl_ans_2025.xlsx');
      expect(res.bytes, fakeXlsx);
      expect(requisicoes.last.url.path, endsWith('/relatorios/exportar'));
      expect(requisicoes.last.headers['Authorization'], 'Bearer token-admin');

      client.setAuthToken('token-colab');
      await expectLater(
        vm.exportarRelatorioBytes({'anos': [2025], 'formato': 'XLSX'}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('parseRelatorioJson converte resposta JSON do backend em ExportTables para PDF', () {
      final parsed = parseRelatorioJson({
        'titulo_geral': 'Relatório Analítico ANS · Intuitive Care',
        'subtitulo_geral': 'Período 2025',
        'nome_base': 'relatorio_etl_ans_2025',
        'abas': [
          {
            'titulo': 'Resumo Executivo',
            'subtitulo': 'Período 2025',
            'colunas': ['Indicador', 'Valor'],
            'linhas': [
              ['Despesas', '2000000000.00'],
            ],
          },
          {
            'titulo': 'Base ETL · Lotes Extraídos',
            'colunas': ['Período', 'Auditado'],
            'linhas': [
              ['1º trimestre de 2025', 'Auditado'],
            ],
          },
        ],
      });
      expect(parsed.nomeBase, 'relatorio_etl_ans_2025');
      expect(parsed.abas.length, 2);
      expect(parsed.abas.first.titulo, 'Resumo Executivo');
      expect(parsed.abas.last.linhas.single, ['1º trimestre de 2025', 'Auditado']);
    });
  });
}
