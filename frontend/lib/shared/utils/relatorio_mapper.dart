import '../../models/explorar_model.dart';
import '../../models/relatorio_config_model.dart';
import 'exporter.dart';
import 'formatters.dart';

String _fmtValorMetrica(Metrica m, Valores v) => switch (m) {
      Metrica.despesas => v.despesas.toStringAsFixed(2),
      Metrica.receitas => v.receitas.toStringAsFixed(2),
      Metrica.sinistralidade => v.sinistralidade == null ? '' : v.sinistralidade!.toStringAsFixed(2),
      Metrica.beneficiarios => v.beneficiarios.toStringAsFixed(0),
    };

String _fmtValorResumo(Metrica m, Valores v) => switch (m) {
      Metrica.despesas => fmtBi(v.despesas),
      Metrica.receitas => fmtBi(v.receitas),
      Metrica.sinistralidade => v.sinistralidade == null ? '—' : fmtPct(v.sinistralidade!),
      Metrica.beneficiarios => fmtInt(v.beneficiarios),
    };

String _colunaMetrica(Metrica m) => switch (m) {
      Metrica.despesas => 'Despesas assistenciais (R\$)',
      Metrica.receitas => 'Receitas / Contraprestações (R\$)',
      Metrica.sinistralidade => 'Sinistralidade (%)',
      Metrica.beneficiarios => 'Beneficiários',
    };

String _rotuloRecorte(ExplorarModel dados, ConfigRelatorio cfg) {
  final anos = dados.anos.isNotEmpty ? dados.anos : [dados.anoInicio];
  final parteAnos = anos.length == 1
      ? '${anos.first}'
      : (anos.length == anos.last - anos.first + 1 ? '${anos.first}–${anos.last}' : anos.join(', '));
  final parteTris = cfg.trimestres.isEmpty || cfg.trimestres.length == 4 ? '' : ' · ${fmtTrimestres(cfg.trimestres)}';
  final filtros = <String>[
    if (cfg.ufs.isNotEmpty) 'UF: ${(cfg.ufs.toList()..sort()).join(', ')}',
    if (cfg.modalidades.isNotEmpty) 'Modalidade: ${(cfg.modalidades.toList()..sort()).join(', ')}',
    if (cfg.statuses.isNotEmpty) 'Status: ${(cfg.statuses.toList()..sort()).join(', ')}',
  ];
  return [
    'Período $parteAnos$parteTris',
    if (filtros.isNotEmpty) filtros.join(' · '),
    '${fmtInt(dados.totalOperadoras)} operadoras no recorte',
  ].join(' · ');
}

/// Monta abas concisas client-side a partir de [ExplorarModel] (mantido para compatibilidade e fallback).
List<ExportTable> montarAbasRelatorio(ExplorarModel dados, ConfigRelatorio cfg) {
  final metricas = [for (final m in Metrica.values) if (cfg.metricas.contains(m)) m];
  final subtitulo = _rotuloRecorte(dados, cfg);
  final abas = <ExportTable>[];

  if (cfg.secoes.contains(SecaoRelatorio.resumo)) {
    abas.add(
      ExportTable(
        titulo: 'Resumo Executivo',
        subtitulo: subtitulo,
        colunas: const ['Indicador', 'Valor', 'Detalhe'],
        linhas: [
          [
            'Período analisado',
            _rotuloRecorte(dados, cfg).split(' · ').first.replaceFirst('Período ', ''),
            cfg.granularidade == 'ano' ? 'Agrupamento anual' : 'Agrupamento trimestral',
          ],
          [
            'Operadoras no recorte',
            fmtInt(dados.totalOperadoras),
            cfg.statuses.isEmpty ? 'Ativas e inativas conforme filtro' : (cfg.statuses.toList()..sort()).join(', '),
          ],
          for (final m in metricas) [m.nome, _fmtValorResumo(m, dados.kpis), m.descricao],
        ],
      ),
    );
  }

  if (cfg.secoes.contains(SecaoRelatorio.evolucao)) {
    abas.add(
      ExportTable(
        titulo: 'Evolucao',
        subtitulo: subtitulo,
        colunas: ['Período', for (final m in metricas) _colunaMetrica(m)],
        linhas: [
          for (final p in dados.serie)
            [
              p.trimestre == null ? '${p.ano}' : fmtPeriodo(p.ano, p.trimestre!),
              for (final m in metricas) _fmtValorMetrica(m, p.valores),
            ],
        ],
      ),
    );
  }

  if (cfg.secoes.contains(SecaoRelatorio.modalidades)) {
    abas.add(
      ExportTable(
        titulo: 'Modalidades',
        subtitulo: subtitulo,
        colunas: ['Modalidade', 'Operadoras', for (final m in metricas) _colunaMetrica(m)],
        linhas: [
          for (final mod in dados.porModalidade)
            [
              mod.modalidade,
              mod.operadoras.toString(),
              for (final m in metricas) _fmtValorMetrica(m, mod.valores),
            ],
        ],
      ),
    );
  }

  if (cfg.secoes.contains(SecaoRelatorio.operadoras)) {
    final lista = List<OperadoraExplorar>.from(dados.operadoras)
      ..sort((a, b) => (b.valores.de(cfg.ordenarPor) ?? -1).compareTo(a.valores.de(cfg.ordenarPor) ?? -1));
    final recorte = cfg.limiteOperadoras == null ? lista : lista.take(cfg.limiteOperadoras!).toList();
    abas.add(
      ExportTable(
        titulo: 'Operadoras',
        subtitulo: '$subtitulo · Ordenado por ${cfg.ordenarPor.nome}',
        colunas: ['Registro ANS', 'Operadora', 'UF', 'Modalidade', 'Status', for (final m in metricas) _colunaMetrica(m)],
        linhas: [
          for (final o in recorte)
            [
              o.registroAns,
              o.nome,
              o.uf ?? '',
              o.modalidade,
              o.status ?? '',
              for (final m in metricas) _fmtValorMetrica(m, o.valores),
            ],
        ],
      ),
    );
  }

  return abas;
}
