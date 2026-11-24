import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'cell_parser.dart';
import 'export_table.dart';

final _reCaractereInvalidoAba = RegExp(r'[:\\/?*\[\]]');
final _reEspacos = RegExp(r'\s+');

String _nomeAbaSeguro(String bruto, Set<String> usadas) {
  var limpo = bruto.replaceAll(_reCaractereInvalidoAba, ' ').replaceAll(_reEspacos, ' ').trim();
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

class _XlsxEstilos {
  static final _corForest = ExcelColor.fromHexString('FF113E32');
  static final _corBranco = ExcelColor.fromHexString('FFFFFFFF');
  static final _corSage = ExcelColor.fromHexString('FFDCE7E2');
  static final _corZebra = ExcelColor.fromHexString('FFF3F7F5');
  static final _corTexto = ExcelColor.fromHexString('FF0F172A');
  static final _corBorda = ExcelColor.fromHexString('FFD3DFD9');

  late final Border _bordaFina = Border(borderStyle: BorderStyle.Thin, borderColorHex: _corBorda);

  late final CellStyle titulo = CellStyle(
    backgroundColorHex: _corForest,
    fontColorHex: _corBranco,
    bold: true,
    fontSize: 13,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
  );

  late final CellStyle subtitulo = CellStyle(
    backgroundColorHex: _corSage,
    fontColorHex: _corForest,
    italic: true,
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
  );

  late final CellStyle cabecalho = CellStyle(
    backgroundColorHex: _corForest,
    fontColorHex: _corBranco,
    bold: true,
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  final Map<(bool, bool, NumFormat), CellStyle> _cacheCelulas = {};

  CellStyle celula(bool zebra, bool numerico, NumFormat formato) => _cacheCelulas.putIfAbsent(
    (zebra, numerico, formato),
    () => CellStyle(
      backgroundColorHex: zebra ? _corZebra : ExcelColor.none,
      fontColorHex: _corTexto,
      fontSize: 10,
      horizontalAlign: numerico ? HorizontalAlign.Right : HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _bordaFina,
      rightBorder: _bordaFina,
      topBorder: _bordaFina,
      bottomBorder: _bordaFina,
      numberFormat: formato,
    ),
  );
}

void _escreverBannerLinha(
  Sheet sheet, {
  required int rowIndex,
  required String texto,
  required CellStyle estilo,
  required int numCols,
  required double altura,
}) {
  final inicio = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex);
  sheet.updateCell(inicio, TextCellValue(texto), cellStyle: estilo);
  if (numCols > 1) {
    sheet.merge(inicio, CellIndex.indexByColumnRow(columnIndex: numCols - 1, rowIndex: rowIndex));
  }
  sheet.setRowHeight(rowIndex, altura);
}

void _preencherAba(Sheet sheet, ExportTable tabela, _XlsxEstilos estilos) {
  final numCols = tabela.colunas.isEmpty ? 1 : tabela.colunas.length;
  final larguras = List<int>.generate(
    numCols,
    (c) => c < tabela.colunas.length ? tabela.colunas[c].length : 10,
  );

  var rowIdx = 0;
  if (tabela.subtitulo case final sub? when sub.isNotEmpty) {
    _escreverBannerLinha(
      sheet,
      rowIndex: 0,
      texto: 'INTUITIVE CARE · ${tabela.titulo.toUpperCase()}',
      estilo: estilos.titulo,
      numCols: numCols,
      altura: 26,
    );
    _escreverBannerLinha(
      sheet,
      rowIndex: 1,
      texto: sub,
      estilo: estilos.subtitulo,
      numCols: numCols,
      altura: 20,
    );
    rowIdx = 3;
  }

  sheet.setRowHeight(rowIdx, 24);
  for (var c = 0; c < tabela.colunas.length; c++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
      TextCellValue(tabela.colunas[c]),
      cellStyle: estilos.cabecalho,
    );
  }
  rowIdx++;

  for (var r = 0; r < tabela.linhas.length; r++) {
    final linha = tabela.linhas[r];
    final zebra = r.isOdd;
    for (var c = 0; c < linha.length; c++) {
      final bruto = linha[c];
      final colNome = c < tabela.colunas.length ? tabela.colunas[c] : '';
      final parsed = parseCelulaExcel(bruto, colNome);
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
        parsed.valor,
        cellStyle: estilos.celula(zebra, parsed.numerico, parsed.formato),
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

/// Gera os bytes `.xlsx` estilizados para uma tabela única.
Uint8List gerarXlsx(ExportTable tabela) => gerarXlsxMulti([tabela]);

/// Gera os bytes `.xlsx` multi-aba estilizados no tema Forest e com tipagem numérica.
Uint8List gerarXlsxMulti(List<ExportTable> abas) {
  final excel = Excel.createExcel();
  final padrao = excel.getDefaultSheet();
  final usadas = <String>{};
  final nomesCriados = <String>[];
  final estilos = _XlsxEstilos();

  for (final tabela in abas) {
    final nomeAba = _nomeAbaSeguro(tabela.titulo, usadas);
    nomesCriados.add(nomeAba);
    _preencherAba(excel[nomeAba], tabela, estilos);
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
