import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/explorar_model.dart';
import '../models/relatorio_config_model.dart';
import '../services/api_client.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/explorar_viewmodel.dart';
import 'relatorio/relatorio_filtros_section.dart';
import 'relatorio/relatorio_secoes_section.dart';

export '../models/relatorio_config_model.dart';
export '../shared/utils/relatorio_mapper.dart';

/// Abre o construtor de relatório personalizado (planilha XLSX com openpyxl / CSV / PDF) exclusivo do Administrador.
void abrirRelatorioPersonalizado(BuildContext context) {
  showSideDrawer<void>(context, width: 580, builder: (_) => const RelatorioDrawer());
}

class RelatorioDrawer extends StatefulWidget {
  const RelatorioDrawer({super.key});

  @override
  State<RelatorioDrawer> createState() => _RelatorioDrawerState();
}

class _RelatorioDrawerState extends State<RelatorioDrawer> {
  List<int> _anosDisponiveis = const [];
  Facetas _facetas = const Facetas();
  Set<int> _anos = {};
  Set<int> _trimestres = {};
  String _granularidade = 'ano';
  Set<String> _ufs = {};
  Set<String> _modalidades = {};
  Set<String> _portes = {};
  Set<String> _statuses = {};
  Set<String> _consolidacoes = {};
  Set<SecaoRelatorio> _secoes = Set.of(SecaoRelatorio.values);
  OrdemRelatorio _ordenarPor = OrdemRelatorio.despesas;
  int? _limite = 50;
  String _formato = 'XLSX';
  String _formatoData = 'DD/MM/AAAA';
  bool _carregandoBase = true;
  bool _gerando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<AuthViewModel>().currentUser?.preferencias;
    if (prefs != null) {
      if (const {'XLSX', 'CSV', 'PDF'}.contains(prefs.formatoExportacao)) {
        _formato = prefs.formatoExportacao;
      }
      if (const {'DD/MM/AAAA', 'AAAA-MM-DD'}.contains(prefs.formatoData)) {
        _formatoData = prefs.formatoData;
      }
    }
    _carregarOpcoes();
  }

  Future<void> _carregarOpcoes() async {
    final vm = context.read<ExplorarViewModel>();
    try {
      final base = vm.dados ?? await vm.consultarRelatorio(const {'granularidade': 'ano'});
      if (!mounted) return;
      setState(() {
        _anosDisponiveis = base.anosDisponiveis;
        _facetas = base.facetas;
        _anos = base.anosDisponiveis.isEmpty ? {} : {base.anosDisponiveis.last};
        _carregandoBase = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.message;
          _carregandoBase = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar as opções do relatório: $e';
          _carregandoBase = false;
        });
      }
    }
  }

  int get _quantidadeAbasXlsx {
    var total = _secoes.length;
    // A seção "Base ETL · Lotes e Cadastro" gera duas abas no XLSX: "Lotes ETL" e "Cadastro Operadoras".
    if (_secoes.contains(SecaoRelatorio.lotesCadastro)) total += 1;
    return total;
  }

  Future<void> _gerar() async {
    if (_anos.isEmpty || _secoes.isEmpty) return;
    setState(() {
      _gerando = true;
      _erro = null;
    });
    final vm = context.read<ExplorarViewModel>();
    final toast = context.read<ToastController>();
    final anosOrd = _anos.toList()..sort();
    final sufixoAnos = anosOrd.length == 1 ? '${anosOrd.first}' : '${anosOrd.first}_${anosOrd.last}';

    final cfg = ConfigRelatorio(
      anos: _anos,
      trimestres: _trimestres,
      granularidade: _granularidade,
      ufs: _ufs,
      modalidades: _modalidades,
      portes: _portes,
      statuses: _statuses,
      consolidacoes: _consolidacoes,
      secoes: _secoes,
      ordenarRelatorio: _ordenarPor,
      limiteOperadoras: _limite,
      formato: _formato,
      formatoData: _formatoData,
    );

    try {
      late final String nomeFinal;
      if (_formato == 'PDF') {
        final resposta = await vm.exportarRelatorioJson(cfg.toApiPayload(formatoOverride: 'JSON'));
        final parsed = parseRelatorioJson(resposta);
        if (parsed.abas.isEmpty) {
          throw const ApiException(statusCode: 404, message: 'Não há dados para compor o relatório com esses filtros.');
        }
        nomeFinal = await Exporter.exportarRelatorio(
          parsed.abas,
          nomeBase: parsed.nomeBase,
          formato: 'PDF',
          tituloGeral: parsed.tituloGeral,
          subtituloGeral: parsed.subtituloGeral,
        );
      } else {
        final resposta = await vm.exportarRelatorioBytes(cfg.toApiPayload());
        final ext = _formato == 'CSV' ? 'csv' : 'xlsx';
        final mime = _formato == 'CSV' ? Exporter.mimeCsv : Exporter.mimeXlsx;
        final nome = resposta.filename ?? 'relatorio_etl_ans_$sufixoAnos.$ext';
        nomeFinal = Exporter.salvarBytes(resposta.bytes, nome, mime);
      }
      if (!mounted) return;
      toast.show('Relatório exportado ($nomeFinal)');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Falha ao gerar o relatório: $e');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final podeGerar = !_carregandoBase && !_gerando && _anos.isNotEmpty && _secoes.isNotEmpty;
    final resumoFormato = switch (_formato) {
      'XLSX' => '$_quantidadeAbasXlsx aba(s) com fórmulas vivas, gráficos nativos e formatação contábil ANS',
      'CSV' => '${_secoes.length} bloco(s) em UTF-8 BOM compatível com Excel e BI',
      _ => '${_secoes.length} seção(ões) estruturadas direto das bases ETL da ANS',
    };

    return Container(
      color: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  'Exportar relatório ETL (ANS)',
                  style: AppText.display(20, color: AppColors.sageText),
                ),
              ),
              AppIconButton(icon: LucideIcons.x, label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Gere planilhas analíticas diretamente sobre todas as bases do ETL da ANS com filtros avançados, fórmulas e gráficos.',
              style: AppText.sans(13, color: AppColors.sageMuted),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _carregandoBase
                ? const LoadingBlock(label: 'Carregando filtros...')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    children: [
                      if (_erro != null) ...[ErrorBox(_erro!), const SizedBox(height: 16)],
                      RelatorioFormatoPeriodoSection(
                        formato: _formato,
                        resumoFormato: resumoFormato,
                        anosDisponiveis: _anosDisponiveis,
                        anos: _anos,
                        trimestres: _trimestres,
                        granularidade: _granularidade,
                        onFormatoChanged: (v) => setState(() => _formato = v),
                        onAnosChanged: (v) => setState(() => _anos = v),
                        onTrimestresChanged: (v) => setState(() => _trimestres = v),
                        onGranularidadeChanged: (v) => setState(() => _granularidade = v),
                      ),
                      RelatorioSecoesSelector(
                        secoes: _secoes,
                        onChanged: (v) => setState(() => _secoes = v),
                      ),
                      if (_secoes.contains(SecaoRelatorio.operadoras))
                        RelatorioOrdenacaoSection(
                          ordenarPor: _ordenarPor,
                          limite: _limite,
                          onOrdenarChanged: (v) => setState(() => _ordenarPor = v),
                          onLimiteChanged: (v) => setState(() => _limite = v),
                        ),
                      RelatorioFiltrosAvancadosSection(
                        facetas: _facetas,
                        ufs: _ufs,
                        modalidades: _modalidades,
                        portes: _portes,
                        statuses: _statuses,
                        consolidacoes: _consolidacoes,
                        onUfsChanged: (v) => setState(() => _ufs = v),
                        onModalidadesChanged: (v) => setState(() => _modalidades = v),
                        onPortesChanged: (v) => setState(() => _portes = v),
                        onStatusesChanged: (v) => setState(() => _statuses = v),
                        onConsolidacoesChanged: (v) => setState(() => _consolidacoes = v),
                      ),
                    ],
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.slate200)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AppButton('Cancelar', variant: ButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    _formato == 'XLSX' ? 'Exportar planilha' : 'Exportar $_formato',
                    icon: LucideIcons.fileSpreadsheet,
                    loading: _gerando,
                    loadingLabel: 'Gerando...',
                    onPressed: podeGerar ? _gerar : null,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
