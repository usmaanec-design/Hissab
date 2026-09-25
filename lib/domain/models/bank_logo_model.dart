/// Model representing a bundled or selectable bank logo.
class BankLogo {
  final String id;
  final String name;
  final String nameAr;
  final String nameUr;
  final String country; // 'sa' (Saudi Arabia) or 'pk' (Pakistan)
  final String assetPath;
  final String shortCode;
  final int brandColor;

  const BankLogo({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.nameUr,
    required this.country,
    required this.assetPath,
    required this.shortCode,
    required this.brandColor,
  });

  /// Localized name according to language code
  String getLocalizedName(String languageCode) {
    if (languageCode == 'ar') return nameAr;
    if (languageCode == 'ur') return nameUr;
    return name;
  }
}
