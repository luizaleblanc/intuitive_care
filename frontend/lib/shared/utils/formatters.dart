import 'package:intl/intl.dart';

/// Helpers de formatação (seção 10 da especificação).

final _int = NumberFormat.decimalPattern('pt_BR');
final _dec1 = NumberFormat('#,##0.0', 'pt_BR');
final _dec2 = NumberFormat('#,##0.00', 'pt_BR');

String fmtInt(num n) => _int.format(n.round());

/// Valor em reais -> "R$ 79,80 bi".
String fmtBi(num reais) => 'R\$ ${_dec2.format(reais / 1e9)} bi';

/// Valor já em bilhões -> "79,80".
String fmtBiNum(num bilhoes) => _dec2.format(bilhoes);

/// 79.84 -> "79,8".
String fmtDec1(num n) => _dec1.format(n);

/// 51.400.000 -> "51,4 mi".
String fmtMi(num n) => n >= 1e6 ? '${_dec1.format(n / 1e6)} mi' : fmtInt(n);

/// Moeda inteira: "R$ 351".
String fmtReais(num n) => 'R\$ ${_int.format(n.round())}';

String fmtPct(num n, {int casas = 1}) => '${(casas == 1 ? _dec1 : _dec2).format(n)}%';

String fmtDelta(num n) => '${n >= 0 ? '+' : ''}${_dec1.format(n)}%';

double? variation(num? atual, num? anterior) {
  if (atual == null || anterior == null || anterior == 0) return null;
  return (atual - anterior) / anterior.abs() * 100;
}

/// "4º trimestre de 2025" — títulos e rótulos.
String fmtPeriodo(int ano, int trimestre) => '$trimestreº trimestre de $ano';

/// Rótulo de eixo em duas linhas: "4º trimestre" / "2025". Trimestre nunca é abreviado.
String fmtPeriodoCurto(int ano, int trimestre) => '$trimestreº trimestre\n$ano';

String fmtTrimestre(int t) => '$tº trimestre';

/// Rótulo resumido para lista de trimestres (sem abreviações):
/// [1] -> "1º trimestre", [1, 2] -> "1º e 2º trimestres", [1, 2, 3] -> "3 trimestres".
String fmtTrimestres(Iterable<int> trimestres, {String vazio = 'Todos os trimestres'}) {
  final lista = trimestres.toSet().toList()..sort();
  if (lista.isEmpty) return vazio;
  if (lista.length == 1) return fmtTrimestre(lista.first);
  if (lista.length == 2) return '${lista[0]}º e ${lista[1]}º trimestres';
  if (lista.length == 4) return 'Todos os trimestres';
  return '${lista.length} trimestres';
}

/// Rótulo resumido para lista de anos: [2025] -> "2025", [2024, 2025] -> "2024, 2025", 3+ -> "3 anos".
String fmtAnos(Iterable<int> anos, {String vazio = 'Todos os anos'}) {
  final lista = anos.toSet().toList()..sort((a, b) => b.compareTo(a));
  if (lista.isEmpty) return vazio;
  if (lista.length <= 2) return lista.join(', ');
  return '${lista.length} anos';
}

/// Rótulo descritivo para um ou mais períodos (ano, trimestre) selecionados.
String fmtPeriodosSelecionados(List<(int, int)> periodos) {
  if (periodos.isEmpty) return '';
  if (periodos.length == 1) return fmtPeriodo(periodos.first.$1, periodos.first.$2);
  final anos = periodos.map((p) => p.$1).toSet().toList()..sort();
  final tris = periodos.map((p) => p.$2).toSet().toList()..sort();
  if (anos.length == 1) return '${fmtTrimestres(tris)} de ${anos.first}';
  final rotuloAnos = anos.length <= 3 ? anos.join(', ') : '${anos.first}–${anos.last}';
  if (tris.length < 4) return '${fmtTrimestres(tris)} · $rotuloAnos';
  return '${periodos.length} trimestres · $rotuloAnos';
}

/// Máscara de CNPJ: 29309127000179 -> 29.309.127/0001-79.
String fmtCnpj(String? cnpj) {
  final d = (cnpj ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length != 14) return cnpj ?? '';
  return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
}

/// Datas conforme a preferência do usuário ('DD/MM/AAAA' ou 'AAAA-MM-DD').
String fmtData(DateTime? data, {String formato = 'DD/MM/AAAA', bool hora = false}) {
  if (data == null) return '—';
  final local = data.toLocal();
  final base = formato == 'AAAA-MM-DD'
      ? DateFormat('yyyy-MM-dd').format(local)
      : DateFormat('dd/MM/yyyy').format(local);
  return hora ? '$base · ${DateFormat('HH:mm').format(local)}' : base;
}

String fmtMesAno(DateTime? data) => data == null ? '—' : DateFormat('MM/yyyy').format(data.toLocal());

String iniciais(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
  return (partes.first[0] + partes.last[0]).toUpperCase();
}

/// Converte "AMIL ASSISTÊNCIA MÉDICA" em "Amil Assistência Médica" para exibição de nomes.
String nomeProprio(String texto) {
  const minusculas = {'de', 'da', 'do', 'das', 'dos', 'e', 'em'};
  const siglas = {'S.A.', 'S/A', 'LTDA', 'LTDA.', 'SA', 'ME', 'EPP', 'S.A', 'SP', 'RJ', 'MG', 'BH', 'JP'};
  final palavras = texto.toLowerCase().split(' ');
  return [
    for (var i = 0; i < palavras.length; i++)
      if (palavras[i].isEmpty)
        ''
      else if (siglas.contains(palavras[i].toUpperCase()) ||
          (palavras[i].contains('/') && palavras[i].length <= 6))
        palavras[i].toUpperCase()
      else if (i > 0 && minusculas.contains(palavras[i]))
        palavras[i]
      else
        palavras[i][0].toUpperCase() + palavras[i].substring(1),
  ].join(' ');
}
