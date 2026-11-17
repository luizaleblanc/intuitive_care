import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/app_error_banner.dart';

/// Exibe as informações do usuário autenticado retornadas pela API Flask e permite logout.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nomeController = TextEditingController();
  bool _editingName = false;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuário Autenticado'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar com API',
            icon: const Icon(Icons.sync),
            onPressed: authVm.refreshProfile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (authVm.errorMessage != null)
            AppErrorBanner(
              message: authVm.errorMessage!,
              onDismiss: authVm.clearMessages,
            ),
          if (user != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user.nome.isNotEmpty ? user.nome[0].toUpperCase() : 'U',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!_editingName) ...[
                      Text(
                        user.nome,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('ID #${user.id ?? '-'}')),
                          Chip(label: Text('Perfil: ${user.perfil}')),
                          Chip(label: Text(user.ativo ? 'Sessão Ativa' : 'Inativo')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          _nomeController.text = user.nome;
                          setState(() => _editingName = true);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar Nome'),
                      ),
                    ] else ...[
                      TextField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _editingName = false),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: authVm.isLoading
                                ? null
                                : () async {
                                    final ok = await authVm.updateProfile(nome: _nomeController.text);
                                    if (ok && mounted) {
                                      setState(() => _editingName = false);
                                    }
                                  },
                            child: const Text('Salvar'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
            ),
            child: ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Endpoint da API Flask'),
              subtitle: Text(ApiConfig.baseUrl),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: authVm.isLoading ? null : authVm.logout,
            icon: const Icon(Icons.logout),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Encerrar Sessão (Logout)'),
            ),
          ),
        ],
      ),
    );
  }
}
