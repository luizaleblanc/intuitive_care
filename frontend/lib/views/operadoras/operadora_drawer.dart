import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/operadora_model.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/exporter.dart';
import '../../shared/utils/formatters.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/operadoras_viewmodel.dart';
import 'operadora_drawer_widgets.dart';

// ---------------------------------------------------------------------------
// Gaveta de detalhes / edição / criação de operadora
// ---------------------------------------------------------------------------
class OperadoraDrawer extends StatefulWidget {
  final OperadoraModel? operadora;
  const OperadoraDrawer({super.key, this.operadora});

  @override
  State<OperadoraDrawer> createState() => _OperadoraDrawerState();
}

class _OperadoraDrawerState extends State<OperadoraDrawer> {
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
        OperadoraDrawerHeader(operadora: o, onClose: () => Navigator.of(context).pop()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_erro != null) ...[ErrorBox(_erro!), const SizedBox(height: 12)],
              Row(children: [
                Expanded(child: OperadoraCampoBox(label: 'Registro ANS', controller: _reg, mono: true, editavel: _editando && _criando)),
                const SizedBox(width: 12),
                Expanded(child: OperadoraCampoBox(label: 'CNPJ', controller: _cnpj, mono: true, editavel: _editando)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OperadoraCampoBox(label: 'Nome fantasia', controller: _fantasia, editavel: _editando)),
                const SizedBox(width: 12),
                Expanded(child: OperadoraCampoBox(label: 'UF', controller: _uf, maxLength: 2, editavel: _editando)),
              ]),
              const SizedBox(height: 12),
              OperadoraCampoBox(label: 'Razão social', controller: _razao, editavel: _editando),
              const SizedBox(height: 12),
              if (_editando) ...[
                Row(children: [
                  Expanded(child: OperadoraCampoBox(label: 'Modalidade', controller: _modalidade, editavel: true)),
                  const SizedBox(width: 12),
                  Expanded(child: OperadoraCampoBox(label: 'Beneficiários', controller: _benef, numerico: true, editavel: true)),
                ]),
              ] else if (o != null) ...[
                Row(children: [
                  Expanded(child: OperadoraSageCard(label: 'Beneficiários', valor: fmtInt(o.beneficiarios))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OperadoraSageCard(
                      label: 'Despesas · último trimestre',
                      valor: o.despesaTrimestre == null ? '—' : fmtBi(o.despesaTrimestre!),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                OperadoraInfoLinha(label: 'Modalidade', valor: ModalidadePill(o.modalidade)),
                const SizedBox(height: 12),
                OperadoraInfoLinha(label: 'Situação cadastral', valor: StatusPill(o.status)),
                if (o.isInativa && o.dataDescredenciamento != null) ...[
                  const SizedBox(height: 12),
                  OperadoraInfoLinha(
                    label: 'Descredenciada em',
                    valor: Text(fmtData(DateTime.tryParse(o.dataDescredenciamento!), formato: formatoData),
                        style: AppText.sans(14, weight: FontWeight.w600)),
                  ),
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
}
