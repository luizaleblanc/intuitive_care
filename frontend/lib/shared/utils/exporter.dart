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

  static Uint8List _csv(ExportTable t) {
    String esc(String v) => v.contains(RegExp(r'[;"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final buffer = StringBuffer('﻿');
    buffer.writeln(t.colunas.map(esc).join(';'));
    for (final l in t.linhas) {
      buffer.writeln(l.map(esc).join(';'));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static Uint8List _xlsx(ExportTable t) {
    final excel = Excel.createExcel();
    final nomeAba = t.titulo.length > 30 ? t.titulo.substring(0, 30) : t.titulo;
    excel.rename(excel.getDefaultSheet()!, nomeAba);
    final sheet = excel[nomeAba];
    sheet.appendRow(t.colunas.map((c) => TextCellValue(c)).toList());
    for (final l in t.linhas) {
      sheet.appendRow(l.map((v) => TextCellValue(v)).toList());
    }
    return Uint8List.fromList(excel.encode()!);
  }

  static Future<Uint8List> _pdf(ExportTable t) async {
    const forest = PdfColor.fromInt(0xFF113E32);
    const sage = PdfColor.fromInt(0xFFDCE7E2);
    final doc = pw.Document(title: t.titulo, author: 'Intuitive Care');
    doc.addPage(
      pw.MultiPage(
        pageFormat: t.colunas.length > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('intuitivecare',
                style: pw.TextStyle(color: forest, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('CONTROLE E TRATAMENTO DE DADOS', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.SizedBox(height: 12),
            pw.Text(t.titulo, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (t.subtitulo != null)
              pw.Text(t.subtitulo!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Fonte: dados abertos ANS · página ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: t.colunas,
            data: t.linhas,
            headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: forest),
            cellStyle: const pw.TextStyle(fontSize: 8),
            oddRowDecoration: const pw.BoxDecoration(color: sage),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        ],
      ),
    );
    return doc.save();
  }
}

