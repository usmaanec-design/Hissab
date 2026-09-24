class CurrencyConfig {
  final String code;
  final String symbol;
  final String name;
  final int decimalPlaces;
  final String minorUnitName;

  const CurrencyConfig({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimalPlaces = 2,
    required this.minorUnitName,
  });

  /// Minor unit multiplier, e.g. 10^2 = 100 for SAR/PKR/USD
  int get unitMultiplier {
    int mul = 1;
    for (int i = 0; i < decimalPlaces; i++) {
      mul *= 10;
    }
    return mul;
  }
}

class Currencies {
  static const CurrencyConfig sar = CurrencyConfig(
    code: 'SAR',
    symbol: 'ر.س',
    name: 'Saudi Riyal',
    decimalPlaces: 2,
    minorUnitName: 'Halala',
  );

  static const CurrencyConfig pkr = CurrencyConfig(
    code: 'PKR',
    symbol: 'Rs',
    name: 'Pakistani Rupee',
    decimalPlaces: 2,
    minorUnitName: 'Paisa',
  );

  static const CurrencyConfig usd = CurrencyConfig(
    code: 'USD',
    symbol: '\$',
    name: 'US Dollar',
    decimalPlaces: 2,
    minorUnitName: 'Cent',
  );

  static const CurrencyConfig aed = CurrencyConfig(
    code: 'AED',
    symbol: 'د.إ',
    name: 'UAE Dirham',
    decimalPlaces: 2,
    minorUnitName: 'Fils',
  );

  static const CurrencyConfig eur = CurrencyConfig(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    decimalPlaces: 2,
    minorUnitName: 'Cent',
  );

  static const CurrencyConfig gbp = CurrencyConfig(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    decimalPlaces: 2,
    minorUnitName: 'Penny',
  );

  static const CurrencyConfig inr = CurrencyConfig(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
    decimalPlaces: 2,
    minorUnitName: 'Paisa',
  );

  static const CurrencyConfig kwd = CurrencyConfig(
    code: 'KWD',
    symbol: 'د.ك',
    name: 'Kuwaiti Dinar',
    decimalPlaces: 3,
    minorUnitName: 'Fils',
  );

  static const CurrencyConfig omr = CurrencyConfig(
    code: 'OMR',
    symbol: 'ر.ع',
    name: 'Omani Rial',
    decimalPlaces: 3,
    minorUnitName: 'Baisa',
  );

  static const CurrencyConfig bhd = CurrencyConfig(
    code: 'BHD',
    symbol: 'ب.د',
    name: 'Bahraini Dinar',
    decimalPlaces: 3,
    minorUnitName: 'Fils',
  );

  static const CurrencyConfig qar = CurrencyConfig(
    code: 'QAR',
    symbol: 'ر.ق',
    name: 'Qatari Riyal',
    decimalPlaces: 2,
    minorUnitName: 'Dirham',
  );

  static const List<CurrencyConfig> all = [
    sar,
    pkr,
    usd,
    aed,
    eur,
    gbp,
    inr,
    kwd,
    omr,
    bhd,
    qar,
  ];

  static CurrencyConfig findByCode(String code) {
    return all.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => sar,
    );
  }
}
