import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/services/pdf_font_service.dart';
import 'package:hissab/core/services/speech_session_controller.dart';
import 'package:hissab/core/utils/money_display_formatter.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/data/repositories/backup_repository.dart';
import 'package:hissab/domain/services/dashboard_summary_service.dart';
import 'package:hissab/presentation/widgets/all_books_horizontal_bars.dart';
import 'package:hissab/presentation/widgets/responsive_money_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sar = Currencies.sar; // 2 decimal places, unitMultiplier = 100

  group('1. MoneyDisplayFormatter & Extreme Number Safety', () {
    test('Format exact: standard small, medium, and large amounts', () {
      // 10.00 SAR
      expect(MoneyDisplayFormatter.formatExact(1000, sar), 'SAR 10.00');

      // 1,250.00 SAR
      expect(MoneyDisplayFormatter.formatExact(125000, sar), 'SAR 1,250.00');

      // 125,000.00 SAR
      expect(MoneyDisplayFormatter.formatExact(12500000, sar), 'SAR 125,000.00');

      // 555,555,555,555.00 SAR (Exact mode)
      expect(
        MoneyDisplayFormatter.formatExact(55555555555500, sar),
        'SAR 555,555,555,555.00',
      );
    });

    test('Format compact: K, M, B, T scaling', () {
      // Under 10K shows exact
      expect(MoneyDisplayFormatter.formatCompact(125000, sar), 'SAR 1,250.00');

      // >= 10K shows K
      expect(MoneyDisplayFormatter.formatCompact(12500000, sar), 'SAR 125.00K');

      // Millions: 1.25M and 125.50M
      expect(MoneyDisplayFormatter.formatCompact(125000000, sar), 'SAR 1.25M');
      expect(MoneyDisplayFormatter.formatCompact(12550000000, sar), 'SAR 125.50M');

      // Billions: 555,555,555,555.00 -> 555.56B
      expect(MoneyDisplayFormatter.formatCompact(55555555555500, sar), 'SAR 555.56B');

      // Trillions: 1,200,000,000,000.00 -> 1.20T
      expect(MoneyDisplayFormatter.formatCompact(120000000000000, sar), 'SAR 1.20T');
    });

    test('Extreme boundary: 9999999999999999 minor units without crash', () {
      const extremeMinor = 9999999999999999;
      final exact = MoneyDisplayFormatter.formatExact(extremeMinor, sar);
      expect(exact, contains('SAR'));
      expect(exact, contains('.99'));

      final compact = MoneyDisplayFormatter.formatCompact(extremeMinor, sar);
      expect(compact, contains('T'));
    });

    test('Negative numbers and explicit signs', () {
      expect(MoneyDisplayFormatter.formatExact(-50000, sar), '-SAR 500.00');
      expect(MoneyDisplayFormatter.formatCompact(-55555555555500, sar), '-SAR 555.56B');
      expect(
        MoneyDisplayFormatter.formatExact(50000, sar, showExplicitPlus: true),
        '+SAR 500.00',
      );
    });

    test('Split parts for multi-line rendering', () {
      final parts = MoneyDisplayFormatter.formatParts(55555555555500, sar, compact: true);
      expect(parts.code, 'SAR');
      expect(parts.amount, '555.56B');
      expect(parts.fullExact, 'SAR 555,555,555,555.00');
    });
  });

  group('2. SpeechSessionController & Live Transcription UX', () {
    test('State management and language selector', () {
      final controller = SpeechSessionController();
      expect(controller.status, SpeechSessionStatus.idle);
      expect(controller.languageMode, SpeechLanguageMode.auto);

      controller.setLanguageMode(SpeechLanguageMode.urdu);
      expect(controller.languageMode, SpeechLanguageMode.urdu);
      expect(controller.languageMode.displayName, 'اردو');
      expect(controller.languageMode.localeId, 'ur_PK');

      controller.setLanguageMode(SpeechLanguageMode.arabic);
      expect(controller.languageMode.localeId, 'ar_SA');

      controller.setLanguageMode(SpeechLanguageMode.english);
      expect(controller.languageMode.localeId, 'en_US');
    });

    test('Manual edit protection: user edits are never overwritten by speech events', () {
      final controller = SpeechSessionController();

      // User manually types initial text
      controller.notifyUserManualEdit('آج احمد سے پانچ سو ریال وصول ہوئے');
      expect(controller.hasManualEdits, isTrue);
      expect(controller.visibleTranscript, 'آج احمد سے پانچ سو ریال وصول ہوئے');

      // User manually corrects "پانچ سو" to "چھ سو"
      controller.notifyUserManualEdit('آج احمد سے چھ سو ریال وصول ہوئے');
      expect(controller.visibleTranscript, 'آج احمد سے چھ سو ریال وصول ہوئے');

      // Subsequent speech results respect user manual edit and append, never replacing user correction!
      expect(controller.visibleTranscript, contains('چھ سو'));
      expect(controller.visibleTranscript, isNot(contains('پانچ سو')));
    });
  });

  group('3. PDF Unicode & RTL Detection', () {
    test('RTL script detection for Urdu, Arabic, English, and Mixed text', () {
      // Urdu text
      expect(PdfFontService.isRtlText('احمد سے پانچ سو ریال وصول ہوئے'), isTrue);

      // Arabic text
      expect(PdfFontService.isRtlText('تم استلام خمسمائة ريال من أحمد'), isTrue);

      // English text
      expect(PdfFontService.isRtlText('Received SAR 500 from Ahmed'), isFalse);

      // Mixed text: Urdu + English
      expect(PdfFontService.isRtlText('Ahmed سے SAR 500 وصول ہوئے'), isTrue);

      // Mixed text: Arabic + English
      expect(PdfFontService.isRtlText('دفعت SAR 500 إلى Ahmed'), isTrue);

      // Null or empty
      expect(PdfFontService.isRtlText(null), isFalse);
      expect(PdfFontService.isRtlText(''), isFalse);
    });

    test('PDF Statement generation with Urdu, Arabic, and Large Amounts', () async {
      final repo = BackupRepository();
      final book = BookModel(
        id: 'book-1',
        name: 'محمد عثمان جنرل اسٹور اینڈ ٹریڈنگ کمپنی ریاض',
        currency: 'SAR',
        color: 0xFF059669,
        openingBalanceMinor: 1000000000000, // 10 Billion
        openingBalanceDate: '2026-01-01',
        createdAt: '2026-01-01T00:00:00',
        updatedAt: '2026-01-01T00:00:00',
      );

      final txList = [
        TransactionModel(
          id: 'tx-1',
          bookId: 'book-1',
          type: TransactionType.income,
          amountMinorUnit: 55555555555500, // 555.56 Billion
          date: '2026-09-25',
          time: '10:00',
          description: 'احمد سے پانچ سو ریال وصول ہوئے - Payment received from Ahmed',
          paymentMethod: 'Cash',
          createdAt: '2026-09-25T10:00:00',
          updatedAt: '2026-09-25T10:00:00',
        ),
        TransactionModel(
          id: 'tx-2',
          bookId: 'book-1',
          type: TransactionType.expense,
          amountMinorUnit: 250000000000,
          date: '2026-09-25',
          time: '11:00',
          description: 'تم استلام خمسمائة ريال من أحمد - Office Rent',
          paymentMethod: 'Bank Transfer',
          createdAt: '2026-09-25T11:00:00',
          updatedAt: '2026-09-25T11:00:00',
        ),
      ];

      final pdfBytes = await repo.generatePdfReport(
        book: book,
        transactions: txList,
        currency: sar,
        dateRangeLabel: 'Sep 2026',
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('Printable Receipt PDF with Unicode names and large amounts', () async {
      final repo = BackupRepository();

      final receiptBytes = await repo.generateReceiptPdf(
        businessName: 'محمد عثمان جنرل اسٹور',
        receiptNumber: 'RCP-2026-999',
        date: '25 Sep 2026',
        receivedFrom: 'محمد احمد بن عبدالرحمن علی خان',
        amountMinorUnit: 55555555555500,
        currency: sar,
        paymentMethod: 'Mada',
        purpose: 'دفعت SAR 500 إلى Ahmed - تسديد حساب تجاري',
        notes: 'Thank you for your business!',
      );

      expect(receiptBytes, isNotEmpty);
      expect(receiptBytes.length, greaterThan(1000));
    });
  });

  group('4. Widget Overflow Protection Tests', () {
    testWidgets('ResponsiveMoneyText scales down in very narrow width without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 60, // Very tight width
                child: ResponsiveMoneyText(
                  minorUnits: 55555555555500,
                  currency: sar,
                  smart: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull); // No RenderFlex overflow
      expect(find.byType(ResponsiveMoneyText), findsOneWidget);
    });

    testWidgets('AllBooksHorizontalBars renders multiple books and extreme numbers safely', (tester) async {
      final book1 = BookModel(
        id: 'b1',
        name: 'Usman Store',
        currency: 'SAR',
        color: 0xFF2563EB,
        openingBalanceMinor: 0,
        openingBalanceDate: '2026-01-01',
        createdAt: '2026-01-01T00:00:00',
        updatedAt: '2026-01-01T00:00:00',
      );
      final book2 = BookModel(
        id: 'b2',
        name: 'محمد عثمان ٹریڈنگ',
        currency: 'SAR',
        color: 0xFF059669,
        openingBalanceMinor: 0,
        openingBalanceDate: '2026-01-01',
        createdAt: '2026-01-01T00:00:00',
        updatedAt: '2026-01-01T00:00:00',
      );

      final globalData = GlobalDashboardData(
        globalIncomeMinor: 55555555555500,
        globalExpenseMinor: 320000,
        globalBalanceMinor: 55555555235500,
        bookSummaries: [
          BookFinancialSummary(
            book: book1,
            totalIncomeMinor: 55555555555500,
            totalExpenseMinor: 0,
            currentBalanceMinor: 55555555555500,
          ),
          BookFinancialSummary(
            book: book2,
            totalIncomeMinor: 1250000,
            totalExpenseMinor: 320000,
            currentBalanceMinor: 930000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AllBooksHorizontalBars(
                globalData: globalData,
                displayCurrency: sar,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // Zero overflow
      expect(find.text('All Books Overview'), findsOneWidget);
      expect(find.text('Usman Store'), findsOneWidget);
      expect(find.text('محمد عثمان ٹریڈنگ'), findsOneWidget);
    });
  });
}
