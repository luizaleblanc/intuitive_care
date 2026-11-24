import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../shared/ui/ui.dart';

class PerfilDadosPessoaisCard extends StatelessWidget {
  final TextEditingController nome;
  final TextEditingController email;
  final TextEditingController cargo;
  final TextEditingController telefone;
  final TextEditingController nascimento;
  final VoidCallback onSelecionarData;

  const PerfilDadosPessoaisCard({
    super.key,
    required this.nome,
    required this.email,
    required this.cargo,
    required this.telefone,
    required this.nascimento,
    required this.onSelecionarData,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dados pessoais', style: AppText.cardTitle()),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: LabeledField(label: 'Nome completo', child: PillTextField(controller: nome, label: 'Nome completo'))),
            const SizedBox(width: 16),
            Expanded(
              child: LabeledField(
                label: 'E-mail',
                child: PillTextField(controller: email, label: 'E-mail', keyboardType: TextInputType.emailAddress),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: LabeledField(label: 'Cargo', child: PillTextField(controller: cargo, label: 'Cargo'))),
            const SizedBox(width: 16),
            Expanded(
              child: LabeledField(
                label: 'Telefone',
                child: PillTextField(
                    controller: telefone, label: 'Telefone', hint: '(00) 00000-0000', keyboardType: TextInputType.phone),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: LabeledField(
                label: 'Data de nascimento',
                child: PillTextField(
                  controller: nascimento,
                  label: 'Data de nascimento',
                  hint: 'AAAA-MM-DD',
                  icon: LucideIcons.calendarDays,
                  readOnly: true,
                  onTap: onSelecionarData,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()),
          ]),
        ],
      ),
    );
  }
}
