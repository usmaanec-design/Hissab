import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hissab/core/services/book_appearance_service.dart';
import 'package:hissab/data/database/app_database.dart';
import 'package:hissab/data/database/tables.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/models/category_model.dart';
import 'package:hissab/domain/services/category_detection_service.dart';
import 'package:hissab/domain/services/dashboard_summary_service.dart';
import 'package:hissab/domain/services/description_suggestion_service.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';

void main() {
  late Database testDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    testDb = await AppDatabase.createInMemoryDatabase();
  });

  tearDown(() async {
    await testDb.close();
  });

  group('1. Book Appearance & Model Tests', () {
    test('BookModel serializes and deserializes color and logo accurately', () {
      final book = BookModel(
        id: 'book-123',
        name: 'Usman Store',
        currency: 'SAR',
        openingBalanceMinor: 50000,
        openingBalanceDate: '2026-09-25',
        color: 0xFF059669,
        logo: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        createdAt: '2026-09-25T00:00:00',
        updatedAt: '2026-09-25T00:00:00',
      );

      final map = book.toMap();
      expect(map['color'], 0xFF059669);
      expect(map['logo'], isNotNull);

      final fromDb = BookModel.fromMap(map);
      expect(fromDb.id, 'book-123');
      expect(fromDb.name, 'Usman Store');
      expect(fromDb.color, 0xFF059669);
      expect(fromDb.logo, book.logo);
    });

    test('BookAppearanceService correctly calculates contrast text color', () {
      // Dark colors should have white text
      const darkBlue = Color(0xFF1E3A8A);
      expect(BookAppearanceService.getContrastTextColor(darkBlue), Colors.white);

      // Light colors should have dark slate text
      const lightYellow = Color(0xFFFEF08A);
      expect(BookAppearanceService.getContrastTextColor(lightYellow), const Color(0xFF1E293B));
    });

    test('BookAppearanceService extracts initial letter correctly', () {
      expect(BookAppearanceService.getInitial('Usman Store'), 'U');
      expect(BookAppearanceService.getInitial('  Personal  '), 'P');
      expect(BookAppearanceService.getInitial(''), 'B');
    });

    test('BookAppearanceService provides curated color palette', () {
      final palette = BookAppearanceService.palette;
      expect(palette.length, greaterThanOrEqualTo(8));
      expect(palette.contains(0xFF2563EB), isTrue); // Sapphire Blue
      expect(palette.contains(0xFF059669), isTrue); // Emerald Green
      expect(palette.contains(0xFFD97706), isTrue); // Amber Gold
    });
  });

  group('2. Deterministic & Multilingual Category Auto-Detection Tests', () {
    final List<CategoryModel> categories = [
      const CategoryModel(id: 'cat-fuel', bookId: 'b1', name: 'Fuel', type: 'expense', icon: 'local_gas_station', color: 0xFFF97316, createdAt: ''),
      const CategoryModel(id: 'cat-salary', bookId: 'b1', name: 'Salary', type: 'income', icon: 'payments', color: 0xFF10B981, createdAt: ''),
      const CategoryModel(id: 'cat-rent', bookId: 'b1', name: 'Rent', type: 'expense', icon: 'home', color: 0xFF8B5CF6, createdAt: ''),
      const CategoryModel(id: 'cat-food', bookId: 'b1', name: 'Food & Dining', type: 'expense', icon: 'restaurant', color: 0xFFEF4444, createdAt: ''),
      const CategoryModel(id: 'cat-util', bookId: 'b1', name: 'Utilities', type: 'expense', icon: 'lightbulb', color: 0xFFEAB308, createdAt: ''),
      const CategoryModel(id: 'cat-sales', bookId: 'b1', name: 'Sales', type: 'income', icon: 'point_of_sale', color: 0xFF06B6D4, createdAt: ''),
    ];

    test('Detects English keywords correctly', () async {
      final catService = CategoryDetectionService(database: testDb);

      final resFuel = await catService.detectCategory(
        bookId: 'b1',
        description: 'Paid petrol for delivery van',
        availableCategories: categories,
      );
      expect(resFuel, isNotNull);
      expect(resFuel!.category.id, 'cat-fuel');
      expect(resFuel.confidence, DetectionConfidence.high);

      final resSalary = await catService.detectCategory(
        bookId: 'b1',
        description: 'Monthly salary received',
        availableCategories: categories,
      );
      expect(resSalary, isNotNull);
      expect(resSalary!.category.id, 'cat-salary');
    });

    test('Detects Arabic keywords correctly without translation', () async {
      final catService = CategoryDetectionService(database: testDb);

      final resArabicFuel = await catService.detectCategory(
        bookId: 'b1',
        description: 'بنزين للسيارة',
        availableCategories: categories,
      );
      expect(resArabicFuel, isNotNull);
      expect(resArabicFuel!.category.id, 'cat-fuel');

      final resArabicRent = await catService.detectCategory(
        bookId: 'b1',
        description: 'إيجار المحل الشهري',
        availableCategories: categories,
      );
      expect(resArabicRent, isNotNull);
      expect(resArabicRent!.category.id, 'cat-rent');
    });

    test('Detects Urdu keywords correctly without translation', () async {
      final catService = CategoryDetectionService(database: testDb);

      final resUrduSalary = await catService.detectCategory(
        bookId: 'b1',
        description: 'تنخواہ وصول ہوئی',
        availableCategories: categories,
      );
      expect(resUrduSalary, isNotNull);
      expect(resUrduSalary!.category.id, 'cat-salary');

      final resUrduRent = await catService.detectCategory(
        bookId: 'b1',
        description: 'دکان کا کرایہ',
        availableCategories: categories,
      );
      expect(resUrduRent, isNotNull);
      expect(resUrduRent!.category.id, 'cat-rent');
    });

    test('Returns null / uncategorized when no match found', () async {
      final catService = CategoryDetectionService(database: testDb);

      final resUnknown = await catService.detectCategory(
        bookId: 'b1',
        description: 'xyz abc random text 12345',
        availableCategories: categories,
      );
      expect(resUnknown, isNull);
    });

    test('Learned user correction overrides default keyword detection in SQLite', () async {
      await testDb.insert(Tables.books, {
        'id': 'book-A',
        'name': 'Book A',
        'currency': 'SAR',
        'opening_balance_minor': 0,
        'opening_balance_date': '2026-09-25',
        'is_archived': 0,
        'is_deleted': 0,
        'created_at': '2026-09-25',
        'updated_at': '2026-09-25',
      });
      await testDb.insert(Tables.books, {
        'id': 'book-B',
        'name': 'Book B',
        'currency': 'SAR',
        'opening_balance_minor': 0,
        'opening_balance_date': '2026-09-25',
        'is_archived': 0,
        'is_deleted': 0,
        'created_at': '2026-09-25',
        'updated_at': '2026-09-25',
      });

      final isolatedCatService = CategoryDetectionService(database: testDb);

      // Default match for "Monthly electricity bill" matches Utilities
      final initial = await isolatedCatService.detectCategory(
        bookId: 'book-A',
        description: 'Monthly electricity bill',
        availableCategories: categories,
      );
      expect(initial?.category.id, 'cat-util');

      // User changes to Rent for book-A
      await isolatedCatService.learnCorrection(
        bookId: 'book-A',
        description: 'Monthly electricity bill',
        selectedCategory: categories.firstWhere((c) => c.id == 'cat-rent'),
      );

      // Subsequent query in book-A must return the learned category (Rent) with highest priority
      final afterLearning = await isolatedCatService.detectCategory(
        bookId: 'book-A',
        description: 'Monthly electricity bill',
        availableCategories: categories,
      );
      expect(afterLearning?.category.id, 'cat-rent');
      expect(afterLearning?.confidence, DetectionConfidence.high);

      // Book isolation: book-B has NOT learned this correction, so it should still detect Utilities
      final bookBMatch = await isolatedCatService.detectCategory(
        bookId: 'book-B',
        description: 'Monthly electricity bill',
        availableCategories: categories,
      );
      expect(bookBMatch?.category.id, 'cat-util');
    });
  });

  group('3. Smart Description Suggestions & Book Isolation Tests', () {
    test('Ranks descriptions by frequency and recency per book and tx_type', () async {
      // Create books to satisfy foreign key constraints
      await testDb.insert(Tables.books, {
        'id': 'b1',
        'name': 'Book 1',
        'currency': 'SAR',
        'opening_balance_minor': 0,
        'opening_balance_date': '2026-09-25',
        'is_archived': 0,
        'is_deleted': 0,
        'created_at': '2026-09-25',
        'updated_at': '2026-09-25',
      });
      await testDb.insert(Tables.books, {
        'id': 'b2',
        'name': 'Book 2',
        'currency': 'SAR',
        'opening_balance_minor': 0,
        'opening_balance_date': '2026-09-25',
        'is_archived': 0,
        'is_deleted': 0,
        'created_at': '2026-09-25',
        'updated_at': '2026-09-25',
      });

      final descService = DescriptionSuggestionService(database: testDb);

      // Record descriptions for Book 1
      await descService.recordDescription(bookId: 'b1', description: 'Fuel', txType: 'EXPENSE');
      await descService.recordDescription(bookId: 'b1', description: 'Fuel', txType: 'EXPENSE');
      await descService.recordDescription(bookId: 'b1', description: 'Fuel', txType: 'EXPENSE'); // Frequency 3
      await descService.recordDescription(bookId: 'b1', description: 'Office Rent', txType: 'EXPENSE'); // Frequency 1

      // Record descriptions for Book 2
      await descService.recordDescription(bookId: 'b2', description: 'Grocery', txType: 'EXPENSE');

      // Check Book 1 suggestions
      final b1Suggestions = await descService.getSuggestions(bookId: 'b1', txType: 'EXPENSE');
      expect(b1Suggestions.length, 2);
      expect(b1Suggestions.first, 'Fuel'); // Most frequent first
      expect(b1Suggestions.contains('Grocery'), isFalse); // Never leaks from Book 2

      // Check Book 2 suggestions
      final b2Suggestions = await descService.getSuggestions(bookId: 'b2', txType: 'EXPENSE');
      expect(b2Suggestions.length, 1);
      expect(b2Suggestions.first, 'Grocery');
      expect(b2Suggestions.contains('Fuel'), isFalse); // Never leaks from Book 1
    });
  });

  group('4. Global Dashboard Aggregation & Multi-Book Isolation Tests', () {
    test('Aggregates income and expense across all books accurately into global totals', () async {
      final summaryService = DashboardSummaryService(database: testDb);

      // Create Book 1 (Store)
      await testDb.insert(Tables.books, {
        'id': 'b1',
        'name': 'Usman Store',
        'currency': 'SAR',
        'opening_balance_minor': 10000,
        'opening_balance_date': '2026-09-25',
        'color': 0xFF2563EB,
        'is_archived': 0,
        'is_deleted': 0,
        'created_at': '2026-09-25T00:00:00',
        'updated_at': '2026-09-25T00:00:00',
      });

      // Create Book 2 (Personal)
      await testDb.insert(Tables.books, {
        'id': 'b2',
        'name': 'Personal',
        'currency': 'SAR',
        'opening_balance_minor': 5000,
        'opening_balance_date': '2026-09-25',
        'color': 0xFF10B981,
        'is_archived': 0,
        'is_deleted': 0,
        'created_at': '2026-09-25T00:00:00',
        'updated_at': '2026-09-25T00:00:00',
      });

      // Insert transactions in Book 1
      await testDb.insert(Tables.transactions, {
        'id': 'tx-1',
        'book_id': 'b1',
        'type': 'INCOME',
        'amount_minor': 100000, // 1,000.00
        'date': '2026-09-25',
        'time': '10:00',
        'is_deleted': 0,
        'created_at': '2026-09-25T10:00:00',
        'updated_at': '2026-09-25T10:00:00',
      });
      await testDb.insert(Tables.transactions, {
        'id': 'tx-2',
        'book_id': 'b1',
        'type': 'EXPENSE',
        'amount_minor': 40000, // 400.00
        'date': '2026-09-25',
        'time': '11:00',
        'is_deleted': 0,
        'created_at': '2026-09-25T11:00:00',
        'updated_at': '2026-09-25T11:00:00',
      });

      // Insert transactions in Book 2
      await testDb.insert(Tables.transactions, {
        'id': 'tx-3',
        'book_id': 'b2',
        'type': 'INCOME',
        'amount_minor': 50000, // 500.00
        'date': '2026-09-25',
        'time': '12:00',
        'is_deleted': 0,
        'created_at': '2026-09-25T12:00:00',
        'updated_at': '2026-09-25T12:00:00',
      });
      await testDb.insert(Tables.transactions, {
        'id': 'tx-4',
        'book_id': 'b2',
        'type': 'EXPENSE',
        'amount_minor': 20000, // 200.00
        'date': '2026-09-25',
        'time': '13:00',
        'is_deleted': 0,
        'created_at': '2026-09-25T13:00:00',
        'updated_at': '2026-09-25T13:00:00',
      });

      final globalData = await summaryService.getGlobalDashboardData();

      // Check Global Totals:
      // Total Income = 100,000 + 50,000 = 150,000
      expect(globalData.globalIncomeMinor, 150000);
      // Total Expense = 40,000 + 20,000 = 60,000
      expect(globalData.globalExpenseMinor, 60000);
      // Total Balance = (10,000 + 100,000 - 40,000) + (5,000 + 50,000 - 20,000) = 70,000 + 35,000 = 105,000
      expect(globalData.globalBalanceMinor, 105000);

      // Check per-book summaries in chart data
      expect(globalData.bookSummaries.length, 2);
      final b1Sum = globalData.bookSummaries.firstWhere((s) => s.book.id == 'b1');
      expect(b1Sum.totalIncomeMinor, 100000);
      expect(b1Sum.totalExpenseMinor, 40000);
      expect(b1Sum.currentBalanceMinor, 70000);

      final b2Sum = globalData.bookSummaries.firstWhere((s) => s.book.id == 'b2');
      expect(b2Sum.totalIncomeMinor, 50000);
      expect(b2Sum.totalExpenseMinor, 20000);
      expect(b2Sum.currentBalanceMinor, 35000);
    });
  });

  group('5. BookAvatarWidget Visual Fallback Tests', () {
    testWidgets('Renders first letter uppercase with book color when no logo provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookAvatarWidget(
              bookName: 'Usman Store',
              bookColor: 0xFF2563EB,
              size: 48,
            ),
          ),
        ),
      );

      expect(find.text('U'), findsOneWidget);
    });
  });
}
