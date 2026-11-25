import 'dart:typed_data';

import 'browser.dart';
import 'export/csv_exporter.dart';
import 'export/export_table.dart';
import 'export/pdf_exporter.dart' deferred as pdf_exporter;
import 'export/xlsx_exporter.dart';

export 'browser.dart' show abrirNovaAba;
export 'export/export_table.dart';

/// Gera o arquivo no formato escolhido nas preferências (CSV, PDF ou XLSX) e inicia o download.
class Exporter {
  static const mimeXlsx = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const mimeCsv = 'text/csv;charset=utf-8';
  static const mimePdf = 'application/pdf';

  /// Inicia o download direto de bytes já prontos (ex.: arquivo XLSX/CSV gerado pela API).
  static String salvarBytes(Uint8List bytes, String nome, String mime) {
    baixarArquivo(bytes, nome, mime);
    return nome;
  }

  /// Exporta uma única tabela no formato indicado (`CSV`, `XLSX` ou `PDF`) e inicia o download.
  static Future<String> exportar(ExportTable tabela, {required String nomeBase, String formato = 'CSV'}) async {
    final (bytes, mime, ext) = switch (formato.toUpperCase()) {
      'PDF' => await _pdfTabela(tabela),
      'XLSX' => (gerarXlsx(tabela), mimeXlsx, 'xlsx'),
      _ => (gerarCsv(tabela), mimeCsv, 'csv'),
    };
    return salvarBytes(bytes, '$nomeBase.$ext', mime);
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
    final (bytes, mime, ext) = switch (formato.toUpperCase()) {
      'PDF' => await _pdfRelatorio(abas, tituloGeral: tituloGeral, subtituloGeral: subtituloGeral),
      'CSV' => (gerarCsvMulti(abas, tituloGeral: tituloGeral, subtituloGeral: subtituloGeral), mimeCsv, 'csv'),
      _ => (gerarXlsxMulti(abas), mimeXlsx, 'xlsx'),
    };
    return salvarBytes(bytes, '$nomeBase.$ext', mime);
  }

  static Future<(Uint8List, String, String)> _pdfTabela(ExportTable tabela) async {
    await pdf_exporter.loadLibrary();
    return (await pdf_exporter.gerarPdf(tabela), mimePdf, 'pdf');
  }

  static Future<(Uint8List, String, String)> _pdfRelatorio(
    List<ExportTable> abas, {
    String? tituloGeral,
    String? subtituloGeral,
  }) async {
    await pdf_exporter.loadLibrary();
    return (
      await pdf_exporter.gerarPdfMulti(abas, tituloGeral: tituloGeral, subtituloGeral: subtituloGeral),
      mimePdf,
      'pdf',
    );
  }

  /// Gera os bytes `.xlsx` multi-aba estilizados (útil também para testes unitários).
  static Uint8List gerarXlsxBytes(List<ExportTable> abas) => gerarXlsxMulti(abas);

  /// Gera os bytes `.csv` UTF-8 BOM multi-seção.
  static Uint8List gerarCsvBytes(List<ExportTable> abas, {String? tituloGeral, String? subtituloGeral}) =>
      gerarCsvMulti(abas, tituloGeral: tituloGeral, subtituloGeral: subtituloGeral);
}
