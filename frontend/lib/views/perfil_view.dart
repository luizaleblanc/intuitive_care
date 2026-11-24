import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/user_model.dart';
import '../shared/ui/ui.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/painel_viewmodel.dart';
import 'perfil/perfil_dados_pessoais_card.dart';
import 'perfil/perfil_identidade_card.dart';
import 'perfil/perfil_preferencias_card.dart';

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
    final toast = _toast();
    final ok = await vm.updateTheme(normalizado);
    if (!mounted || ok) return;
    final msg = vm.errorMessage;
    if (msg != null && msg.isNotEmpty) {
      setState(() => _erro = msg);
      toast?.show(msg, error: true);
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
    final vm = context.read<AuthViewModel>();
    final toast = _toast();
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (!mounted || arquivo == null) return;
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
      toast?.show(msg, error: true);
      return;
    }
    final bytes = await arquivo.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 2 * 1024 * 1024) {
      const msg = 'A foto deve ter no máximo 2 MB.';
      setState(() => _erro = msg);
      toast?.show(msg, error: true);
      return;
    }
    final anterior = _foto;
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() {
      _erro = null;
      _foto = dataUrl;
      _enviandoFoto = true;
    });

    final ok = await vm.updatePhoto(dataUrl);
    if (!mounted) return;
    setState(() => _enviandoFoto = false);
    if (ok) {
      toast?.show('Foto de perfil atualizada');
    } else {
      final msg = vm.errorMessage ?? 'Não foi possível salvar a foto.';
      setState(() {
        _foto = anterior;
        _erro = msg;
      });
      toast?.show(msg, error: true);
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
    if (!mounted) return;
    if (escolhida != null) {
      _nascimento.text =
          '${escolhida.year}-${escolhida.month.toString().padLeft(2, '0')}-${escolhida.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _salvar() async {
    final vm = context.read<AuthViewModel>();
    final toast = _toast();
    final theme = _themeController();
    final painelVm = _painelVm();
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
        theme?.aplicar(atualizado.preferencias.tema, persistir: true);
        if (atualizado.preferencias.ufPadrao != ufAnterior ||
            atualizado.preferencias.trimestrePadrao != triAnterior) {
          painelVm?.aplicarPreferencias(
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
              PerfilIdentidadeCard(
                usuario: u,
                nomeAtual: _nome.text,
                foto: _foto,
                enviandoFoto: _enviandoFoto,
                onEscolherFoto: _escolherFoto,
              ),
              const SizedBox(height: AppLayout.gutter),
              PerfilContaCard(
                usuario: u,
                formatoData: _prefs.formatoData,
                confirmarSaida: _confirmarSaida,
                saindo: _saindo,
                onPedirConfirmacao: () => setState(() => _confirmarSaida = true),
                onCancelarSaida: () => setState(() => _confirmarSaida = false),
                onConfirmarSaida: _sair,
              ),
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
              PerfilDadosPessoaisCard(
                nome: _nome,
                email: _email,
                cargo: _cargo,
                telefone: _telefone,
                nascimento: _nascimento,
                onSelecionarData: _selecionarData,
              ),
              const SizedBox(height: AppLayout.gutter),
              PerfilPreferenciasCard(
                usuario: u,
                prefs: _prefs,
                onPrefsChanged: (p) => setState(() => _prefs = p),
                onTemaChanged: _alterarTema,
              ),
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
}
