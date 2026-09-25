import 'package:intl/intl.dart';
import '../constants/currencies.dart';

/// Centralized production-grade money formatter for Hissab.
/// Supports exact, compact, smart, and split-line formatting for numbers
/// ranging from small amounts (10.00) to trillion-level (555.56B / 1.20T)
/// while strictly preserving integer minor-unit accounting accuracy.
class MoneyDisplayFormatter {
  /// Format exact full amount with commas and full decimals.
  /// Example: 55555555555500 (SAR) -> "SAR 555,555,555,555.00"
  static String formatExact(
    int minorUnits,
    CurrencyConfig currency, {
    bool showExplicitPlus = false,
    bool includeCode = true,
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
    } else {
      return '$sign$amountStr';
    }
  }

  /// Compact formatting for cards, overview bars, badges, and small screens.
  /// Examples:
  ///   1000 -> SAR 10.00
  ///   125000 -> SAR 1,250.00
  ///   84520000 -> SAR 845.20K
  ///   125500000 -> SAR 1.26M
  ///   55555555555500 -> SAR 555.56B
  ///   120000000000000 -> SAR 1.20T
  static String formatCompact(
    int minorUnits,
    CurrencyConfig currency, {
    bool showExplicitPlus = false,
    bool includeCode = true,
  }) {
    final isNegative = minorUnits < 0;
    final absAmount = minorUnits.abs() / currency.unitMultiplier;
    final sign = isNegative ? '-' : (showExplicitPlus && minorUnits > 0 ? '+' : '');

    String numStr;
    if (absAmount >= 1000000000000.0) {
      // Trillion
      final val = absAmount / 1000000000000.0;
      numStr = '${_formatCompactNumber(val)}T';
    } else if (absAmount >= 1000000000.0) {
      // Billion
      final val = absAmount / 1000000000.0;
      numStr = '${_formatCompactNumber(val)}B';
    } else if (absAmount >= 1000000.0) {
      // Million
      final val = absAmount / 1000000.0;
      numStr = '${_formatCompactNumber(val)}M';
    } else if (absAmount >= 10000.0) {
      // Thousand (for >= 10K)
      final val = absAmount / 1000.0;
      numStr = '${_formatCompactNumber(val)}K';
    } else {
      // Under 10K: show exact amount
      return formatExact(minorUnits, currency, showExplicitPlus: showExplicitPlus, includeCode: includeCode);
    }

    if (includeCode) {
      return '$sign${currency.code} $numStr';
    } else {
      return '$sign$numStr';
    }
  }

  /// Automatically chooses compact format if the amount exceeds [thresholdMajor] (default: 100,000).
  static String formatSmart(
    int minorUnits,
    CurrencyConfig currency, {
    double thresholdMajor = 100000.0,
    bool showExplicitPlus = false,
    bool includeCode = true,
  }) {
    final absMajor = minorUnits.abs() / currency.unitMultiplier;
    if (absMajor >= thresholdMajor) {
      return formatCompact(minorUnits, currency, showExplicitPlus: showExplicitPlus, includeCode: includeCode);
    }
    return formatExact(minorUnits, currency, showExplicitPlus: showExplicitPlus, includeCode: includeCode);
  }

  /// Returns split parts (sign, currencyCode, amountStr) for multi-line or two-column rendering.
  static ({String sign, String code, String amount, String fullExact}) formatParts(
    int minorUnits,
    CurrencyConfig currency, {
    bool compact = false,
    bool showExplicitPlus = false,
  }) {
    final isNegative = minorUnits < 0;
    final sign = isNegative ? '-' : (showExplicitPlus && minorUnits > 0 ? '+' : '');
    final exact = formatExact(minorUnits, currency, showExplicitPlus: showExplicitPlus, includeCode: true);

    if (compact) {
      final compactWithCode = formatCompact(minorUnits, currency, showExplicitPlus: false, includeCode: false);
      return (
        sign: sign,
        code: currency.code,
        amount: compactWithCode,
        fullExact: exact,
      );
    } else {
      final exactWithoutCode = formatExact(minorUnits, currency, showExplicitPlus: false, includeCode: false);
      return (
        sign: sign,
        code: currency.code,
        amount: exactWithoutCode,
        fullExact: exact,
      );
    }
  }

  static String _formatCompactNumber(double val) {
    if (val >= 100.0) {
      // e.g. 555.56
      return val.toStringAsFixed(2);
    } else if (val >= 10.0) {
      // e.g. 12.50
      return val.toStringAsFixed(2);
    } else {
      // e.g. 1.25
      return val.toStringAsFixed(2);
    }
  }
}
