import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _brl = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static String formatBrl(double value) => _brl.format(value);

  static String formatCompactBrl(double value) {
    if (value >= 1e9) {
      return 'R\$ ${(value / 1e9).toStringAsFixed(2)} bi';
    }
    if (value >= 1e6) {
      return 'R\$ ${(value / 1e6).toStringAsFixed(1)} mi';
    }
    return formatBrl(value);
  }
}
