import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/operadora_model.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/operadoras_viewmodel.dart';
import 'app_shell.dart';

class OperadorasView extends StatefulWidget {
  final String? buscaInicial;
  const OperadorasView({super.key, this.buscaInicial});

  @override
  State<OperadorasView> createState() => _OperadorasViewState();
}

class _OperadorasViewState extends State<OperadorasView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OperadorasViewModel>().carregar(search: widget.buscaInicial ?? '', resumo: true);
      context.read<ShellActions>().registrarExportacao(() => _exportar());
    });
  }

  @override
  void didUpdateWidget(covariant OperadorasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.buscaInicial != oldWidget.buscaInicial) {
      context.read<OperadorasViewModel>().carregar(search: widget.buscaInicial ?? '');
    }
  }

  @override
  void deactivate() {
    context.read<ShellActions>().registrarExportacao(null);
    super.deactivate();
  }

  /// Sem [formato], usa a preferência "Exportar como" do perfil; o botão "Exportar CSV" força CSV.
  Future<void> _exportar({String? formato}) async {
    final vm = context.read<OperadorasViewModel>();
    formato ??= context.read<AuthViewModel>().currentUser?.preferencias.formatoExportacao ?? 'CSV';
    try {
      final linhas = await vm.exportar();
      if (linhas.isEmpty) return;
      final nome = await Exporter.exportar(
        ExportTable(
          titulo: 'Operadoras ANS',
          subtitulo: [
            if (vm.search.isNotEmpty) 'Busca: ${vm.search}',
            if (vm.modalidade.isNotEmpty) 'Modalidade: ${vm.modalidade}',
            '${linhas.length - 1} operadora(s)',
          ].join(' · '),
          colunas: linhas.first,
          linhas: linhas.skip(1).toList(),
        ),
        nomeBase: 'operadoras_ans',
        formato: formato,
      );
      if (mounted) context.read<ToastController>().show('Exportação concluída ($nome)');
    } catch (e) {
      if (mounted) context.read<ToastController>().show('Falha ao exportar: $e', error: true);
    }
  }

  void _abrir(OperadoraModel? op) {
    showSideDrawer(context, builder: (_) => _OperadoraDrawer(operadora: op));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final vm = context.watch<OperadorasViewModel>();
    final isAdmin = context.watch<AuthViewModel>().currentUser?.isAdmin ?? false;
    final r = vm.resumo;
    final cards = [
      ('Ativas', fmtInt(r.ativas), LucideIcons.circleCheck),
      ('Em análise', fmtInt(r.emAnalise), LucideIcons.clock),
      ('Inativadas (12m)', fmtInt(r.inativadas12m), LucideIcons.circleOff),
      ('Beneficiários', fmtMi(r.beneficiarios), LucideIcons.users),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: AppLayout.gutter),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(16)),
                        child: Icon(cards[i].$3, size: 19, color: AppColors.sageText),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cards[i].$1, style: AppText.sans(14, color: AppColors.muted)),
                          Text(cards[i].$2, style: AppText.display(20, weight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppLayout.gutter),
        AppCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SearchInput(
                      value: vm.search,
                      width: 420,
                      placeholder: 'Buscar por Registro ANS, Razão Social ou CNPJ',
                      onChanged: (v) => vm.carregar(search: v),
                      onSubmitted: (v) => vm.carregar(search: v),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: AppMultiSelect<String>(
                        semanticLabel: 'Modalidades',
                        icon: LucideIcons.layers,
                        selected: vm.modalidades,
                        emptyLabel: 'Todas modalidades',
                        options: [for (final m in r.modalidades) (m, m)],
                        formatSelected: (l) => l.length == 1 ? l.first.$2 : '${l.length} modalidades',
                        onChanged: (v) => vm.carregar(modalidades: v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${fmtInt(vm.total)} resultado(s)', style: AppText.sans(14, color: AppColors.muted)),
                    const Spacer(),
                    if (isAdmin) ...[
                      AppButton('Exportar CSV',
                          variant: ButtonVariant.secondary,
                          icon: LucideIcons.download,
                          onPressed: () => _exportar(formato: 'CSV')),
                      const SizedBox(width: 8),
                      AppButton('Nova operadora', icon: LucideIcons.plus, onPressed: () => _abrir(null)),
                    ],
                  ],
                ),
              ),
              if (vm.error != null)
                Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: ErrorBox(vm.error!)),
              _Tabela(itens: vm.items, isAdmin: isAdmin, loading: vm.isLoading, busca: vm.search, onTap: _abrir),
              if (vm.totalPages > 1)
                Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate100))),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text('Página ${vm.page} de ${vm.totalPages}', style: AppText.sans(14, color: AppColors.muted)),
                      const Spacer(),
                      AppButton('Anterior',
                          size: ButtonSize.sm,
                          variant: ButtonVariant.secondary,
                          icon: LucideIcons.chevronLeft,
                          onPressed: vm.page > 1 && !vm.isLoading ? () => vm.carregar(page: vm.page - 1) : null),
                      const SizedBox(width: 8),
                      AppButton('Próxima',
                          size: ButtonSize.sm,
                          variant: ButtonVariant.secondary,
                          iconRight: LucideIcons.chevronRight,
                          onPressed: vm.page < vm.totalPages && !vm.isLoading
                              ? () => vm.carregar(page: vm.page + 1)
                              : null),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tabela extends StatelessWidget {
  final List<OperadoraModel> itens;
  final bool isAdmin;
  final bool loading;
  final String busca;
  final void Function(OperadoraModel) onTap;

  const _Tabela(
      {required this.itens, required this.isAdmin, required this.loading, required this.busca, required this.onTap});

  static const _flex = [12, 30, 17, 16, 5, 12, 11, 11];

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    Widget th(String t, int i, {TextAlign align = TextAlign.left}) => Expanded(
          flex: _flex[i],
          child: Text(t.toUpperCase(),
              textAlign: align,
              style: AppText.sans(11, weight: FontWeight.w700, color: Colors.white, spacing: 11 * 0.05)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.primaryBg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            th('Registro ANS', 0),
            th('Operadora', 1),
            th('CNPJ', 2),
            th('Modalidade', 3),
            th('UF', 4),
            th('Beneficiários', 5, align: TextAlign.right),
            th('   Status', 6),
            th('', 7),
          ]),
        ),
        if (loading && itens.isEmpty) const LoadingBlock(height: 200, label: 'Carregando operadoras...'),
        if (!loading && itens.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 56),
            child: Text(
              busca.isEmpty ? 'Nenhuma operadora encontrada.' : 'Nenhuma operadora encontrada para "$busca".',
              textAlign: TextAlign.center,
              style: AppText.sans(14, color: AppColors.muted),
            ),
          ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: loading ? 0.5 : 1,
          child: Column(
            children: [
              for (final o in itens) _Linha(op: o, isAdmin: isAdmin, flex: _flex, onTap: () => onTap(o)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Linha extends StatefulWidget {
  final OperadoraModel op;
  final bool isAdmin;
  final List<int> flex;
  final VoidCallback onTap;
  const _Linha({required this.op, required this.isAdmin, required this.flex, required this.onTap});

  @override
  State<_Linha> createState() => _LinhaState();
}

class _LinhaState extends State<_Linha> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final o = widget.op;
    final f = widget.flex;
    return Semantics(
      button: true,
      label: '${o.nomeExibicao}, registro ${o.registroAns}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: _hover ? AppColors.cardHover : AppColors.card,
              border: Border(top: BorderSide(color: AppColors.slate100)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(flex: f[0], child: Text(o.registroAns, style: AppText.mono(14))),
                Expanded(
                  flex: f[1],
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nomeProprio(o.nomeExibicao),
                            overflow: TextOverflow.ellipsis, style: AppText.sans(14, weight: FontWeight.w600)),
                        Text(o.razaoSocial,
                            overflow: TextOverflow.ellipsis, style: AppText.sans(12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: f[2],
                  child: Text(fmtCnpj(o.cnpj),
                      style: AppText.mono(12, weight: FontWeight.w400, color: AppColors.slate600)),
                ),
                Expanded(
                    flex: f[3],
                    child: Align(alignment: Alignment.centerLeft, child: ModalidadePill(o.modalidade))),
                Expanded(flex: f[4], child: Text(o.uf, style: AppText.sans(14, weight: FontWeight.w600))),
                Expanded(
                  flex: f[5],
                  child: Text(fmtInt(o.beneficiarios),
                      textAlign: TextAlign.right, style: AppText.sans(14, weight: FontWeight.w600)),
                ),
                Expanded(
                  flex: f[6],
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Align(alignment: Alignment.centerLeft, child: StatusPill(o.status)),
                  ),
                ),
                Expanded(
                  flex: f[7],
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _hover ? AppColors.sage : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.isAdmin ? LucideIcons.pencil : LucideIcons.eye,
                              size: 13, color: AppColors.brandText),
                          const SizedBox(width: 4),
                          Text(widget.isAdmin ? 'Gerenciar' : 'Detalhes',
                              style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.brandText)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gaveta de detalhes / edição / criação
// ---------------------------------------------------------------------------
class _OperadoraDrawer extends StatefulWidget {
  final OperadoraModel? operadora;
  const _OperadoraDrawer({this.operadora});

  @override
  State<_OperadoraDrawer> createState() => _OperadoraDrawerState();
}

class _OperadoraDrawerState extends State<_OperadoraDrawer> {
  late OperadoraModel? _op = widget.operadora;
  late bool _editando = widget.operadora == null;
  String? _erro;

  late final _reg = TextEditingController();
  late final _cnpj = TextEditingController();
  late final _fantasia = TextEditingController();
  late final _razao = TextEditingController();
  late final _uf = TextEditingController();
  late final _modalidade = TextEditingController();
  late final _benef = TextEditingController();

  bool get _criando => _op == null;

  @override
  void initState() {
    super.initState();
    _preencher();
  }

  void _preencher() {
    final o = _op;
    _reg.text = o?.registroAns ?? '';
    _cnpj.text = o == null ? '' : fmtCnpj(o.cnpj);
    _fantasia.text = o?.nomeFantasia ?? '';
    _razao.text = o?.razaoSocial ?? '';
    _uf.text = o?.uf ?? '';
    _modalidade.text = o?.modalidade ?? '';
    _benef.text = o == null ? '' : o.beneficiarios.toString();
  }

  @override
  void dispose() {
    for (final c in [_reg, _cnpj, _fantasia, _razao, _uf, _modalidade, _benef]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final vm = context.read<OperadorasViewModel>();
    final toast = context.read<ToastController>();
    setState(() => _erro = null);
    final benef = int.tryParse(_benef.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    OperadoraModel? res;
    if (_criando) {
      res = await vm.criar(OperadoraModel(
        registroAns: _reg.text.trim(),
        cnpj: _cnpj.text,
        razaoSocial: _razao.text.trim(),
        nomeFantasia: _fantasia.text.trim(),
        uf: _uf.text.trim().toUpperCase(),
        modalidade: _modalidade.text.trim(),
        beneficiarios: benef,
      ));
    } else {
      res = await vm.salvar(_op!, {
        'cnpj': _cnpj.text,
        'razao_social': _razao.text.trim(),
        'nome_fantasia': _fantasia.text.trim(),
        'uf': _uf.text.trim().toUpperCase(),
        'modalidade': _modalidade.text.trim(),
        'beneficiarios': benef,
      });
    }
    if (!mounted) return;
    if (res == null) {
      setState(() => _erro = vm.error);
      return;
    }
    toast.show(_criando ? 'Operadora cadastrada' : 'Operadora atualizada');
    setState(() {
      _op = res;
      _editando = false;
      _preencher();
    });
  }

  Future<void> _alternarStatus() async {
    final vm = context.read<OperadorasViewModel>();
    final toast = context.read<ToastController>();
    final novo = _op!.isInativa ? 'Ativa' : 'Inativa';
    final res = await vm.alterarStatus(_op!, novo);
    if (!mounted) return;
    if (res == null) {
      setState(() => _erro = vm.error);
      return;
    }
    toast.show(novo == 'Inativa' ? 'Operadora inativada' : 'Operadora reativada');
    setState(() => _op = res);
  }

  Future<void> _exportarFicha() async {
    final o = _op!;
    final nome = await Exporter.exportar(
      ExportTable(
        titulo: 'Ficha da operadora · ${o.nomeExibicao}',
        subtitulo: 'Registro ANS ${o.registroAns} · ${o.uf}',
        colunas: const ['Campo', 'Valor'],
        linhas: [
          ['Registro ANS', o.registroAns],
          ['CNPJ', fmtCnpj(o.cnpj)],
          ['Razão social', o.razaoSocial],
          ['Nome fantasia', o.nomeFantasia ?? '—'],
          ['Modalidade', o.modalidade ?? '—'],
          ['UF', o.uf],
          ['Cidade', o.cidade ?? '—'],
          ['Beneficiários', fmtInt(o.beneficiarios)],
          ['Despesas do último trimestre', o.despesaTrimestre == null ? '—' : fmtBi(o.despesaTrimestre!)],
          ['Situação cadastral', o.status],
        ],
      ),
      nomeBase: 'ficha_operadora_${o.registroAns}',
      formato: 'PDF',
    );
    if (mounted) context.read<ToastController>().show('Ficha exportada ($nome)');
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final user = context.watch<AuthViewModel>().currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final formatoData = user?.preferencias.formatoData ?? 'DD/MM/AAAA';
    final saving = context.watch<OperadorasViewModel>().isSaving;
    final o = _op;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.heroBg,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(LucideIcons.building2, size: 22, color: AppColors.mint),
                  ),
                  const Spacer(),
                  AppIconButton(
                    icon: LucideIcons.x,
                    label: 'Fechar',
                    background: Colors.white.withValues(alpha: 0.1),
                    foreground: Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(o == null ? 'Nova operadora' : nomeProprio(o.nomeExibicao),
                  style: AppText.display(20, weight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(o?.razaoSocial ?? 'Cadastro manual de operadora com registro na ANS',
                  style: AppText.sans(14, color: Colors.white.withValues(alpha: 0.7))),
              if (o != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Pill('Reg. ANS ${o.registroAns}', tone: PillTone.lime),
                  const SizedBox(width: 8),
                  Pill(o.uf, background: Colors.white.withValues(alpha: 0.1), foreground: Colors.white),
                ]),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_erro != null) ...[ErrorBox(_erro!), const SizedBox(height: 12)],
              Row(children: [
                Expanded(child: _campo('Registro ANS', _reg, mono: true, editavel: _criando)),
                const SizedBox(width: 12),
                Expanded(child: _campo('CNPJ', _cnpj, mono: true)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _campo('Nome fantasia', _fantasia)),
                const SizedBox(width: 12),
                Expanded(child: _campo('UF', _uf, maxLength: 2)),
              ]),
              const SizedBox(height: 12),
              _campo('Razão social', _razao),
              const SizedBox(height: 12),
              if (_editando) ...[
                Row(children: [
                  Expanded(child: _campo('Modalidade', _modalidade)),
                  const SizedBox(width: 12),
                  Expanded(child: _campo('Beneficiários', _benef, numerico: true)),
                ]),
              ] else if (o != null) ...[
                Row(children: [
                  Expanded(child: _sage('Beneficiários', fmtInt(o.beneficiarios))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sage('Despesas · último trimestre',
                        o.despesaTrimestre == null ? '—' : fmtBi(o.despesaTrimestre!)),
                  ),
                ]),
                const SizedBox(height: 12),
                _linha('Modalidade', ModalidadePill(o.modalidade)),
                const SizedBox(height: 12),
                _linha('Situação cadastral', StatusPill(o.status)),
                if (o.isInativa && o.dataDescredenciamento != null) ...[
                  const SizedBox(height: 12),
                  _linha(
                      'Descredenciada em',
                      Text(fmtData(DateTime.tryParse(o.dataDescredenciamento!), formato: formatoData),
                          style: AppText.sans(14, weight: FontWeight.w600))),
                ],
              ],
              if (!isAdmin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(children: [
                    Icon(LucideIcons.lock, size: 14, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Text('Edição disponível apenas para o perfil Administrador.',
                        style: AppText.sans(12, color: AppColors.caption)),
                  ]),
                ),
              ],
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate100))),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              if (!isAdmin)
                Expanded(
                  child: Text('Modo consulta: edição e exportação disponíveis apenas para o perfil Administrador.',
                      style: AppText.sans(12, color: AppColors.caption)),
                )
              else if (_editando) ...[
                AppButton('Cancelar', variant: ButtonVariant.secondary, onPressed: () {
                  if (_criando) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _editando = false;
                      _erro = null;
                      _preencher();
                    });
                  }
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(_criando ? 'Cadastrar operadora' : 'Salvar alterações',
                      icon: LucideIcons.check,
                      expand: true,
                      loading: saving,
                      loadingLabel: 'Salvando...',
                      onPressed: _salvar),
                ),
              ] else ...[
                AppButton(o!.isInativa ? 'Reativar' : 'Inativar',
                    variant: ButtonVariant.danger,
                    icon: LucideIcons.power,
                    onPressed: saving ? null : _alternarStatus),
                const SizedBox(width: 8),
                AppIconButton(icon: LucideIcons.fileDown, label: 'Exportar ficha (PDF)', onPressed: _exportarFicha),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton('Editar operadora',
                      icon: LucideIcons.pencil, expand: true, onPressed: () => setState(() => _editando = true)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _campo(String label, TextEditingController c,
      {bool mono = false, bool editavel = true, bool numerico = false, int? maxLength}) {
    final editar = _editando && editavel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppText.sans(11, weight: FontWeight.w600, color: AppColors.caption, spacing: 11 * 0.05)),
          const SizedBox(height: 4),
          if (editar)
            SizedBox(
              height: 34,
              child: TextField(
                controller: c,
                style: mono ? AppText.mono(14, weight: FontWeight.w500, color: AppColors.ink) : AppText.sans(14),
                keyboardType: numerico ? TextInputType.number : null,
                inputFormatters: [
                  if (numerico) FilteringTextInputFormatter.digitsOnly,
                  if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.slate200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.slate200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.mint)),
                ),
              ),
            )
          else
            Text(c.text.isEmpty ? '—' : c.text,
                style: mono ? AppText.mono(14, color: AppColors.ink) : AppText.sans(14, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sage(String label, String valor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: AppText.sans(11, weight: FontWeight.w600, color: AppColors.sageMuted, spacing: 11 * 0.05)),
            const SizedBox(height: 2),
            Text(valor, style: AppText.display(18, weight: FontWeight.w700, color: AppColors.sageText)),
          ],
        ),
      );

  Widget _linha(String label, Widget valor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(label, style: AppText.sans(14, color: AppColors.muted)),
          const Spacer(),
          valor,
        ]),
      );
}
