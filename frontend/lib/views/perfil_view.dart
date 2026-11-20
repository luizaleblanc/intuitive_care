import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/user_model.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'app_shell.dart';

const _ufs = [
  'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', //
  'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO',
];

class PerfilView extends StatefulWidget {
  const PerfilView({super.key});

  @override
  State<PerfilView> createState() => _PerfilViewState();
}

class _PerfilViewState extends State<PerfilView> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _cargo = TextEditingController();
  final _telefone = TextEditingController();
  final _nascimento = TextEditingController();
  String? _foto;
  late PreferenciasModel _prefs;
  bool _confirmarSaida = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarDoUsuario();
  }

  void _carregarDoUsuario() {
    final u = context.read<AuthViewModel>().currentUser!;
    _nome.text = u.nome;
    _email.text = u.email;
    _cargo.text = u.cargo ?? '';
    _telefone.text = u.telefone ?? '';
    _nascimento.text = (u.dataNascimento ?? '').split('T').first;
    _foto = u.foto;
    _prefs = u.preferencias;
    _erro = null;
  }

  @override
  void dispose() {
    for (final c in [_nome, _email, _cargo, _telefone, _nascimento]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    final arquivo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (arquivo == null) return;
    final nome = arquivo.name.toLowerCase();
    final mime = arquivo.mimeType ??
        (nome.endsWith('.png') ? 'image/png' : (nome.endsWith('.jpg') || nome.endsWith('.jpeg') ? 'image/jpeg' : ''));
    if (mime != 'image/png' && mime != 'image/jpeg') {
      setState(() => _erro = 'Use uma imagem JPG ou PNG.');
      return;
    }
    final bytes = await arquivo.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      setState(() => _erro = 'A foto deve ter no máximo 2 MB.');
      return;
    }
    setState(() {
      _erro = null;
      _foto = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _selecionarData() async {
    final atual = DateTime.tryParse(_nascimento.text);
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime(1995),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida != null) {
      _nascimento.text =
          '${escolhida.year}-${escolhida.month.toString().padLeft(2, '0')}-${escolhida.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _salvar() async {
    final vm = context.read<AuthViewModel>();
    final toast = context.read<ToastController>();
    final u = vm.currentUser;
    final prefsJson = Map<String, dynamic>.from(_prefs.toJson());
    if (u != null && !u.isAdmin) {
      prefsJson
        ..remove('formato_exportacao')
        ..remove('resumo_semanal')
        ..remove('alerta_novos_dados');
    }
    setState(() => _erro = null);
    final ok = await vm.updateProfile({
      'nome': _nome.text,
      'email': _email.text,
      'cargo': _cargo.text,
      'telefone': _telefone.text,
      'data_nascimento': _nascimento.text,
      'foto': _foto,
      'preferencias': prefsJson,
    });
    if (!mounted) return;
    if (ok) {
      toast.show('Perfil atualizado');
    } else {
      setState(() => _erro = vm.errorMessage);
    }
  }

  Future<void> _sair() async {
    await context.read<AuthViewModel>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final u = vm.currentUser;
    if (u == null) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _identidade(u),
              const SizedBox(height: AppLayout.gutter),
              _conta(u),
            ],
          ),
        ),
        const SizedBox(width: AppLayout.gutter),
        Expanded(
          flex: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_erro != null) ...[ErrorBox(_erro!), const SizedBox(height: 16)],
              _dadosPessoais(),
              const SizedBox(height: AppLayout.gutter),
              _preferencias(u),
              const SizedBox(height: AppLayout.gutter),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton('Cancelar',
                      variant: ButtonVariant.secondary,
                      onPressed: () {
                        setState(_carregarDoUsuario);
                        context.read<ToastController>().show('Alterações descartadas');
                      }),
                  const SizedBox(width: 8),
                  AppButton('Salvar alterações',
                      icon: LucideIcons.check, loading: vm.isLoading, loadingLabel: 'Salvando...', onPressed: _salvar),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _identidade(UserModel u) => AppCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 96,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Container(color: AppColors.forest),
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.15), shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -48),
                    child: SizedBox(
                      width: 104,
                      height: 104,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Avatar(
                              nome: _nome.text.isEmpty ? u.nome : _nome.text,
                              foto: _foto,
                              size: 96,
                              radius: 24,
                              bg: AppColors.mint,
                              fg: AppColors.forest,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: AppIconButton(
                                icon: LucideIcons.camera,
                                label: 'Alterar foto (JPG ou PNG, até 2 MB)',
                                background: AppColors.forest,
                                foreground: Colors.white,
                                onPressed: _escolherFoto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.nome, style: AppText.display(24, weight: FontWeight.w700)),
                        Text(u.cargo?.isNotEmpty == true ? u.cargo! : 'Cargo não informado',
                            style: AppText.sans(14, color: AppColors.muted)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          Pill('ID #${u.id}', tone: PillTone.sage),
                          Pill(u.perfil, tone: u.isAdmin ? PillTone.forest : PillTone.sage),
                          const Pill('Sessão ativa', tone: PillTone.ok, dot: true),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _conta(UserModel u) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Conta', style: AppText.display(15, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            InfoRow('Membro desde', fmtMesAno(u.membroDesde)),
            const SizedBox(height: 8),
            InfoRow('Último acesso', fmtData(u.ultimoAcesso, formato: u.preferencias.formatoData, hora: true)),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.slate100),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: _confirmarSaida
                  ? Row(children: [
                      AppButton('Cancelar',
                          size: ButtonSize.sm,
                          variant: ButtonVariant.secondary,
                          onPressed: () => setState(() => _confirmarSaida = false)),
                      const SizedBox(width: 8),
                      AppButton('Confirmar saída',
                          size: ButtonSize.sm, variant: ButtonVariant.dangerSolid, icon: LucideIcons.logOut, onPressed: _sair),
                    ])
                  : AppButton('Encerrar sessão',
                      size: ButtonSize.sm,
                      variant: ButtonVariant.danger,
                      icon: LucideIcons.logOut,
                      onPressed: () => setState(() => _confirmarSaida = true)),
            ),
          ],
        ),
      );

  Widget _dadosPessoais() => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dados pessoais', style: AppText.cardTitle()),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: LabeledField(label: 'Nome completo', child: PillTextField(controller: _nome, label: 'Nome completo'))),
              const SizedBox(width: 16),
              Expanded(
                child: LabeledField(
                  label: 'E-mail',
                  child: PillTextField(controller: _email, label: 'E-mail', keyboardType: TextInputType.emailAddress),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: LabeledField(label: 'Cargo', child: PillTextField(controller: _cargo, label: 'Cargo'))),
              const SizedBox(width: 16),
              Expanded(
                child: LabeledField(
                  label: 'Telefone',
                  child: PillTextField(
                      controller: _telefone, label: 'Telefone', hint: '(00) 00000-0000', keyboardType: TextInputType.phone),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: LabeledField(
                  label: 'Data de nascimento',
                  child: PillTextField(
                    controller: _nascimento,
                    label: 'Data de nascimento',
                    hint: 'AAAA-MM-DD',
                    icon: LucideIcons.calendarDays,
                    readOnly: true,
                    onTap: _selecionarData,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ]),
          ],
        ),
      );

  Widget _preferencias(UserModel u) {
    Widget campo(String label, Widget child) => LabeledField(label: label, child: child);
    final isAdmin = u.isAdmin;
    final podeExportar = u.pode('dados.exportar');
    final idioma = campo(
      'Idioma',
      AppSelect<String>(
        semanticLabel: 'Idioma',
        icon: LucideIcons.languages,
        width: double.infinity,
        value: _prefs.idioma,
        options: const [('pt-BR', 'Português (Brasil)'), ('en', 'English'), ('es', 'Español')],
        onChanged: (v) => setState(() => _prefs = _prefs.copyWith(idioma: v)),
      ),
    );
    final formatoData = campo(
      'Formato de data',
      AppSelect<String>(
        semanticLabel: 'Formato de data',
        icon: LucideIcons.calendarDays,
        width: double.infinity,
        value: _prefs.formatoData,
        options: const [('DD/MM/AAAA', 'DD/MM/AAAA'), ('AAAA-MM-DD', 'AAAA-MM-DD')],
        onChanged: (v) => setState(() => _prefs = _prefs.copyWith(formatoData: v)),
      ),
    );
    final ufPadrao = campo(
      'UF padrão',
      AppSelect<String>(
        semanticLabel: 'UF padrão',
        icon: LucideIcons.mapPin,
        width: double.infinity,
        value: _prefs.ufPadrao ?? '',
        options: [('', 'Todas UFs'), for (final uf in _ufs) (uf, uf)],
        onChanged: (v) => setState(() => _prefs = _prefs.copyWith(ufPadrao: () => v.isEmpty ? null : v)),
      ),
    );
    final trimestrePadrao = campo(
      'Trimestre padrão',
      AppSelect<int>(
        semanticLabel: 'Trimestre padrão',
        icon: LucideIcons.calendar,
        width: double.infinity,
        value: _prefs.trimestrePadrao,
        options: [for (final t in [1, 2, 3, 4]) (t, fmtTrimestre(t))],
        onChanged: (v) => setState(() => _prefs = _prefs.copyWith(trimestrePadrao: v)),
      ),
    );
    final tema = campo(
      'Tema',
      SegmentedPill<String>(
        value: _prefs.tema,
        options: const [('claro', 'Claro'), ('escuro', 'Escuro'), ('sistema', 'Sistema')],
        onChanged: (v) => setState(() => _prefs = _prefs.copyWith(tema: v)),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Preferências', style: AppText.cardTitle()),
          const SizedBox(height: 20),
          if (podeExportar) ...[
            Row(children: [
              Expanded(child: idioma),
              const SizedBox(width: 16),
              Expanded(child: formatoData),
              const SizedBox(width: 16),
              Expanded(
                child: campo(
                  'Exportar como',
                  AppSelect<String>(
                    semanticLabel: 'Exportar como',
                    icon: LucideIcons.fileDown,
                    width: double.infinity,
                    value: _prefs.formatoExportacao,
                    options: const [('CSV', 'CSV'), ('PDF', 'PDF'), ('XLSX', 'XLSX')],
                    onChanged: (v) => setState(() => _prefs = _prefs.copyWith(formatoExportacao: v)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ufPadrao),
              const SizedBox(width: 16),
              Expanded(child: trimestrePadrao),
              const SizedBox(width: 16),
              Expanded(child: tema),
            ]),
          ] else ...[
            Row(children: [
              Expanded(child: idioma),
              const SizedBox(width: 16),
              Expanded(child: formatoData),
              const SizedBox(width: 16),
              Expanded(child: tema),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ufPadrao),
              const SizedBox(width: 16),
              Expanded(child: trimestrePadrao),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ]),
          ],
          if (isAdmin) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.slate100),
            ToggleRow(
              on: _prefs.resumoSemanal,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(resumoSemanal: v)),
              label: 'Resumo semanal por e-mail',
              desc: 'Principais variações de despesas toda segunda-feira',
            ),
            const Divider(height: 1, color: AppColors.slate100),
            ToggleRow(
              on: _prefs.alertaNovosDados,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(alertaNovosDados: v)),
              label: 'Avisar quando houver novos dados da ANS',
              desc: 'Notificação quando um novo trimestre for publicado',
            ),
          ],
        ],
      ),
    );
  }
}
