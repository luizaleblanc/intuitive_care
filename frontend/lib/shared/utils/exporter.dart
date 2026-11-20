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
  static const mimeXlsx = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const mimeCsv = 'text/csv;charset=utf-8';
  static const mimePdf = 'application/pdf';

  /// Inicia o download direto de bytes já prontos (ex.: arquivo XLSX/CSV gerado pela API).
  static String salvarBytes(Uint8List bytes, String nome, String mime) {
    baixarArquivo(bytes, nome, mime);
    return nome;
  }

  static Future<String> exportar(ExportTable tabela, {required String nomeBase, String formato = 'CSV'}) async {
    final f = formato.toUpperCase();
    late final Uint8List bytes;
    late final String mime;
    late final String ext;
    switch (f) {
      case 'PDF':
        bytes = await _pdf(tabela);
        mime = mimePdf;
        ext = 'pdf';
      case 'XLSX':
        bytes = _xlsx(tabela);
        mime = mimeXlsx;
        ext = 'xlsx';
      default:
        bytes = _csv(tabela);
        mime = mimeCsv;
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
        mime = mimePdf;
        ext = 'pdf';
      case 'CSV':
        bytes = _csvMulti(abas, tituloGeral: tituloGeral, subtituloGeral: subtituloGeral);
        mime = mimeCsv;
        ext = 'csv';
      default:
        bytes = _xlsxMulti(abas);
        mime = mimeXlsx;
        ext = 'xlsx';
    }
    final nome = '$nomeBase.$ext';
    baixarArquivo(bytes, nome, mime);
    return nome;
  }

  /// Gera os bytes `.xlsx` multi-aba estilizados (útil também para testes unitários).
  static Uint8List gerarXlsxBytes(List<ExportTable> abas) => _xlsxMulti(abas);

  /// Gera os bytes `.csv` UTF-8 BOM multi-seção.
  static Uint8List gerarCsvBytes(List<ExportTable> abas, {String? tituloGeral, String? subtituloGeral}) =>
      _csvMulti(abas, tituloGeral: tituloGeral, subtituloGeral: subtituloGeral);

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

  static final _reInteiroSimples = RegExp(r'^-?\d+$');
  static final _reDecimalPonto = RegExp(r'^-?\d+\.\d+$');
  static final _reInteiroPtBr = RegExp(r'^-?\d{1,3}(\.\d{3})+$');
  static final _reDecimalPtBr = RegExp(r'^-?(?:\d{1,3}(?:\.\d{3})+|\d+),\d+$');
  static final _rePercentual = RegExp(r'^[+-]?\d+(?:[.,]\d+)?%$');
  static final _reMoedaPtBr = RegExp(r'^R\$\s*-?(?:\d{1,3}(?:\.\d{3})*|\d+)(?:,\d{1,2})?$');

  static bool _ehColunaIdentificador(String coluna) {
    final c = coluna.toLowerCase();
    return c.contains('registro') ||
        c.contains('reg.') ||
        c.contains('cnpj') ||
        c.contains('cpf') ||
        c.contains('cep') ||
        c.contains('telefone') ||
        c.contains('fone') ||
        c.contains('conta') ||
        c.contains('código') ||
        c.contains('codigo') ||
        c.contains('e-mail') ||
        c.contains('email') ||
        c == 'id';
  }

  static bool _ehColunaSemMilhar(String coluna) {
    final c = coluna.toLowerCase().trim();
    return c == 'ano' || c == 'trimestre' || c == 'nível' || c == 'nivel';
  }

  /// Converte valores tabulares em tipos nativos do Excel (`IntCellValue` / `DoubleCellValue`) quando aplicável.
  static ({CellValue valor, NumFormat formato, bool numerico}) _parseCelula(String bruto, String coluna) {
    final s = bruto.trim();
    if (s.isEmpty || s == '—' || s == '-' || _ehColunaIdentificador(coluna)) {
      return (valor: TextCellValue(bruto), formato: NumFormat.standard_0, numerico: false);
    }

    if (_reInteiroSimples.hasMatch(s)) {
      final semSinal = s.startsWith('-') ? s.substring(1) : s;
      // Preserva códigos com zero à esquerda ou identificadores muito longos como texto.
      if ((semSinal.length > 1 && semSinal.startsWith('0')) || semSinal.length > 11) {
        return (valor: TextCellValue(bruto), formato: NumFormat.standard_0, numerico: false);
      }
      final parsed = int.tryParse(s);
      if (parsed != null) {
        return (
          valor: IntCellValue(parsed),
          formato: _ehColunaSemMilhar(coluna) ? NumFormat.standard_1 : NumFormat.standard_3,
          numerico: true,
        );
      }
    }

    if (_reInteiroPtBr.hasMatch(s)) {
      final parsed = int.tryParse(s.replaceAll('.', ''));
      if (parsed != null) {
        return (valor: IntCellValue(parsed), formato: NumFormat.standard_3, numerico: true);
      }
    }

    if (_reDecimalPonto.hasMatch(s)) {
      final parsed = double.tryParse(s);
      if (parsed != null && parsed.isFinite) {
        return (valor: DoubleCellValue(parsed), formato: NumFormat.standard_4, numerico: true);
      }
    }

    if (_reDecimalPtBr.hasMatch(s)) {
      final normalizado = s.replaceAll('.', '').replaceAll(',', '.');
      final parsed = double.tryParse(normalizado);
      if (parsed != null && parsed.isFinite) {
        return (valor: DoubleCellValue(parsed), formato: NumFormat.standard_4, numerico: true);
      }
    }

    if (_rePercentual.hasMatch(s)) {
      final limpo = s.substring(0, s.length - 1).replaceAll('+', '').replaceAll(',', '.');
      final parsed = double.tryParse(limpo);
      if (parsed != null && parsed.isFinite) {
        return (valor: DoubleCellValue(parsed / 100.0), formato: NumFormat.standard_10, numerico: true);
      }
    }

    if (_reMoedaPtBr.hasMatch(s)) {
      final limpo = s.replaceFirst(RegExp(r'^R\$\s*'), '').replaceAll('.', '').replaceAll(',', '.');
      final parsed = double.tryParse(limpo);
      if (parsed != null && parsed.isFinite) {
        return (valor: DoubleCellValue(parsed), formato: NumFormat.standard_4, numerico: true);
      }
    }

    return (valor: TextCellValue(bruto), formato: NumFormat.standard_0, numerico: false);
  }

  static Uint8List _xlsxMulti(List<ExportTable> abas) {
    final excel = Excel.createExcel();
    final padrao = excel.getDefaultSheet();
    final usadas = <String>{};
    final nomesCriados = <String>[];

    final corForest = ExcelColor.fromHexString('FF113E32');
    final corBranco = ExcelColor.fromHexString('FFFFFFFF');
    final corSage = ExcelColor.fromHexString('FFDCE7E2');
    final corZebra = ExcelColor.fromHexString('FFF3F7F5');
    final corTexto = ExcelColor.fromHexString('FF0F172A');
    final corBorda = ExcelColor.fromHexString('FFD3DFD9');
    final bordaFina = Border(borderStyle: BorderStyle.Thin, borderColorHex: corBorda);

    final estiloTitulo = CellStyle(
      backgroundColorHex: corForest,
      fontColorHex: corBranco,
      bold: true,
      fontSize: 13,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final estiloSubtitulo = CellStyle(
      backgroundColorHex: corSage,
      fontColorHex: corForest,
      italic: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final estiloCabecalho = CellStyle(
      backgroundColorHex: corForest,
      fontColorHex: corBranco,
      bold: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: bordaFina,
      rightBorder: bordaFina,
      topBorder: bordaFina,
      bottomBorder: bordaFina,
    );

    final cacheEstilos = <(bool, bool, NumFormat), CellStyle>{};
    CellStyle estiloCelula(bool zebra, bool numerico, NumFormat formato) =>
        cacheEstilos.putIfAbsent(
          (zebra, numerico, formato),
          () => CellStyle(
            backgroundColorHex: zebra ? corZebra : ExcelColor.none,
            fontColorHex: corTexto,
            fontSize: 10,
            horizontalAlign: numerico ? HorizontalAlign.Right : HorizontalAlign.Left,
            verticalAlign: VerticalAlign.Center,
            leftBorder: bordaFina,
            rightBorder: bordaFina,
            topBorder: bordaFina,
            bottomBorder: bordaFina,
            numberFormat: formato,
          ),
        );

    for (final t in abas) {
      final nomeAba = _nomeAbaSeguro(t.titulo, usadas);
      nomesCriados.add(nomeAba);
      final sheet = excel[nomeAba];
      final numCols = t.colunas.isEmpty ? 1 : t.colunas.length;
      final larguras = List<int>.generate(
        numCols,
        (c) => c < t.colunas.length ? t.colunas[c].length : 10,
      );

      var rowIdx = 0;
      if (t.subtitulo != null && t.subtitulo!.isNotEmpty) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          TextCellValue('INTUITIVE CARE · ${t.titulo.toUpperCase()}'),
          cellStyle: estiloTitulo,
        );
        if (numCols > 1) {
          sheet.merge(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
            CellIndex.indexByColumnRow(columnIndex: numCols - 1, rowIndex: 0),
          );
        }
        sheet.setRowHeight(0, 26);

        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          TextCellValue(t.subtitulo!),
          cellStyle: estiloSubtitulo,
        );
        if (numCols > 1) {
          sheet.merge(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
            CellIndex.indexByColumnRow(columnIndex: numCols - 1, rowIndex: 1),
          );
        }
        sheet.setRowHeight(1, 20);
        rowIdx = 3;
      }

      sheet.setRowHeight(rowIdx, 24);
      for (var c = 0; c < t.colunas.length; c++) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
          TextCellValue(t.colunas[c]),
          cellStyle: estiloCabecalho,
        );
      }
      rowIdx++;

      for (var r = 0; r < t.linhas.length; r++) {
        final linha = t.linhas[r];
        final zebra = r.isOdd;
        for (var c = 0; c < linha.length; c++) {
          final bruto = linha[c];
          final colNome = c < t.colunas.length ? t.colunas[c] : '';
          final parsed = _parseCelula(bruto, colNome);
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
            parsed.valor,
            cellStyle: estiloCelula(zebra, parsed.numerico, parsed.formato),
          );
          if (c < larguras.length && bruto.length > larguras[c]) {
            larguras[c] = bruto.length;
          }
        }
        rowIdx++;
      }

      for (var c = 0; c < larguras.length; c++) {
        final largura = (larguras[c] + 4).clamp(11, 46).toDouble();
        sheet.setColumnWidth(c, largura);
      }
    }

    // Remove a aba padrão inicial ("Sheet1") sem usar rename() quando ela não foi usada.
    if (padrao != null && !usadas.contains(padrao) && nomesCriados.isNotEmpty) {
      excel.delete(padrao);
    }
    if (nomesCriados.isNotEmpty) {
      excel.setDefaultSheet(nomesCriados.first);
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
