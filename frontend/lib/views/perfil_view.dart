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
import '../viewmodels/painel_viewmodel.dart';
import 'app_shell.dart';
import 'relatorio_drawer.dart';

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
  int? _usuarioCarregadoId;
  bool _confirmarSaida = false;
  bool _saindo = false;
  bool _enviandoFoto = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarDoUsuario();
  }

  void _carregarDoUsuario([UserModel? usuario]) {
    final u = usuario ?? context.read<AuthViewModel>().currentUser;
    if (u == null) return;
    _usuarioCarregadoId = u.id;
    _nome.text = u.nome;
    _email.text = u.email;
    _cargo.text = u.cargo ?? '';
    _telefone.text = u.telefone ?? '';
    _nascimento.text = (u.dataNascimento ?? '').split('T').first;
    _foto = u.foto;
    _prefs = u.preferencias.copyWith(tema: ThemeController.normalizarTema(u.preferencias.tema));
    _erro = null;
  }

  ThemeController? _themeController() {
    try {
      return context.read<ThemeController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  PainelViewModel? _painelVm() {
    try {
      return context.read<PainelViewModel>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  ToastController? _toast() {
    try {
      return context.read<ToastController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _alterarTema(String novoTema) async {
    final normalizado = ThemeController.normalizarTema(novoTema);
    setState(() => _prefs = _prefs.copyWith(tema: normalizado));
    _themeController()?.aplicar(normalizado, persistir: true);
    final vm = context.read<AuthViewModel>();
    final ok = await vm.updateTheme(normalizado);
    if (!mounted || ok) return;
    final msg = vm.errorMessage;
    if (msg != null && msg.isNotEmpty) {
      setState(() => _erro = msg);
      _toast()?.show(msg, error: true);
    }
  }

  @override
  void dispose() {
    for (final c in [_nome, _email, _cargo, _telefone, _nascimento]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    if (_enviandoFoto) return;
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (arquivo == null) return;
    final nome = arquivo.name.toLowerCase();
    final mimeBruto = (arquivo.mimeType ?? '').toLowerCase();
    final mime = mimeBruto == 'image/png' || mimeBruto == 'image/jpeg' || mimeBruto == 'image/webp'
        ? mimeBruto
        : (nome.endsWith('.png')
            ? 'image/png'
            : (nome.endsWith('.jpg') || nome.endsWith('.jpeg')
                ? 'image/jpeg'
                : (nome.endsWith('.webp') ? 'image/webp' : '')));
    if (mime.isEmpty) {
      const msg = 'Use uma imagem JPG, PNG ou WebP.';
      setState(() => _erro = msg);
      _toast()?.show(msg, error: true);
      return;
    }
    final bytes = await arquivo.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      const msg = 'A foto deve ter no máximo 2 MB.';
      setState(() => _erro = msg);
      _toast()?.show(msg, error: true);
      return;
    }
    final anterior = _foto;
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() {
      _erro = null;
      _foto = dataUrl;
      _enviandoFoto = true;
    });

    final vm = context.read<AuthViewModel>();
    final ok = await vm.updatePhoto(dataUrl);
    if (!mounted) return;
    setState(() => _enviandoFoto = false);
    if (ok) {
      _toast()?.show('Foto de perfil atualizada');
    } else {
      final msg = vm.errorMessage ?? 'Não foi possível salvar a foto.';
      setState(() {
        _foto = anterior;
        _erro = msg;
      });
      _toast()?.show(msg, error: true);
    }
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
    final toast = _toast();
    final antes = vm.currentUser;
    final ufAnterior = antes?.preferencias.ufPadrao;
    final triAnterior = antes?.preferencias.trimestrePadrao;
    final temaNormalizado = ThemeController.normalizarTema(_prefs.tema);
    final prefsJson = Map<String, dynamic>.from(_prefs.copyWith(tema: temaNormalizado).toJson())
      ..remove('resumo_semanal')
      ..remove('alerta_novos_dados');
    if (antes != null && !antes.pode('dados.exportar')) {
      prefsJson.remove('formato_exportacao');
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
      final atualizado = vm.currentUser;
      if (atualizado != null) {
        _themeController()?.aplicar(atualizado.preferencias.tema, persistir: true);
        if (atualizado.preferencias.ufPadrao != ufAnterior ||
            atualizado.preferencias.trimestrePadrao != triAnterior) {
          _painelVm()?.aplicarPreferencias(
            ufPadrao: atualizado.preferencias.ufPadrao,
            trimestrePadrao: atualizado.preferencias.trimestrePadrao,
            isAdmin: atualizado.isAdmin,
            forcar: true,
          );
        }
        setState(() => _carregarDoUsuario(atualizado));
      }
      toast?.show('Perfil atualizado');
    } else {
      final msg = vm.errorMessage ?? 'Não foi possível salvar as alterações.';
      setState(() => _erro = msg);
      toast?.show(msg, error: true);
    }
  }

  Future<void> _sair() async {
    if (_saindo) return;
    setState(() => _saindo = true);
    await context.read<AuthViewModel>().logout();
    // O GoRouter já redireciona para /login via refreshListenable; só força se ainda montado fora de /login.
    if (mounted) {
      final router = GoRouter.maybeOf(context);
      if (router != null && router.routeInformationProvider.value.uri.path != '/login') {
        router.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final vm = context.watch<AuthViewModel>();
    final u = vm.currentUser;
    if (u == null) return const SizedBox.shrink();
    if (_usuarioCarregadoId != u.id) {
      _carregarDoUsuario(u);
    }

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
                        setState(() => _carregarDoUsuario(u));
                        _themeController()?.aplicar(u.preferencias.tema, persistir: true);
                        _toast()?.show('Alterações descartadas');
                      }),
                  const SizedBox(width: 8),
                  AppButton('Salvar alterações',
                      icon: LucideIcons.check,
                      loading: vm.isLoading && !_saindo,
                      loadingLabel: 'Salvando...',
                      onPressed: _saindo ? null : _salvar),
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
                  Container(color: AppColors.heroBg),
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
                              border: Border.all(color: AppColors.card, width: 4),
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
                                border: Border.all(color: AppColors.card, width: 4),
                              ),
                              child: _enviandoFoto
                                  ? Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(color: AppColors.primaryBg, shape: BoxShape.circle),
                                      alignment: Alignment.center,
                                      child: const Spinner(size: 16, color: Colors.white),
                                    )
                                  : AppIconButton(
                                      icon: LucideIcons.camera,
                                      label: 'Alterar foto (JPG, PNG ou WebP, até 2 MB)',
                                      background: AppColors.primaryBg,
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
            InfoRow('Último acesso', fmtData(u.ultimoAcesso, formato: _prefs.formatoData, hora: true)),
            const SizedBox(height: 20),
            Divider(height: 1, color: AppColors.slate100),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: _confirmarSaida
                  ? Wrap(spacing: 8, runSpacing: 8, children: [
                      AppButton('Cancelar',
                          size: ButtonSize.sm,
                          variant: ButtonVariant.secondary,
                          onPressed: _saindo ? null : () => setState(() => _confirmarSaida = false)),
                      AppButton('Confirmar saída',
                          size: ButtonSize.sm,
                          variant: ButtonVariant.dangerSolid,
                          icon: LucideIcons.logOut,
                          loading: _saindo,
                          loadingLabel: 'Saindo...',
                          onPressed: _sair),
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
    final podeExportar = u.pode('dados.exportar');
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
        value: ThemeController.normalizarTema(_prefs.tema),
        options: const [('claro', 'Claro'), ('escuro', 'Escuro')],
        onChanged: _alterarTema,
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
              const SizedBox(width: 16),
              Expanded(child: tema),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ufPadrao),
              const SizedBox(width: 16),
              Expanded(child: trimestrePadrao),
            ]),
            const SizedBox(height: 20),
            Divider(height: 1, color: AppColors.slate100),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.isDark ? AppColors.sage : AppColors.sage.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.fileSpreadsheet, size: 18, color: AppColors.mint),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Relatório personalizado (planilha ETL)',
                            style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sageText)),
                        const SizedBox(height: 2),
                        Text(
                          'Exporte planilhas XLSX/CSV robustas construídas diretamente das bases do ETL da ANS (demonstrações, plano de contas, beneficiários, CADOP e lotes), com fórmulas e gráficos.',
                          style: AppText.sans(12, color: AppColors.sageMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  AppButton(
                    'Exportar planilha',
                    icon: LucideIcons.download,
                    onPressed: () => abrirRelatorioPersonalizado(context),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(children: [
              Expanded(child: formatoData),
              const SizedBox(width: 16),
              Expanded(child: tema),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ufPadrao),
              const SizedBox(width: 16),
              Expanded(child: trimestrePadrao),
            ]),
          ],
        ],
      ),
    );
  }
}
