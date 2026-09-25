import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:hissab/data/database/app_database.dart';
import 'package:hissab/data/database/tables.dart';
import 'package:hissab/data/models/category_model.dart';

enum DetectionConfidence { high, medium, low }

class CategoryDetectionResult {
  final CategoryModel category;
  final DetectionConfidence confidence;
  final String matchedKeyword;

  const CategoryDetectionResult({
    required this.category,
    required this.confidence,
    required this.matchedKeyword,
  });
}

/// 100% Offline-First Multilingual Category Auto-Detection & Adaptive Learning Engine.
class CategoryDetectionService {
  final Database? _database;
  final Uuid _uuid = const Uuid();

  CategoryDetectionService({Database? database}) : _database = database;

  Future<Database> get _db async => _database ?? await AppDatabase.instance.database;

  /// Comprehensive multilingual keyword dictionary (English, Arabic, Urdu)
  static final Map<String, List<String>> _keywordDictionary = {
    // Food & Dining / Groceries
    'Food': [
      'food', 'lunch', 'dinner', 'breakfast', 'meal', 'restaurant', 'cafe',
      'coffee', 'tea', 'snack', 'burger', 'pizza', 'grocery', 'groceries',
      'supermarket', 'fruits', 'vegetables', 'milk', 'bread', 'water',
      // Arabic
      'طعام', 'غداء', 'عشاء', 'فطور', 'وجبة', 'مطعم', 'مقهى', 'قهوة', 'شاي',
      'سوبرماركت', 'بقالة', 'خضار', 'فواكه', 'حليب', 'خبز',
      // Urdu
      'کھانا', 'روٹی', 'ناشتہ', 'دوپہر کا کھانا', 'رات کا کھانا', 'ہوٹل',
      'چائے', 'کافی', 'راشن', 'سبزی', 'پھل', 'دودھ', 'بیکری'
    ],

    // Fuel & Gas
    'Fuel': [
      'fuel', 'petrol', 'gas', 'diesel', 'gasoline', 'oil', 'station',
      // Arabic
      'بنزين', 'وقود', 'ديزل', 'غاز', 'محطة', 'زيت',
      // Urdu
      'پیٹرول', 'ڈیزل', 'ایندھن', 'گیس', 'پمپ', 'موبل آئل'
    ],

    // Transport & Vehicles
    'Transport': [
      'transport', 'taxi', 'uber', 'careem', 'cab', 'bus', 'train', 'metro',
      'fare', 'toll', 'parking', 'flight', 'ticket',
      // Arabic
      'مواصلات', 'نقل', 'تاكسي', 'أوبر', 'كريم', 'باص', 'قطار', 'مترو',
      'موقف', 'تذكرة',
      // Urdu
      'سواری', 'کرایہ', 'ٹیکسی', 'اوبر', 'کریم', 'بس', 'ٹرین', 'میٹرو',
      'پارکنگ', 'گاڑی کرایہ', 'رکشہ'
    ],

    // Salary & Wages
    'Salary': [
      'salary', 'wages', 'payroll', 'stipend', 'bonus', 'commission', 'allowance',
      // Arabic
      'راتب', 'رواتب', 'أجر', 'أجور', 'مكافأة', 'عمولة', 'بدل',
      // Urdu
      'تنخواہ', 'اجرت', 'معاوضہ', 'بونس', 'کمیشن', 'مشاہرہ'
    ],

    // Sales & Business Revenue
    'Sales': [
      'sale', 'sales', 'sold', 'revenue', 'income', 'customer payment',
      'client payment', 'order', 'invoice', 'product',
      // Arabic
      'مبيعات', 'بيع', 'إيراد', 'دخل', 'دفعة عميل', 'فاتورة', 'زبون', 'طلب',
      // Urdu
      'فروخت', 'بکری', 'آمدنی', 'گاہک ادائیگی', 'انوائس', 'گاہک وصولی', 'مال فروخت'
    ],

    // Rent
    'Rent': [
      'rent', 'rental', 'lease', 'office rent', 'shop rent', 'house rent',
      // Arabic
      'إيجار', 'ايجار', 'عقار', 'إيجار مكتب', 'إيجار محل',
      // Urdu
      'کرایہ', 'دکان کرایہ', 'مکان کرایہ', 'دفتر کرایہ', 'لیز'
    ],

    // Utilities & Bills
    'Utilities': [
      'utility', 'utilities', 'electricity', 'power', 'water', 'internet',
      'wifi', 'bill', 'phone', 'mobile recharge', 'stc', 'zain', 'mobily',
      // Arabic
      'فاتورة', 'كهرباء', 'ماء', 'إنترنت', 'نت', 'هاتف', 'جوال', 'شحن',
      // Urdu
      'بل', 'بجلی', 'پانی', 'انٹرنیٹ', 'نیٹ', 'موبائل کارڈ', 'موبائل لوڈ', 'ٹیلیفون'
    ],

    // Maintenance & Repairs
    'Maintenance': [
      'repair', 'maintenance', 'fix', 'service', 'spare part', 'hardware',
      'mechanic', 'workshop',
      // Arabic
      'صيانة', 'تصليح', 'ورشة', 'قطع غيار', 'ميكانيكي',
      // Urdu
      'مرمت', 'صيانة', 'میکینک', 'ورکشاپ', 'اسپیئر پارٹ', 'سروس'
    ],

    // Medical & Healthcare
    'Medical': [
      'medical', 'doctor', 'hospital', 'clinic', 'medicine', 'pharmacy',
      'prescription', 'dental', 'health',
      // Arabic
      'طبيب', 'دكتور', 'مستشفى', 'عيادة', 'دواء', 'صيدلية', 'علاج',
      // Urdu
      'ڈاکٹر', 'ہسپتال', 'کلینک', 'دوائی', 'میڈیکل', 'علاج', 'فارمیسی'
    ],

    // Office & Supplies
    'Office': [
      'office', 'stationery', 'paper', 'printer', 'ink', 'pen', 'supplies',
      // Arabic
      'مكتب', 'قرطاسية', 'ورق', 'طابعة', 'حبر', 'أدوات مكتبية',
      // Urdu
      'دفتر', 'اسٹیشنری', 'کاغذ', 'پرنٹر', 'سپلائیز'
    ],
  };

  /// Detects the most accurate category for a given description within the active book.
  Future<CategoryDetectionResult?> detectCategory({
    required String bookId,
    required String description,
    required List<CategoryModel> availableCategories,
  }) async {
    final clean = description.trim().toLowerCase();
    if (clean.isEmpty || availableCategories.isEmpty) return null;

    final db = await _db;

    // 1. TIER 1: Check learned user corrections for this book
    final learnings = await db.query(
      Tables.categoryLearnings,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'updated_at DESC',
    );

    for (final learn in learnings) {
      final keyword = (learn['keyword'] as String).toLowerCase();
      if (clean.contains(keyword) || keyword.contains(clean)) {
        final catId = learn['category_id'] as String;
        final matched = availableCategories.where((c) => c.id == catId);
        if (matched.isNotEmpty) {
          return CategoryDetectionResult(
            category: matched.first,
            confidence: DetectionConfidence.high,
            matchedKeyword: keyword,
          );
        }
      }
    }

    // 2. TIER 2: Keyword Dictionary Match against available categories
    final words = clean.split(RegExp(r'[\s,._-]+')).where((w) => w.length > 1).toList();

    for (final word in words) {
      for (final entry in _keywordDictionary.entries) {
        final categoryTheme = entry.key;
        final keywords = entry.value;

        if (keywords.any((k) => k == word || word.contains(k) || k.contains(word))) {
          // Find matching category in the book's categories
          final found = availableCategories.where((c) {
            final catName = c.name.toLowerCase();
            return catName.contains(categoryTheme.toLowerCase()) ||
                keywords.any((k) => catName.contains(k));
          });

          if (found.isNotEmpty) {
            return CategoryDetectionResult(
              category: found.first,
              confidence: DetectionConfidence.high,
              matchedKeyword: word,
            );
          }
        }
      }
    }

    // 3. TIER 3: Direct Category Name substring match
    for (final cat in availableCategories) {
      final catName = cat.name.toLowerCase();
      if (clean.contains(catName) || catName.contains(clean)) {
        return CategoryDetectionResult(
          category: cat,
          confidence: DetectionConfidence.medium,
          matchedKeyword: cat.name,
        );
      }
    }

    // 4. Fallback: Medium/Low match or null
    return null;
  }

  /// Remembers a user correction so the engine becomes smarter for this book over time.
  Future<void> learnCorrection({
    required String bookId,
    required String description,
    required CategoryModel selectedCategory,
  }) async {
    final clean = description.trim();
    if (clean.isEmpty) return;

    final db = await _db;
    final now = DateTime.now().toIso8601String();

    // Check if learning exists for this keyword in this book
    final existing = await db.query(
      Tables.categoryLearnings,
      where: 'book_id = ? AND LOWER(keyword) = LOWER(?)',
      whereArgs: [bookId, clean],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as String;
      await db.update(
        Tables.categoryLearnings,
        {
          'category_id': selectedCategory.id,
          'category_name': selectedCategory.name,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.insert(
        Tables.categoryLearnings,
        {
          'id': _uuid.v4(),
          'book_id': bookId,
          'keyword': clean,
          'category_id': selectedCategory.id,
          'category_name': selectedCategory.name,
          'confidence': 1.0,
          'created_at': now,
          'updated_at': now,
        },
      );
    }
  }
}
