import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/despesa_model.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/despesa_viewmodel.dart';
import '../viewmodels/operadora_viewmodel.dart';
import '../widgets/app_error_banner.dart';

class DespesaFormView extends StatefulWidget {
  final DespesaModel? despesa;
  final String? initialRegAns;

  const DespesaFormView({super.key, this.despesa, this.initialRegAns});

  @override
  State<DespesaFormView> createState() => _DespesaFormViewState();
}

class _DespesaFormViewState extends State<DespesaFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _regAnsCtrl;
  late final TextEditingController _anoCtrl;
  late int _trimestre;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _categoriaCtrl;
  late final TextEditingController _descricaoCtrl;

  bool get _isEditing => widget.despesa != null;

  @override
  void initState() {
    super.initState();
    final d = widget.despesa;
    _regAnsCtrl = TextEditingController(text: d?.regAns ?? widget.initialRegAns ?? '');
    _anoCtrl = TextEditingController(text: (d?.ano ?? DateTime.now().year).toString());
    _trimestre = d?.trimestre ?? 1;
    _valorCtrl = TextEditingController(
      text: d != null ? d.valorDespesa.toStringAsFixed(2) : '',
    );
    _categoriaCtrl = TextEditingController(text: d?.categoria ?? 'Despesa Assistencial');
    _descricaoCtrl = TextEditingController(text: d?.descricao ?? '');
  }

  @override
  void dispose() {
    _regAnsCtrl.dispose();
    _anoCtrl.dispose();
    _valorCtrl.dispose();
    _categoriaCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final despVm = context.read<DespesaViewModel>();
    final dashVm = context.read<DashboardViewModel>();
    final opVm = context.read<OperadoraViewModel>();

    final parsedValor = double.parse(_valorCtrl.text.trim().replaceAll(',', '.'));
    final model = DespesaModel(
      id: widget.despesa?.id,
      regAns: _regAnsCtrl.text.trim(),
      ano: int.parse(_anoCtrl.text.trim()),
      trimestre: _trimestre,
      valorDespesa: parsedValor,
      categoria: _categoriaCtrl.text.trim(),
      descricao: _descricaoCtrl.text.trim(),
    );

    final ok = _isEditing
        ? await despVm.updateDespesa(widget.despesa!.id!, model)
        : await despVm.createDespesa(model);

    if (ok && mounted) {
      dashVm.loadDashboard();
      opVm.loadOperadoras();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Despesa atualizada!' : 'Despesa lançada com sucesso!'),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final despVm = context.watch<DespesaViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Despesa' : 'Lançar Despesa'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (despVm.errorMessage != null)
                    AppErrorBanner(
                      message: despVm.errorMessage!,
                      onDismiss: despVm.clearError,
                    ),
                  TextFormField(
                    controller: _regAnsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Registro ANS da Operadora *',
                      hintText: 'Ex: 359017',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().length < 4) ? 'Informe o Registro ANS.' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _anoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ano *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final y = int.tryParse(v ?? '');
                            if (y == null || y < 2000) return 'Ano inválido.';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _trimestre,
                          decoration: const InputDecoration(
                            labelText: 'Trimestre *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1º Trimestre')),
                            DropdownMenuItem(value: 2, child: Text('2º Trimestre')),
                            DropdownMenuItem(value: 3, child: Text('3º Trimestre')),
                            DropdownMenuItem(value: 4, child: Text('4º Trimestre')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _trimestre = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _valorCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor da Despesa (R\$) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final numVal = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (numVal == null || numVal <= 0) return 'Informe um valor maior que zero.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _categoriaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Categoria Contábil',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descricaoCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descrição / Observação',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: despVm.isSubmitting ? null : _submit,
                    icon: const Icon(Icons.save),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(despVm.isSubmitting ? 'Salvando...' : 'Salvar Despesa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
