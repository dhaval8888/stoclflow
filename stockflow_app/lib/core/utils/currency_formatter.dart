import 'package:intl/intl.dart';

/// Utility class for formatting monetary values consistently across StockFlow.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _compact = NumberFormat.compact();
  static final _full = NumberFormat('#,##0.00');
  static final _integer = NumberFormat('#,##0');

  /// Formats value as compact (e.g. 12500 → "12.5K")
  static String compact(double value) => _compact.format(value);

  /// Formats with 2 decimal places (e.g. 1234.5 → "1,234.50")
  static String amount(double value) => _full.format(value);

  /// Formats without decimals (e.g. 1234 → "1,234")
  static String integer(double value) => _integer.format(value);

  /// Formats as percentage (e.g. 0.235 → "23.5%")
  static String percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

  /// Formats a pre-multiplied percentage (e.g. 23.5 → "23.5%")
  static String percentDirect(double value) => '${value.toStringAsFixed(1)}%';
}
