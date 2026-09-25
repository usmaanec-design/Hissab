import 'package:hissab/domain/models/bank_logo_model.dart';

/// Centralized catalog of Saudi Arabia and Pakistan banks for Hissab Book logos.
class BankCatalog {
  BankCatalog._();

  static const List<BankLogo> saudiBanks = [
    BankLogo(
      id: 'alrajhi',
      name: 'Al Rajhi Bank',
      nameAr: 'مصرف الراجحي',
      nameUr: 'الراجحی بینک',
      country: 'sa',
      assetPath: 'assets/banks/alrajhi.png',
      shortCode: 'AR',
      brandColor: 0xFF003882,
    ),
    BankLogo(
      id: 'snb',
      name: 'Saudi National Bank (SNB)',
      nameAr: 'البنك الأهلي السعودي',
      nameUr: 'سعودی نیشنل بینک (SNB)',
      country: 'sa',
      assetPath: 'assets/banks/snb.png',
      shortCode: 'SNB',
      brandColor: 0xFF006C35,
    ),
    BankLogo(
      id: 'riyad',
      name: 'Riyad Bank',
      nameAr: 'بنك الرياض',
      nameUr: 'ریاض بینک',
      country: 'sa',
      assetPath: 'assets/banks/riyad.png',
      shortCode: 'RB',
      brandColor: 0xFF004B87,
    ),
    BankLogo(
      id: 'alinma',
      name: 'Bank Alinma',
      nameAr: 'مصرف الإنماء',
      nameUr: 'بینک الانماء',
      country: 'sa',
      assetPath: 'assets/banks/alinma.png',
      shortCode: 'INMA',
      brandColor: 0xFF8A5A2B,
    ),
    BankLogo(
      id: 'albilad',
      name: 'Bank Albilad',
      nameAr: 'بنك البلاد',
      nameUr: 'بینک البلاد',
      country: 'sa',
      assetPath: 'assets/banks/albilad.png',
      shortCode: 'BLD',
      brandColor: 0xFFBA1B23,
    ),
    BankLogo(
      id: 'sab',
      name: 'SAB (Saudi Awwal Bank)',
      nameAr: 'البنك السعودي الأول (ساب)',
      nameUr: 'ساب (سعودی اول بینک)',
      country: 'sa',
      assetPath: 'assets/banks/sab.png',
      shortCode: 'SAB',
      brandColor: 0xFFD41217,
    ),
    BankLogo(
      id: 'anb',
      name: 'Arab National Bank',
      nameAr: 'البنك العربي الوطني',
      nameUr: 'عرب نیشنل بینک',
      country: 'sa',
      assetPath: 'assets/banks/anb.png',
      shortCode: 'ANB',
      brandColor: 0xFF0A2B4C,
    ),
    BankLogo(
      id: 'bsf',
      name: 'Banque Saudi Fransi',
      nameAr: 'البنك السعودي الفرنسي',
      nameUr: 'بینک سعودی فرینسی',
      country: 'sa',
      assetPath: 'assets/banks/bsf.png',
      shortCode: 'BSF',
      brandColor: 0xFF142F54,
    ),
    BankLogo(
      id: 'saib',
      name: 'Saudi Investment Bank',
      nameAr: 'البنك السعودي للاستثمار',
      nameUr: 'سعودی انویسٹمنٹ بینک',
      country: 'sa',
      assetPath: 'assets/banks/saib.png',
      shortCode: 'SAIB',
      brandColor: 0xFF005A9C,
    ),
    BankLogo(
      id: 'aljazira',
      name: 'Bank AlJazira',
      nameAr: 'بنك الجزيرة',
      nameUr: 'بینک الجزیرہ',
      country: 'sa',
      assetPath: 'assets/banks/aljazira.png',
      shortCode: 'BAJ',
      brandColor: 0xFF00587C,
    ),
  ];

  static const List<BankLogo> pakistanBanks = [
    BankLogo(
      id: 'meezan',
      name: 'Meezan Bank',
      nameAr: 'بنك ميزان',
      nameUr: 'میزان بینک',
      country: 'pk',
      assetPath: 'assets/banks/meezan.png',
      shortCode: 'MBL',
      brandColor: 0xFF003366,
    ),
    BankLogo(
      id: 'hbl',
      name: 'Habib Bank Limited (HBL)',
      nameAr: 'حبيب بنك المحدود (HBL)',
      nameUr: 'حبیب بینک لمیٹڈ (HBL)',
      country: 'pk',
      assetPath: 'assets/banks/hbl.png',
      shortCode: 'HBL',
      brandColor: 0xFF007A5E,
    ),
    BankLogo(
      id: 'ubl',
      name: 'United Bank Limited (UBL)',
      nameAr: 'يونايتد بنك ليمتد (UBL)',
      nameUr: 'یونائیٹڈ بینک لمیٹڈ (UBL)',
      country: 'pk',
      assetPath: 'assets/banks/ubl.png',
      shortCode: 'UBL',
      brandColor: 0xFF005696,
    ),
    BankLogo(
      id: 'mcb',
      name: 'MCB Bank',
      nameAr: 'إم سي بي بنك',
      nameUr: 'ایم سی بی بینک',
      country: 'pk',
      assetPath: 'assets/banks/mcb.png',
      shortCode: 'MCB',
      brandColor: 0xFFDE6012,
    ),
    BankLogo(
      id: 'alfalah',
      name: 'Bank Alfalah',
      nameAr: 'بنك الفلاح',
      nameUr: 'بینک الفلاح',
      country: 'pk',
      assetPath: 'assets/banks/alfalah.png',
      shortCode: 'BAFL',
      brandColor: 0xFFD01C24,
    ),
    BankLogo(
      id: 'abl',
      name: 'Allied Bank Limited (ABL)',
      nameAr: 'بنك الحلفاء المحدود (ABL)',
      nameUr: 'الائیڈ بینک لمیٹڈ (ABL)',
      country: 'pk',
      assetPath: 'assets/banks/abl.png',
      shortCode: 'ABL',
      brandColor: 0xFF002B49,
    ),
    BankLogo(
      id: 'askari',
      name: 'Askari Bank',
      nameAr: 'بنك عسكري',
      nameUr: 'عسکری بینک',
      country: 'pk',
      assetPath: 'assets/banks/askari.png',
      shortCode: 'AKBL',
      brandColor: 0xFF004D25,
    ),
    BankLogo(
      id: 'faysal',
      name: 'Faysal Bank',
      nameAr: 'بنك فيصل',
      nameUr: 'فیصل بینک',
      country: 'pk',
      assetPath: 'assets/banks/faysal.png',
      shortCode: 'FBL',
      brandColor: 0xFF003366,
    ),
    BankLogo(
      id: 'alhabib',
      name: 'Bank AL Habib',
      nameAr: 'بنك الحبيب',
      nameUr: 'بینک الحبیب',
      country: 'pk',
      assetPath: 'assets/banks/alhabib.png',
      shortCode: 'BAHL',
      brandColor: 0xFF004422,
    ),
    BankLogo(
      id: 'scb',
      name: 'Standard Chartered Pakistan',
      nameAr: 'ستاندرد تشارترد باكستان',
      nameUr: 'اسٹینڈرڈ چارٹرڈ پاکستان',
      country: 'pk',
      assetPath: 'assets/banks/scb.png',
      shortCode: 'SCB',
      brandColor: 0xFF008542,
    ),
    BankLogo(
      id: 'js',
      name: 'JS Bank',
      nameAr: 'جي إس بنك',
      nameUr: 'جے ایس بینک',
      country: 'pk',
      assetPath: 'assets/banks/js.png',
      shortCode: 'JSBL',
      brandColor: 0xFF003366,
    ),
    BankLogo(
      id: 'soneri',
      name: 'Soneri Bank',
      nameAr: 'بنك سونيري',
      nameUr: 'سونیری بینک',
      country: 'pk',
      assetPath: 'assets/banks/soneri.png',
      shortCode: 'SNBL',
      brandColor: 0xFF002B49,
    ),
    BankLogo(
      id: 'habibmetro',
      name: 'Habib Metropolitan Bank',
      nameAr: 'بنك حبيب متروبوليتان',
      nameUr: 'حبیب میٹروپولیٹن بینک',
      country: 'pk',
      assetPath: 'assets/banks/habibmetro.png',
      shortCode: 'HMB',
      brandColor: 0xFFB31B2C,
    ),
  ];

  static List<BankLogo> get allBanks => [...saudiBanks, ...pakistanBanks];

  static BankLogo? findById(String id) {
    for (final bank in allBanks) {
      if (bank.id.toLowerCase() == id.toLowerCase()) return bank;
    }
    return null;
  }

  /// Search across all bank names and shortcodes in any language
  static List<BankLogo> search(String query, {String? countryFilter}) {
    final q = query.trim().toLowerCase();
    List<BankLogo> source = allBanks;
    if (countryFilter != null && countryFilter.isNotEmpty) {
      source = allBanks.where((b) => b.country == countryFilter).toList();
    }
    if (q.isEmpty) return source;

    return source.where((b) {
      return b.name.toLowerCase().contains(q) ||
          b.nameAr.toLowerCase().contains(q) ||
          b.nameUr.toLowerCase().contains(q) ||
          b.shortCode.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
    }).toList();
  }
}
