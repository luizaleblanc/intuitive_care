import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/operadora_model.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/operadora_viewmodel.dart';
import '../widgets/app_error_banner.dart';

class OperadoraFormView extends StatefulWidget {
  final OperadoraModel? operadora;

  const OperadoraFormView({super.key, this.operadora});

  @override
  State<OperadoraFormView> createState() => _OperadoraFormViewState();
}

class _OperadoraFormViewState extends State<OperadoraFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _registroAnsCtrl;
  late final TextEditingController _cnpjCtrl;
  late final TextEditingController _razaoSocialCtrl;
  late final TextEditingController _nomeFantasiaCtrl;
  late final TextEditingController _modalidadeCtrl;
  late final TextEditingController _cidadeCtrl;
  late final TextEditingController _ufCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _telefoneCtrl;

  bool get _isEditing => widget.operadora != null;

  @override
  void initState() {
    super.initState();
    final op = widget.operadora;
    _registroAnsCtrl = TextEditingController(text: op?.registroAns ?? '');
    _cnpjCtrl = TextEditingController(text: op?.cnpj ?? '');
    _razaoSocialCtrl = TextEditingController(text: op?.razaoSocial ?? '');
    _nomeFantasiaCtrl = TextEditingController(text: op?.nomeFantasia ?? '');
    _modalidadeCtrl = TextEditingController(text: op?.modalidade ?? 'Medicina de Grupo');
    _cidadeCtrl = TextEditingController(text: op?.cidade ?? '');
    _ufCtrl = TextEditingController(text: op?.uf ?? '');
    _emailCtrl = TextEditingController(text: op?.email ?? '');
    _telefoneCtrl = TextEditingController(text: op?.telefone ?? '');
  }

  @override
  void dispose() {
    _registroAnsCtrl.dispose();
    _cnpjCtrl.dispose();
    _razaoSocialCtrl.dispose();
    _nomeFantasiaCtrl.dispose();
    _modalidadeCtrl.dispose();
    _cidadeCtrl.dispose();
    _ufCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final opVm = context.read<OperadoraViewModel>();
    final dashVm = context.read<DashboardViewModel>();

    final existing = widget.operadora;
    final model = OperadoraModel(
      registroAns: _registroAnsCtrl.text.trim(),
      cnpj: _cnpjCtrl.text.trim(),
      razaoSocial: _razaoSocialCtrl.text.trim(),
      nomeFantasia: _nomeFantasiaCtrl.text.trim(),
      modalidade: _modalidadeCtrl.text.trim(),
      logradouro: existing?.logradouro,
      numero: existing?.numero,
      complemento: existing?.complemento,
      bairro: existing?.bairro,
      cidade: _cidadeCtrl.text.trim(),
      uf: _ufCtrl.text.trim().toUpperCase(),
      cep: existing?.cep,
      telefone: _telefoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      representante: existing?.representante,
      cargoRepresentante: existing?.cargoRepresentante,
    );

    final ok = _isEditing
        ? await opVm.updateOperadora(widget.operadora!.registroAns, model)
        : await opVm.createOperadora(model);

    if (ok && mounted) {
      dashVm.loadDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Operadora atualizada com sucesso!' : 'Operadora cadastrada com sucesso!',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opVm = context.watch<OperadoraViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Operadora' : 'Cadastrar Operadora'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (opVm.errorMessage != null)
                    AppErrorBanner(
                      message: opVm.errorMessage!,
                      onDismiss: opVm.clearError,
                    ),
                  TextFormField(
                    controller: _registroAnsCtrl,
                    enabled: !_isEditing,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Registro ANS *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 4) ? 'Informe o Registro ANS (4-20 dígitos).' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cnpjCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'CNPJ (14 dígitos) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 14) return 'CNPJ deve ter 14 dígitos.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _razaoSocialCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Razão Social *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().length < 3) ? 'Informe a Razão Social.' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nomeFantasiaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome Fantasia',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _modalidadeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Modalidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _cidadeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Cidade',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _ufCtrl,
                          maxLength: 2,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'UF *',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length != 2) ? 'UF inválida' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail institucional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _telefoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: opVm.isSubmitting ? null : _submit,
                    icon: const Icon(Icons.save),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(opVm.isSubmitting ? 'Salvando...' : 'Salvar Operadora'),
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
