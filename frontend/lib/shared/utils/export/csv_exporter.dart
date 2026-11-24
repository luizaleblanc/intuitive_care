import 'dart:convert';
import 'dart:typed_data';

import 'export_table.dart';

final _rePrecisaAspas = RegExp(r'[;"\n]');

String _escaparCsv(String valor) =>
    valor.contains(_rePrecisaAspas) ? '"${valor.replaceAll('"', '""')}"' : valor;

void _escreverTabelaCsv(StringBuffer buffer, ExportTable tabela) {
  buffer.writeln(tabela.colunas.map(_escaparCsv).join(';'));
  for (final linha in tabela.linhas) {
    buffer.writeln(linha.map(_escaparCsv).join(';'));
  }
}

/// Gera os bytes `.csv` UTF-8 BOM para uma tabela única.
Uint8List gerarCsv(ExportTable tabela) {
  final buffer = StringBuffer('\uFEFF');
  _escreverTabelaCsv(buffer, tabela);
  return Uint8List.fromList(utf8.encode(buffer.toString()));
}

/// Gera os bytes `.csv` UTF-8 BOM multi-seção.
Uint8List gerarCsvMulti(
  List<ExportTable> abas, {
  String? tituloGeral,
  String? subtituloGeral,
}) {
  final buffer = StringBuffer('\uFEFF');
  if (tituloGeral != null && tituloGeral.isNotEmpty) {
    buffer.writeln(_escaparCsv(tituloGeral));
  }
  if (subtituloGeral != null && subtituloGeral.isNotEmpty) {
    buffer.writeln(_escaparCsv(subtituloGeral));
  }
  for (var i = 0; i < abas.length; i++) {
    final t = abas[i];
    if (i > 0 || tituloGeral != null) buffer.writeln();
    buffer.writeln(_escaparCsv(t.titulo));
    if (t.subtitulo case final sub? when sub.isNotEmpty) {
      buffer.writeln(_escaparCsv(sub));
    }
    _escreverTabelaCsv(buffer, t);
  }
  return Uint8List.fromList(utf8.encode(buffer.toString()));
}
