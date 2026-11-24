import 'package:excel/excel.dart';

/// Resultado do parsing de uma célula tabular para tipos nativos do Excel.
typedef ParsedExcelCell = ({CellValue valor, NumFormat formato, bool numerico});

final _reInteiroSimples = RegExp(r'^-?\d+$');
final _reDecimalPonto = RegExp(r'^-?\d+\.\d+$');
final _reInteiroPtBr = RegExp(r'^-?\d{1,3}(\.\d{3})+$');
final _reDecimalPtBr = RegExp(r'^-?(?:\d{1,3}(?:\.\d{3})+|\d+),\d+$');
final _rePercentual = RegExp(r'^[+-]?\d+(?:[.,]\d+)?%$');
final _reMoedaPtBr = RegExp(r'^R\$\s*-?(?:\d{1,3}(?:\.\d{3})*|\d+)(?:,\d{1,2})?$');
final _rePrefixoMoeda = RegExp(r'^R\$\s*');

const _termosIdentificador = [
  'registro',
  'reg.',
  'cnpj',
  'cpf',
  'cep',
  'telefone',
  'fone',
  'conta',
  'código',
  'codigo',
  'e-mail',
  'email',
];

const _colunasSemMilhar = {'ano', 'trimestre', 'nível', 'nivel'};

/// Indica se o cabeçalho identifica uma coluna textual de código/documento (ex.: CNPJ, Registro ANS).
bool ehColunaIdentificador(String coluna) {
  final c = coluna.toLowerCase();
  return _termosIdentificador.any(c.contains) || c == 'id';
}

/// Indica se uma coluna numérica inteira deve ser exibida sem separador de milhar (ex.: Ano).
bool ehColunaSemMilhar(String coluna) => _colunasSemMilhar.contains(coluna.toLowerCase().trim());

ParsedExcelCell _texto(String bruto) =>
    (valor: TextCellValue(bruto), formato: NumFormat.standard_0, numerico: false);

ParsedExcelCell? _tryDouble(String normalizado, NumFormat formato, {double divisor = 1.0}) {
  final parsed = double.tryParse(normalizado);
  if (parsed == null || !parsed.isFinite) return null;
  final valor = divisor == 1.0 ? parsed : parsed / divisor;
  return (valor: DoubleCellValue(valor), formato: formato, numerico: true);
}

/// Converte valores tabulares em tipos nativos do Excel (`IntCellValue` / `DoubleCellValue`) quando aplicável.
ParsedExcelCell parseCelulaExcel(String bruto, String coluna) {
  final s = bruto.trim();
  if (s.isEmpty || s == '—' || s == '-' || ehColunaIdentificador(coluna)) {
    return _texto(bruto);
  }

  if (_reInteiroSimples.hasMatch(s)) {
    final semSinal = s.startsWith('-') ? s.substring(1) : s;
    // Preserva códigos com zero à esquerda ou identificadores muito longos como texto.
    if ((semSinal.length > 1 && semSinal.startsWith('0')) || semSinal.length > 11) {
      return _texto(bruto);
    }
    final parsed = int.tryParse(s);
    if (parsed != null) {
      return (
        valor: IntCellValue(parsed),
        formato: ehColunaSemMilhar(coluna) ? NumFormat.standard_1 : NumFormat.standard_3,
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
    final cell = _tryDouble(s, NumFormat.standard_4);
    if (cell != null) return cell;
  }

  if (_reDecimalPtBr.hasMatch(s)) {
    final cell = _tryDouble(s.replaceAll('.', '').replaceAll(',', '.'), NumFormat.standard_4);
    if (cell != null) return cell;
  }

  if (_rePercentual.hasMatch(s)) {
    final limpo = s.substring(0, s.length - 1).replaceAll('+', '').replaceAll(',', '.');
    final cell = _tryDouble(limpo, NumFormat.standard_10, divisor: 100.0);
    if (cell != null) return cell;
  }

  if (_reMoedaPtBr.hasMatch(s)) {
    final limpo = s.replaceFirst(_rePrefixoMoeda, '').replaceAll('.', '').replaceAll(',', '.');
    final cell = _tryDouble(limpo, NumFormat.standard_4);
    if (cell != null) return cell;
  }

  return _texto(bruto);
}
