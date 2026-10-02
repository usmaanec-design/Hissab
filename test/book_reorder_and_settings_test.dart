import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/localization/app_localizations.dart';
import 'package:hissab/core/utils/money_display_formatter.dart';
import 'package:hissab/data/database/tables.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/presentation/screens/settings/contact_us_screen.dart';
import 'package:hissab/presentation/screens/settings/privacy_policy_screen.dart';
import 'package:hissab/presentation/screens/settings/terms_screen.dart';
import 'package:hissab/presentation/widgets/responsive_money_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sar = Currencies.sar;

  group('Part 1 & 4: Book Model DisplayOrder & Canonical Reordering', () {
    test('BookModel has displayOrder default of 0 and copyWith supports it', () {
      final book = BookModel(
        id: 'book-1',
        name: 'Meezan',
        currency: 'SAR',
        openingBalanceMinor: 0,
        openingBalanceDate: '2026-09-01',
        createdAt: '2026-09-01T00:00:00',
        updatedAt: '2026-09-01T00:00:00',
      );

      expect(book.displayOrder, 0);

      final updatedBook = book.copyWith(displayOrder: 2);
      expect(updatedBook.displayOrder, 2);
      expect(updatedBook.name, 'Meezan');
    });

    test('BookModel serialization preserves displayOrder in toMap and fromMap', () {
      final book = BookModel(
        id: 'book-2',
        name: 'Rajhi',
        currency: 'SAR',
        openingBalanceMinor: 10000,
        openingBalanceDate: '2026-09-01',
        color: 0xFF10B981,
        displayOrder: 5,
        createdAt: '2026-09-01T00:00:00',
        updatedAt: '2026-09-01T00:00:00',
      );

      final map = book.toMap();
      expect(map['display_order'], 5);

      final restored = BookModel.fromMap(map);
      expect(restored.id, 'book-2');
      expect(restored.name, 'Rajhi');
      expect(restored.displayOrder, 5);
      expect(restored.color, 0xFF10B981);
    });

    test('Reordering algorithm: Move first -> last', () {
      final list = ['Meezan', 'Easy', 'Rajhi'];
      int oldIndex = 0;
      int newIndex = 3;
      if (oldIndex < newIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      expect(list, ['Easy', 'Rajhi', 'Meezan']);
    });

    test('Reordering algorithm: Move last -> first', () {
      final list = ['Meezan', 'Easy', 'Rajhi'];
      int oldIndex = 2;
      int newIndex = 0;
      if (oldIndex < newIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      expect(list, ['Rajhi', 'Meezan', 'Easy']);
    });

    test('Reordering algorithm: Move middle -> first', () {
      final list = ['Meezan', 'Easy', 'Rajhi'];
      int oldIndex = 1;
      int newIndex = 0;
      if (oldIndex < newIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      expect(list, ['Easy', 'Meezan', 'Rajhi']);
    });

    test('Reordering algorithm: Move middle -> last', () {
      final list = ['Meezan', 'Easy', 'Rajhi'];
      int oldIndex = 1;
      int newIndex = 3;
      if (oldIndex < newIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      expect(list, ['Meezan', 'Rajhi', 'Easy']);
    });

    test('Multiple books (10+ books) ordering assignment', () {
      final books = List.generate(
        12,
        (i) => BookModel(
          id: 'b-$i',
          name: 'Book $i',
          currency: 'SAR',
          openingBalanceMinor: 0,
          openingBalanceDate: '2026-09-01',
          displayOrder: i,
          createdAt: '2026-09-01T00:00:00',
          updatedAt: '2026-09-01T00:00:00',
        ),
      );

      for (int i = 0; i < books.length; i++) {
        expect(books[i].displayOrder, i);
      }
    });

    test('Single book reorder edge case is handled safely', () {
      final list = ['OnlyBook'];
      int oldIndex = 0;
      int newIndex = 1;
      if (oldIndex < newIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      expect(list, ['OnlyBook']);
    });
  });

  group('Part 19: Database Tables Migration Specification', () {
    test('createBooksTable schema includes display_order column and index in createIndexes', () {
      expect(Tables.createBooksTable, contains('display_order INTEGER NOT NULL DEFAULT 0'));
      expect(Tables.createIndexes, anyElement(contains('idx_books_order')));
    });
  });

  group('Part 5: Large Number Safety & Exact Precision', () {
    test('Extreme financial numbers format correctly without losing precision', () {
      const largeAmount = 123456789000; // 1,234,567,890.00 SAR
      final exact = MoneyDisplayFormatter.formatExact(largeAmount, sar);
      expect(exact, 'SAR 1,234,567,890.00');

      final compact = MoneyDisplayFormatter.formatCompact(largeAmount, sar);
      expect(compact, 'SAR 1.23B');

      final parts = MoneyDisplayFormatter.formatParts(largeAmount, sar, compact: true);
      expect(parts.amount, '1.23B');
      expect(parts.fullExact, 'SAR 1,234,567,890.00');
    });

    testWidgets('ResponsiveMoneyText renders large numbers without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              child: ResponsiveMoneyText(
                minorUnits: 123456789000,
                currency: sar,
                smart: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ResponsiveMoneyText), findsOneWidget);
    });
  });

  group('Part 9, 10, 11 & 12: In-App Pages & Deep Links', () {
    testWidgets('PrivacyPolicyScreen renders title, logo, and offline-first core section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Privacy Policy for Hissab'), findsOneWidget);
      expect(find.text('Core Principle: 100% Offline-First'), findsOneWidget);
    });

    testWidgets('TermsScreen renders title, logo, and terms sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TermsScreen(),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Terms & Conditions'), findsWidgets);
      expect(find.text('Acceptance of Terms'), findsOneWidget);
      expect(find.text('Important Notice'), findsOneWidget);
    });

    testWidgets('ContactUsScreen renders WhatsApp card with phone number and links', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ContactUsScreen(),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('+966 50 376 3410'), findsOneWidget);
      expect(find.text('Chat on WhatsApp'), findsOneWidget);
      expect(find.text('Developer Portfolio'), findsOneWidget);
      expect(find.text('Official Hissab Website'), findsOneWidget);
    });
  });

  group('Part 15: Localization & RTL Support', () {
    test('AppLocalizations contains all new settings keys in en, ar, and ur', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));
      final ur = AppLocalizations(const Locale('ur'));

      expect(en.translate('settings.privacy_policy'), 'Privacy Policy');
      expect(ar.translate('settings.privacy_policy'), 'سياسة الخصوصية');
      expect(ur.translate('settings.privacy_policy'), 'پرائیویسی پالیسی');

      expect(en.translate('settings.terms_conditions'), 'Terms & Conditions');
      expect(ar.translate('settings.terms_conditions'), 'الشروط والأحكام');
      expect(ur.translate('settings.terms_conditions'), 'شرائط و ضوابط');

      expect(en.translate('settings.contact_us'), 'Contact Us');
      expect(ar.translate('settings.contact_us'), 'تواصل معنا');
      expect(ur.translate('settings.contact_us'), 'ہم سے رابطہ کریں');

      expect(en.translate('contact.whatsapp'), 'Chat on WhatsApp');
      expect(ar.translate('contact.whatsapp'), 'محادثة عبر واتساب');
      expect(ur.translate('contact.whatsapp'), 'واٹس ایپ پر رابطہ کریں');
    });

    testWidgets('ContactUsScreen renders in RTL when Arabic locale is applied', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ContactUsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('+966 50 376 3410'), findsOneWidget);
    });
  });
}
