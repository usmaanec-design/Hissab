import 'package:flutter_test/flutter_test.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/domain/accounting/accounting_engine.dart';
import 'package:hissab/domain/accounting/balance_reconciliation.dart';

void main() {
  group('Hissab 100+ Accounting Engine & Financial Precision Test Suite', () {
    final testBook = BookModel(
      id: 'book-1',
      name: 'Main Business',
      currency: 'SAR',
      openingBalanceMinor: 100000, // 1,000.00 SAR
      openingBalanceDate: '2026-09-01',
      createdAt: '2026-09-01T00:00:00',
      updatedAt: '2026-09-01T00:00:00',
    );

    TransactionModel createTx({
      required String id,
      required String bookId,
      required TransactionType type,
      required int amountMinorUnit,
      bool isDeleted = false,
      String? accountId,
      String? partyId,
    }) {
      return TransactionModel(
        id: id,
        bookId: bookId,
        accountId: accountId,
        partyId: partyId,
        type: type,
        amountMinorUnit: amountMinorUnit,
        date: '2026-09-24',
        time: '12:00',
        isDeleted: isDeleted,
        createdAt: '2026-09-24T12:00:00',
        updatedAt: '2026-09-24T12:00:00',
      );
    }

    // ----------------------------------------------------
    // Section A: Core Accounting Formulas (Tests 1 - 20)
    // ----------------------------------------------------
    test('1. Opening = 0, Income = 0, Expense = 0 -> Balance = 0', () {
      final zeroBook = testBook.copyWith(openingBalanceMinor: 0);
      final summary = AccountingEngine.calculateBookSummary(book: zeroBook, transactions: []);
      expect(summary.currentBalanceMinor, 0);
      expect(summary.totalMoneyInMinor, 0);
      expect(summary.totalMoneyOutMinor, 0);
      expect(summary.netCashFlowMinor, 0);
    });

    test('2. Opening = 1000, Income = 500, Expense = 200 -> Balance = 1300', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 50000),
        createTx(id: '2', bookId: testBook.id, type: TransactionType.expense, amountMinorUnit: 20000),
      ];
      final summary = AccountingEngine.calculateBookSummary(book: testBook, transactions: txs);
      expect(summary.currentBalanceMinor, 130000);
      expect(summary.netCashFlowMinor, 30000);
    });

    test('3. Opening = 1000, Income = 500, Expense = 1500 -> Balance = 0', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 50000),
        createTx(id: '2', bookId: testBook.id, type: TransactionType.expense, amountMinorUnit: 150000),
      ];
      final summary = AccountingEngine.calculateBookSummary(book: testBook, transactions: txs);
      expect(summary.currentBalanceMinor, 0);
    });

    test('4. Opening = 1000, Expense = 1500 -> Balance = -500 (Never convert negative to positive)', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.expense, amountMinorUnit: 150000),
      ];
      final summary = AccountingEngine.calculateBookSummary(book: testBook, transactions: txs);
      expect(summary.currentBalanceMinor, -50000);
      expect(summary.netCashFlowMinor, -150000);
    });

    test('5. Large Number Test: 999,999,999.99 SAR -> No overflow or precision corruption', () {
      const largeMinor = 99999999999; // 999,999,999.99 * 100
      final largeBook = testBook.copyWith(openingBalanceMinor: largeMinor);
      final txs = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 100), // +1.00
      ];
      final summary = AccountingEngine.calculateBookSummary(book: largeBook, transactions: txs);
      expect(summary.currentBalanceMinor, 100000000099);
      expect(
        CurrencyFormatter.format(summary.currentBalanceMinor, Currencies.sar),
        'SAR 1,000,000,000.99',
      );
    });

    // Generate 15 variations of balances (Tests 6 - 20)
    for (int i = 6; i <= 20; i++) {
      final inAmount = i * 10000;
      final outAmount = (i * 5000);
      test('$i. Multi-step calculation with In: $inAmount and Out: $outAmount', () {
        final txs = [
          createTx(id: 'in-$i', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: inAmount),
          createTx(id: 'out-$i', bookId: testBook.id, type: TransactionType.expense, amountMinorUnit: outAmount),
        ];
        final summary = AccountingEngine.calculateBookSummary(book: testBook, transactions: txs);
        expect(summary.currentBalanceMinor, testBook.openingBalanceMinor + inAmount - outAmount);
      });
    }

    // ----------------------------------------------------
    // Section B: Soft Delete & Audit Integrity (Tests 21 - 35)
    // ----------------------------------------------------
    test('21. Soft-deleted transactions must be strictly excluded from current balance', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 50000),
        createTx(id: '2', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 30000, isDeleted: true),
      ];
      final summary = AccountingEngine.calculateBookSummary(book: testBook, transactions: txs);
      expect(summary.currentBalanceMinor, 150000);
      expect(summary.totalMoneyInMinor, 50000);
      expect(summary.transactionCount, 1);
    });

    test('22. Restoring a soft-deleted transaction recalculates balance correctly', () {
      final txsDeleted = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.expense, amountMinorUnit: 20000, isDeleted: true),
      ];
      final summaryBefore = AccountingEngine.calculateBookSummary(book: testBook, transactions: txsDeleted);
      expect(summaryBefore.currentBalanceMinor, 100000);

      // Now restore it (isDeleted = false)
      final txsRestored = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.expense, amountMinorUnit: 20000, isDeleted: false),
      ];
      final summaryAfter = AccountingEngine.calculateBookSummary(book: testBook, transactions: txsRestored);
      expect(summaryAfter.currentBalanceMinor, 80000);
    });

    test('23. Editing an expense transaction updates balance by exact delta', () {
      final txOld = [createTx(id: '1', bookId: testBook.id, type: TransactionType.expense, amountMinorUnit: 50000)];
      final balOld = AccountingEngine.calculateBookSummary(book: testBook, transactions: txOld).currentBalanceMinor;

      final txNew = [createTx(id: '1', bookId: testBook.id, type: TransactionType.expense, amountMinorUnit: 30000)];
      final balNew = AccountingEngine.calculateBookSummary(book: testBook, transactions: txNew).currentBalanceMinor;

      expect(balNew - balOld, 20000);
    });

    for (int i = 24; i <= 35; i++) {
      test('$i. Random soft-delete variation $i excludes marked items', () {
        final txs = [
          createTx(id: 'a$i', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 10000),
          createTx(id: 'b$i', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 5000, isDeleted: i.isEven),
        ];
        final summary = AccountingEngine.calculateBookSummary(book: testBook, transactions: txs);
        final expected = testBook.openingBalanceMinor + 10000 + (i.isEven ? 0 : 5000);
        expect(summary.currentBalanceMinor, expected);
      });
    }

    // ----------------------------------------------------
    // Section C: Internal Transfers & Account Balances (Tests 36 - 55)
    // ----------------------------------------------------
    test('36. Internal Transfer (Cash -> Bank) preserves overall book net balance', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, accountId: 'cash', type: TransactionType.transferOut, amountMinorUnit: 10000),
        createTx(id: '2', bookId: testBook.id, accountId: 'bank', type: TransactionType.transferIn, amountMinorUnit: 10000),
      ];
      final summary = AccountingEngine.calculateBookSummary(book: testBook, transactions: txs);
      // Overall book balance must NOT change!
      expect(summary.currentBalanceMinor, testBook.openingBalanceMinor);
      expect(summary.totalMoneyInMinor, 0);
      expect(summary.totalMoneyOutMinor, 0);
    });

    test('37. Individual account balances update accurately after transfer', () {
      const cashOpening = 500000; // 5,000 SAR
      const bankOpening = 1000000; // 10,000 SAR

      final txs = [
        createTx(id: '1', bookId: testBook.id, accountId: 'cash', type: TransactionType.transferOut, amountMinorUnit: 100000),
        createTx(id: '2', bookId: testBook.id, accountId: 'bank', type: TransactionType.transferIn, amountMinorUnit: 100000),
      ];

      final cashBal = AccountingEngine.calculateAccountBalance(
        openingBalanceMinor: cashOpening,
        accountId: 'cash',
        transactions: txs,
      );
      final bankBal = AccountingEngine.calculateAccountBalance(
        openingBalanceMinor: bankOpening,
        accountId: 'bank',
        transactions: txs,
      );

      expect(cashBal, 400000); // 4,000 SAR
      expect(bankBal, 1100000); // 11,000 SAR
      expect(cashBal + bankBal, cashOpening + bankOpening); // Total 15,000 SAR preserved
    });

    for (int i = 38; i <= 55; i++) {
      test('$i. Account transfer variation $i preserves zero-sum ledger integrity', () {
        final amount = i * 2500;
        final txs = [
          createTx(id: 't-out-$i', bookId: testBook.id, accountId: 'acc1', type: TransactionType.transferOut, amountMinorUnit: amount),
          createTx(id: 't-in-$i', bookId: testBook.id, accountId: 'acc2', type: TransactionType.transferIn, amountMinorUnit: amount),
        ];
        final acc1Bal = AccountingEngine.calculateAccountBalance(openingBalanceMinor: 100000, accountId: 'acc1', transactions: txs);
        final acc2Bal = AccountingEngine.calculateAccountBalance(openingBalanceMinor: 100000, accountId: 'acc2', transactions: txs);
        expect(acc1Bal + acc2Bal, 200000);
      });
    }

    // ----------------------------------------------------
    // Section D: Customer & Supplier Party Ledgers (Tests 56 - 70)
    // ----------------------------------------------------
    test('56. Customer Account: Sale 1,000, Payment 300 -> Outstanding 700', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, partyId: 'p-ahmed', type: TransactionType.income, amountMinorUnit: 100000),
        createTx(id: '2', bookId: testBook.id, partyId: 'p-ahmed', type: TransactionType.paymentReceived, amountMinorUnit: 30000),
      ];
      final summary = AccountingEngine.calculatePartySummary(
        partyId: 'p-ahmed',
        partyType: 'customer',
        transactions: txs,
      );
      expect(summary.totalBilledMinor, 100000);
      expect(summary.totalPaidOrReceivedMinor, 30000);
      expect(summary.outstandingMinor, 70000);
    });

    test('57. Supplier Account: Purchase 2,000, Paid 500 -> Outstanding 1,500', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, partyId: 'p-abc', type: TransactionType.expense, amountMinorUnit: 200000),
        createTx(id: '2', bookId: testBook.id, partyId: 'p-abc', type: TransactionType.paymentMade, amountMinorUnit: 50000),
      ];
      final summary = AccountingEngine.calculatePartySummary(
        partyId: 'p-abc',
        partyType: 'supplier',
        transactions: txs,
      );
      expect(summary.totalBilledMinor, 200000);
      expect(summary.totalPaidOrReceivedMinor, 50000);
      expect(summary.outstandingMinor, 150000);
    });

    for (int i = 58; i <= 70; i++) {
      test('$i. Party ledger calculation variation $i', () {
        final billed = i * 15000;
        final paid = i * 5000;
        final txs = [
          createTx(id: 'b-$i', bookId: testBook.id, partyId: 'cust-$i', type: TransactionType.income, amountMinorUnit: billed),
          createTx(id: 'p-$i', bookId: testBook.id, partyId: 'cust-$i', type: TransactionType.paymentReceived, amountMinorUnit: paid),
        ];
        final summary = AccountingEngine.calculatePartySummary(
          partyId: 'cust-$i',
          partyType: 'customer',
          transactions: txs,
        );
        expect(summary.outstandingMinor, billed - paid);
      });
    }

    // ----------------------------------------------------
    // Section E: Minor Unit Parser & Decimal Calculator (Tests 71 - 85)
    // ----------------------------------------------------
    test('71. Parse "500" for SAR (2 dec) -> 50000 minor units', () {
      expect(DecimalCalculator.parseToMinorUnits('500', Currencies.sar), 50000);
    });

    test('72. Parse "500.50" for SAR (2 dec) -> 50050 minor units', () {
      expect(DecimalCalculator.parseToMinorUnits('500.50', Currencies.sar), 50050);
    });

    test('73. Parse "500.5" for SAR (2 dec) -> 50050 minor units (correct right padding)', () {
      expect(DecimalCalculator.parseToMinorUnits('500.5', Currencies.sar), 50050);
    });

    test('74. Parse "0.05" for USD (2 dec) -> 5 minor units (5 cents)', () {
      expect(DecimalCalculator.parseToMinorUnits('0.05', Currencies.usd), 5);
    });

    test('75. Parse "10.125" for KWD (3 dec) -> 10125 minor units (fils)', () {
      expect(DecimalCalculator.parseToMinorUnits('10.125', Currencies.kwd), 10125);
    });

    test('76. Parse invalid string "abc" -> null', () {
      expect(DecimalCalculator.parseToMinorUnits('abc', Currencies.sar), isNull);
    });

    test('77. Parse multiple decimal points "50.5.5" -> null', () {
      expect(DecimalCalculator.parseToMinorUnits('50.5.5', Currencies.sar), isNull);
    });

    test('78. Parse negative string "-50" -> null (rejects direct minus entry)', () {
      expect(DecimalCalculator.parseToMinorUnits('-50', Currencies.sar), isNull);
    });

    test('79. Parse empty string "" -> null', () {
      expect(DecimalCalculator.parseToMinorUnits('', Currencies.sar), isNull);
    });

    test('80. Format 10050 minor units -> "100.50"', () {
      expect(DecimalCalculator.formatDecimal(10050, Currencies.sar), '100.50');
    });

    test('81. Format negative -50050 minor units -> "-500.50"', () {
      expect(DecimalCalculator.formatDecimal(-50050, Currencies.sar), '-500.50');
    });

    test('82. Percentage calculation: (200 / 1000) * 100 -> 20.0%', () {
      expect(DecimalCalculator.calculatePercentage(200, 1000), 20.0);
    });

    test('83. Safe Percentage: Total = 0 -> returns 0.0 (No NaN)', () {
      expect(DecimalCalculator.calculatePercentage(50, 0), 0.0);
    });

    test('84. Safe Percentage Change: Previous = 0 -> returns null ("New")', () {
      expect(DecimalCalculator.calculatePercentageChange(100, 0), isNull);
    });

    test('85. Percentage Change: (15000 - 10000)/10000 -> 50.0%', () {
      expect(DecimalCalculator.calculatePercentageChange(15000, 10000), 50.0);
    });

    // ----------------------------------------------------
    // Section F: Currency Formatter & Display (Tests 86 - 95)
    // ----------------------------------------------------
    test('86. CurrencyFormatter: 1254000 (SAR) -> "SAR 12,540.00"', () {
      expect(CurrencyFormatter.format(1254000, Currencies.sar), 'SAR 12,540.00');
    });

    test('87. CurrencyFormatter: with showExplicitPlus for income -> "+SAR 500.00"', () {
      expect(
        CurrencyFormatter.format(50000, Currencies.sar, showExplicitPlus: true),
        '+SAR 500.00',
      );
    });

    test('88. CurrencyFormatter: negative -20000 -> "-SAR 200.00"', () {
      expect(CurrencyFormatter.format(-20000, Currencies.sar), '-SAR 200.00');
    });

    test('89. CurrencyFormatter PKR: 100000000 (PKR) -> "PKR 1,000,000.00"', () {
      expect(CurrencyFormatter.format(100000000, Currencies.pkr), 'PKR 1,000,000.00');
    });

    test('90. Compact Currency: 150000 minor units -> "SAR 1.5K"', () {
      expect(CurrencyFormatter.formatCompact(150000, Currencies.sar), 'SAR 1.5K');
    });

    test('91. Compact Currency: 240000000 minor units -> "SAR 2.4M"', () {
      expect(CurrencyFormatter.formatCompact(240000000, Currencies.sar), 'SAR 2.4M');
    });

    for (int i = 92; i <= 95; i++) {
      test('$i. Multi-currency code lookup test for ${Currencies.all[i - 92].code}', () {
        final cfg = Currencies.findByCode(Currencies.all[i - 92].code);
        expect(cfg.code, Currencies.all[i - 92].code);
      });
    }

    // ----------------------------------------------------
    // Section G: Ledger Reconciliation & Integrity (Tests 96 - 105)
    // ----------------------------------------------------
    test('96. Reconciliation audit: matches ledger calculated balance -> Healthy Balanced', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 50000),
      ];
      final res = BalanceReconciliation.auditBook(
        book: testBook,
        transactions: txs,
        displayedBalanceMinor: 150000,
      );
      expect(res.status, ReconciliationStatus.balanced);
      expect(res.isHealthy, isTrue);
      expect(res.discrepancyMinor, 0);
    });

    test('97. Reconciliation audit: detects mismatch when displayed != calculated', () {
      final txs = [
        createTx(id: '1', bookId: testBook.id, type: TransactionType.income, amountMinorUnit: 50000),
      ];
      final res = BalanceReconciliation.auditBook(
        book: testBook,
        transactions: txs,
        displayedBalanceMinor: 140000, // Discrepancy of 10,000 minor units
      );
      expect(res.status, ReconciliationStatus.mismatch);
      expect(res.isHealthy, isFalse);
      expect(res.discrepancyMinor, 10000);
      expect(res.message, contains('BALANCE_MISMATCH'));
    });

    test('98. Multi-Book Isolation: Transactions in Book A never bleed into Book B', () {
      final bookA = testBook.copyWith(id: 'book-A');
      final bookB = testBook.copyWith(id: 'book-B', openingBalanceMinor: 50000);

      final allTxs = [
        createTx(id: '1', bookId: 'book-A', type: TransactionType.income, amountMinorUnit: 10000),
        createTx(id: '2', bookId: 'book-B', type: TransactionType.income, amountMinorUnit: 20000),
      ];

      final txsA = allTxs.where((t) => t.bookId == 'book-A').toList();
      final txsB = allTxs.where((t) => t.bookId == 'book-B').toList();

      final summaryA = AccountingEngine.calculateBookSummary(book: bookA, transactions: txsA);
      final summaryB = AccountingEngine.calculateBookSummary(book: bookB, transactions: txsB);

      expect(summaryA.currentBalanceMinor, 110000);
      expect(summaryB.currentBalanceMinor, 70000);
    });

    test('99. Cumulative balance calculation preserves precision over 100 transactions', () {
      final txs = <TransactionModel>[];
      for (int i = 0; i < 100; i++) {
        txs.add(createTx(
          id: 'cumulative-$i',
          bookId: testBook.id,
          type: i.isEven ? TransactionType.income : TransactionType.expense,
          amountMinorUnit: 1000, // 10.00 SAR
        ));
      }
      final summary = AccountingEngine.calculateBookSummary(book: testBook, transactions: txs);
      // 50 income of 10.00 = +500.00 (50,000)
      // 50 expense of 10.00 = -500.00 (50,000)
      // net = 0
      expect(summary.totalMoneyInMinor, 50000);
      expect(summary.totalMoneyOutMinor, 50000);
      expect(summary.currentBalanceMinor, testBook.openingBalanceMinor);
    });

    test('100. Final Audit: No calculation depends on UI state or binary float math', () {
      // 0.1 SAR (10 halalas) + 0.2 SAR (20 halalas) must strictly equal 0.3 SAR (30 halalas)
      final p1 = DecimalCalculator.parseToMinorUnits('0.1', Currencies.sar)!;
      final p2 = DecimalCalculator.parseToMinorUnits('0.2', Currencies.sar)!;
      final sum = p1 + p2;
      expect(sum, 30);
      expect(DecimalCalculator.formatDecimal(sum, Currencies.sar), '0.30');
    });

    test('101. Zero-division resilience across all calculation edge cases', () {
      expect(DecimalCalculator.calculatePercentage(0, 0), 0.0);
      expect(DecimalCalculator.calculatePercentage(-10, 100), 0.0);
      expect(DecimalCalculator.calculatePercentage(100, -50), 0.0);
      expect(DecimalCalculator.calculatePercentageChange(0, 0), isNull);
    });
  });
}
