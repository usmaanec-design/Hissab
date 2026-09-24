import 'package:intl/intl.dart';
import '../constants/currencies.dart';

class CurrencyFormatter {
  /// Formats minor units into comma-separated currency string with symbol/code.
  /// Example: 1254000 (SAR) -> "SAR 12,540.00"
  /// With includeSign: true -> "+SAR 500.00" or "-SAR 200.00"
  static String format(
    int minorUnits,
    CurrencyConfig currency, {
    bool includeSymbol = true,
    bool includeCode = true,
    bool showExplicitPlus = false,
  }) {
    final isNegative = minorUnits < 0;
    final absMinor = minorUnits.abs();

    final integerPart = absMinor ~/ currency.unitMultiplier;
    final fractionalPart = absMinor % currency.unitMultiplier;

    final numberFormat = NumberFormat('#,##0');
    final formattedInt = numberFormat.format(integerPart);

    String amountStr;
    if (currency.decimalPlaces > 0) {
      final fractionStr = fractionalPart.toString().padLeft(currency.decimalPlaces, '0');
      amountStr = '$formattedInt.$fractionStr';
    } else {
      amountStr = formattedInt;
    }

    final sign = isNegative ? '-' : (showExplicitPlus && minorUnits > 0 ? '+' : '');

    if (includeCode) {
      return '$sign${currency.code} $amountStr';
    } else if (includeSymbol) {
      return '$sign${currency.symbol} $amountStr';
    } else {
      return '$sign$amountStr';
    }
  }

  /// Compact formatting for charts and small badges (e.g. "SAR 1.5K", "SAR 2.4M")
  static String formatCompact(int minorUnits, CurrencyConfig currency) {
    final absAmount = (minorUnits.abs() / currency.unitMultiplier);
    final sign = minorUnits < 0 ? '-' : '';

    if (absAmount >= 1000000000) {
      return '$sign${currency.code} ${(absAmount / 1000000000).toStringAsFixed(1)}B';
    } else if (absAmount >= 1000000) {
      return '$sign${currency.code} ${(absAmount / 1000000).toStringAsFixed(1)}M';
    } else if (absAmount >= 1000) {
      return '$sign${currency.code} ${(absAmount / 1000).toStringAsFixed(1)}K';
    } else {
      return format(minorUnits, currency);
    }
  }
}
