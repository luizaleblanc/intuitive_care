import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'browser.dart';

export 'browser.dart' show abrirNovaAba;

/// Tabela genérica para exportação (relatórios, listas e fichas).
class ExportTable {
  final String titulo;
  final String? subtitulo;
  final List<String> colunas;
  final List<List<String>> linhas;

  const ExportTable({required this.titulo, this.subtitulo, required this.colunas, required this.linhas});
}

/// Gera o arquivo no formato escolhido nas preferências (CSV, PDF ou XLSX) e inicia o download.
class Exporter {
  static Future<String> exportar(ExportTable tabela, {required String nomeBase, String formato = 'CSV'}) async {
    final f = formato.toUpperCase();
    late final Uint8List bytes;
    late final String mime;
    late final String ext;
    switch (f) {
      case 'PDF':
        bytes = await _pdf(tabela);
        mime = 'application/pdf';
        ext = 'pdf';
      case 'XLSX':
        bytes = _xlsx(tabela);
        mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        ext = 'xlsx';
      default:
        bytes = _csv(tabela);
        mime = 'text/csv;charset=utf-8';
        ext = 'csv';
    }
    final nome = '$nomeBase.$ext';
    baixarArquivo(bytes, nome, mime);
    return nome;
  }

  /// Exporta um relatório conciso com múltiplas abas/seções (XLSX multi-aba, CSV ou PDF).
  static Future<String> exportarRelatorio(
    List<ExportTable> abas, {
    required String nomeBase,
    String formato = 'XLSX',
    String? tituloGeral,
    String? subtituloGeral,
  }) async {
    assert(abas.isNotEmpty);
    final f = formato.toUpperCase();
    late final Uint8List bytes;
    late final String mime;
    late final String ext;
    switch (f) {
      case 'PDF':
        bytes = await _pdfMulti(abas, tituloGeral: tituloGeral, subtituloGeral: subtituloGeral);
        mime = 'application/pdf';
        ext = 'pdf';
      case 'CSV':
        bytes = _csvMulti(abas, tituloGeral: tituloGeral, subtituloGeral: subtituloGeral);
        mime = 'text/csv;charset=utf-8';
        ext = 'csv';
      default:
        bytes = _xlsxMulti(abas);
        mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        ext = 'xlsx';
    }
    final nome = '$nomeBase.$ext';
    baixarArquivo(bytes, nome, mime);
    return nome;
  }

  static String _nomeAbaSeguro(String bruto, Set<String> usadas) {
    var limpo = bruto.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (limpo.isEmpty) limpo = 'Planilha';
    if (limpo.length > 31) limpo = limpo.substring(0, 31).trim();
    var nome = limpo;
    var n = 2;
    while (usadas.contains(nome)) {
      final sufixo = ' ($n)';
      final base = limpo.length + sufixo.length > 31 ? limpo.substring(0, 31 - sufixo.length).trim() : limpo;
      nome = '$base$sufixo';
      n++;
    }
    usadas.add(nome);
    return nome;
  }

  static Uint8List _csv(ExportTable t) {
    String esc(String v) => v.contains(RegExp(r'[;"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln(t.colunas.map(esc).join(';'));
    for (final l in t.linhas) {
      buffer.writeln(l.map(esc).join(';'));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static Uint8List _csvMulti(List<ExportTable> abas, {String? tituloGeral, String? subtituloGeral}) {
    String esc(String v) => v.contains(RegExp(r'[;"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final buffer = StringBuffer('\uFEFF');
    if (tituloGeral != null && tituloGeral.isNotEmpty) buffer.writeln(esc(tituloGeral));
    if (subtituloGeral != null && subtituloGeral.isNotEmpty) buffer.writeln(esc(subtituloGeral));
    for (var i = 0; i < abas.length; i++) {
      final t = abas[i];
      if (i > 0 || tituloGeral != null) buffer.writeln();
      buffer.writeln(esc(t.titulo));
      if (t.subtitulo != null && t.subtitulo!.isNotEmpty) buffer.writeln(esc(t.subtitulo!));
      buffer.writeln(t.colunas.map(esc).join(';'));
      for (final l in t.linhas) {
        buffer.writeln(l.map(esc).join(';'));
      }
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static Uint8List _xlsx(ExportTable t) => _xlsxMulti([t]);

  static Uint8List _xlsxMulti(List<ExportTable> abas) {
    final excel = Excel.createExcel();
    final padrao = excel.getDefaultSheet()!;
    final usadas = <String>{};
    for (var i = 0; i < abas.length; i++) {
      final t = abas[i];
      final nomeAba = _nomeAbaSeguro(t.titulo, usadas);
      if (i == 0) {
        excel.rename(padrao, nomeAba);
      }
      final sheet = excel[nomeAba];
      if (t.subtitulo != null && t.subtitulo!.isNotEmpty) {
        sheet.appendRow([TextCellValue(t.titulo)]);
        sheet.appendRow([TextCellValue(t.subtitulo!)]);
        sheet.appendRow([TextCellValue('')]);
      }
      sheet.appendRow(t.colunas.map((c) => TextCellValue(c)).toList());
      for (final l in t.linhas) {
        sheet.appendRow(l.map((v) => TextCellValue(v)).toList());
      }
    }
    return Uint8List.fromList(excel.encode()!);
  }

  static Future<Uint8List> _pdf(ExportTable t) =>
      _pdfMulti([t], tituloGeral: t.titulo, subtituloGeral: t.subtitulo);

  static Future<Uint8List> _pdfMulti(List<ExportTable> abas, {String? tituloGeral, String? subtituloGeral}) async {
    const forest = PdfColor.fromInt(0xFF113E32);
    const sage = PdfColor.fromInt(0xFFDCE7E2);
    final titulo = tituloGeral ?? abas.first.titulo;
    final subtitulo = subtituloGeral ?? abas.first.subtitulo;
    final maxCols = abas.fold<int>(0, (m, a) => a.colunas.length > m ? a.colunas.length : m);
    final doc = pw.Document(title: titulo, author: 'Intuitive Care');
    doc.addPage(
      pw.MultiPage(
        pageFormat: maxCols > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('intuitivecare',
                style: pw.TextStyle(color: forest, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('CONTROLE E TRATAMENTO DE DADOS', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.SizedBox(height: 12),
            pw.Text(titulo, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (subtitulo != null && subtitulo.isNotEmpty)
              pw.Text(subtitulo, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Fonte: dados abertos ANS · página ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (_) => [
          for (var i = 0; i < abas.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 16),
            if (abas.length > 1) ...[
              pw.Text(abas[i].titulo, style: pw.TextStyle(color: forest, fontSize: 11, fontWeight: pw.FontWeight.bold)),
              if (abas[i].subtitulo != null && abas[i].subtitulo!.isNotEmpty)
                pw.Text(abas[i].subtitulo!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 6),
            ],
            pw.TableHelper.fromTextArray(
              headers: abas[i].colunas,
              data: abas[i].linhas,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: forest),
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(color: sage),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }
}

