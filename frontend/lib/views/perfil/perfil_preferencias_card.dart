import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import '../relatorio_drawer.dart';

const _ufs = [
  'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', //
  'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO',
];

class PerfilPreferenciasCard extends StatelessWidget {
  final UserModel usuario;
  final PreferenciasModel prefs;
  final ValueChanged<PreferenciasModel> onPrefsChanged;
  final ValueChanged<String> onTemaChanged;

  const PerfilPreferenciasCard({
    super.key,
    required this.usuario,
    required this.prefs,
    required this.onPrefsChanged,
    required this.onTemaChanged,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    Widget campo(String label, Widget child) => LabeledField(label: label, child: child);
    final podeExportar = usuario.pode('dados.exportar');
    final formatoData = campo(
      'Formato de data',
      AppSelect<String>(
        semanticLabel: 'Formato de data',
        icon: LucideIcons.calendarDays,
        width: double.infinity,
        value: prefs.formatoData,
        options: const [('DD/MM/AAAA', 'DD/MM/AAAA'), ('AAAA-MM-DD', 'AAAA-MM-DD')],
        onChanged: (v) => onPrefsChanged(prefs.copyWith(formatoData: v)),
      ),
    );
    final ufPadrao = campo(
      'UF padrão',
      AppSelect<String>(
        semanticLabel: 'UF padrão',
        icon: LucideIcons.mapPin,
        width: double.infinity,
        value: prefs.ufPadrao ?? '',
        options: [('', 'Todas UFs'), for (final uf in _ufs) (uf, uf)],
        onChanged: (v) => onPrefsChanged(prefs.copyWith(ufPadrao: () => v.isEmpty ? null : v)),
      ),
    );
    final trimestrePadrao = campo(
      'Trimestre padrão',
      AppSelect<int>(
        semanticLabel: 'Trimestre padrão',
        icon: LucideIcons.calendar,
        width: double.infinity,
        value: prefs.trimestrePadrao,
        options: [for (final t in [1, 2, 3, 4]) (t, fmtTrimestre(t))],
        onChanged: (v) => onPrefsChanged(prefs.copyWith(trimestrePadrao: v)),
      ),
    );
    final tema = campo(
      'Tema',
      SegmentedPill<String>(
        value: ThemeController.normalizarTema(prefs.tema),
        options: const [('claro', 'Claro'), ('escuro', 'Escuro')],
        onChanged: onTemaChanged,
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
                    value: prefs.formatoExportacao,
                    options: const [('CSV', 'CSV'), ('PDF', 'PDF'), ('XLSX', 'XLSX')],
                    onChanged: (v) => onPrefsChanged(prefs.copyWith(formatoExportacao: v)),
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
