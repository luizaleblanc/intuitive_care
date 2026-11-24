import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'export_table.dart';

const _corForestPdf = PdfColor.fromInt(0xFF113E32);
const _corSagePdf = PdfColor.fromInt(0xFFDCE7E2);

pw.Widget _buildCabecalhoPdf(String titulo, String? subtitulo) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      'intuitivecare',
      style: pw.TextStyle(color: _corForestPdf, fontSize: 16, fontWeight: pw.FontWeight.bold),
    ),
    pw.Text('CONTROLE E TRATAMENTO DE DADOS', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
    pw.SizedBox(height: 12),
    pw.Text(titulo, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
    if (subtitulo != null && subtitulo.isNotEmpty)
      pw.Text(subtitulo, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    pw.SizedBox(height: 10),
  ],
);

pw.Widget _buildRodapePdf(pw.Context ctx) => pw.Align(
  alignment: pw.Alignment.centerRight,
  child: pw.Text(
    'Fonte: dados abertos ANS · página ${ctx.pageNumber}/${ctx.pagesCount}',
    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
  ),
);

/// Gera os bytes `.pdf` para uma tabela única.
Future<Uint8List> gerarPdf(ExportTable tabela) =>
    gerarPdfMulti([tabela], tituloGeral: tabela.titulo, subtituloGeral: tabela.subtitulo);

/// Gera os bytes `.pdf` multi-seção com cabeçalho institucional e tabelas zebradas.
Future<Uint8List> gerarPdfMulti(
  List<ExportTable> abas, {
  String? tituloGeral,
  String? subtituloGeral,
}) async {
  final titulo = tituloGeral ?? abas.first.titulo;
  final subtitulo = subtituloGeral ?? abas.first.subtitulo;
  final maxCols = abas.fold<int>(0, (m, a) => a.colunas.length > m ? a.colunas.length : m);
  final doc = pw.Document(title: titulo, author: 'Intuitive Care');

  doc.addPage(
    pw.MultiPage(
      pageFormat: maxCols > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _buildCabecalhoPdf(titulo, subtitulo),
      footer: _buildRodapePdf,
      build: (_) => [
        for (var i = 0; i < abas.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 16),
          if (abas.length > 1) ...[
            pw.Text(
              abas[i].titulo,
              style: pw.TextStyle(color: _corForestPdf, fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            if (abas[i].subtitulo case final sub? when sub.isNotEmpty)
              pw.Text(sub, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 6),
          ],
          pw.TableHelper.fromTextArray(
            headers: abas[i].colunas,
            data: abas[i].linhas,
            headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: _corForestPdf),
            cellStyle: const pw.TextStyle(fontSize: 8),
            oddRowDecoration: const pw.BoxDecoration(color: _corSagePdf),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}
