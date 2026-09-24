import '../constants/currencies.dart';

/// Accurate, deterministic financial calculations using integer minor units.
/// Eliminates floating-point rounding errors (e.g. 0.1 + 0.2 != 0.30000000000000004).
class DecimalCalculator {
  /// Converts a user input string (e.g. "500.50" or "1000") into minor units (e.g. 50050 or 100000).
  /// Rejects invalid characters, multiple decimal points, and negative values.
  static int? parseToMinorUnits(String input, CurrencyConfig currency) {
    final clean = input.trim().replaceAll(',', '');
    if (clean.isEmpty) return null;

    // Check for valid decimal pattern: digits optionally followed by . and digits
    final regex = RegExp(r'^\d+(\.\d+)?$');
    if (!regex.hasMatch(clean)) return null;

    final parts = clean.split('.');
    final integerPartStr = parts[0];
    final fractionalPartStr = parts.length > 1 ? parts[1] : '';

    final integerPart = int.tryParse(integerPartStr);
    if (integerPart == null) return null;

    // Pad or trim fractional part to currency.decimalPlaces
    String paddedFraction = fractionalPartStr;
    if (paddedFraction.length > currency.decimalPlaces) {
      paddedFraction = paddedFraction.substring(0, currency.decimalPlaces);
    } else {
      paddedFraction = paddedFraction.padRight(currency.decimalPlaces, '0');
    }

    final fractionalPart = paddedFraction.isEmpty ? 0 : int.parse(paddedFraction);
    final totalMinor = (integerPart * currency.unitMultiplier) + fractionalPart;
    return totalMinor;
  }

  /// Formats integer minor units to standard decimal string with fixed decimal places.
  /// Example: 10050 minor units (SAR, 2 dec) -> "100.50"
  /// Handles negative numbers properly: -50050 -> "-100.50"
  static String formatDecimal(int minorUnits, CurrencyConfig currency) {
    final isNegative = minorUnits < 0;
    final absMinor = minorUnits.abs();

    final integerPart = absMinor ~/ currency.unitMultiplier;
    final fractionalPart = absMinor % currency.unitMultiplier;

    final fractionStr = fractionalPart.toString().padLeft(currency.decimalPlaces, '0');

    if (currency.decimalPlaces == 0) {
      return '${isNegative ? '-' : ''}$integerPart';
    }

    return '${isNegative ? '-' : ''}$integerPart.$fractionStr';
  }

  /// Calculates percentage safely: (part / total) * 100
  /// Never returns NaN or Infinity. Returns 0.0 if total <= 0.
  static double calculatePercentage(int partMinor, int totalMinor) {
    if (totalMinor <= 0 || partMinor <= 0) return 0.0;
    final pct = (partMinor / totalMinor) * 100.0;
    if (pct.isNaN || pct.isInfinite) return 0.0;
    return pct > 100.0 ? 100.0 : pct;
  }

  /// Calculates percentage change between previous and current:
  /// ((current - previous) / previous) * 100
  /// Returns null if previous == 0 (to display "New" instead of Infinity).
  static double? calculatePercentageChange(int currentMinor, int previousMinor) {
    if (previousMinor == 0) return null;
    return ((currentMinor - previousMinor) / previousMinor.abs()) * 100.0;
  }
}
