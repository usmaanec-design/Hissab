import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/core/utils/date_formatter.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/models/party_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/data/repositories/backup_repository.dart';
import 'package:hissab/data/repositories/party_repository.dart';
import 'package:hissab/data/repositories/transaction_repository.dart';
import 'package:hissab/domain/accounting/accounting_engine.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _dateRange = 'THIS_MONTH'; // TODAY, THIS_WEEK, THIS_MONTH, THIS_YEAR, ALL
  String _selectedBookScope = 'ALL'; // 'ALL' or specific bookId
  String? _selectedCurrency; // e.g. 'SAR', 'PKR'

  final BackupRepository _backupRepository = BackupRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();
  final PartyRepository _partyRepository = PartyRepository();

  List<TransactionModel> _allTransactions = [];
  List<PartyModel> _allParties = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoadingData = true);
    try {
      final txs = await _transactionRepository.getAllActiveTransactionsFromAllBooks();
      final parties = await _partyRepository.getAllPartiesFromAllBooks();
      if (mounted) {
        setState(() {
          _allTransactions = txs;
          _allParties = parties;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  List<TransactionModel> _filterTransactionsByDate(List<TransactionModel> all) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (_dateRange == 'TODAY') {
      start = DateFormatter.startOfDay(now);
    } else if (_dateRange == 'THIS_WEEK') {
      start = DateFormatter.startOfWeek(now);
    } else if (_dateRange == 'THIS_MONTH') {
      start = DateFormatter.startOfMonth(now);
    } else if (_dateRange == 'THIS_YEAR') {
      start = DateFormatter.startOfYear(now);
    } else {
      return all.where((tx) => !tx.isDeleted).toList();
    }

    final startStr = DateFormatter.toIsoDate(start);
    final endStr = DateFormatter.toIsoDate(end);

    return all.where((tx) => !tx.isDeleted && tx.date.compareTo(startStr) >= 0 && tx.date.compareTo(endStr) <= 0).toList();
  }

  void _exportPdf(BuildContext context, List<BookModel> books, CurrencyConfig currency) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 28),
                    const SizedBox(width: 10),
                    const Text(
                      'Download PDF Report',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Har currency ka hissab (SAR, PKR, etc.) PDF mein alag alag sections mein generate hoga.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.library_books, color: AppColors.primary),
                  ),
                  title: const Text('Export All Books & Currencies Report', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('All books segregated strictly by currency with candle comparisons'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pdfBytes = await _backupRepository.generateMultiBookPdfReport(
                      books: books,
                      transactions: _allTransactions,
                      parties: _allParties,
                      dateRangeLabel: _dateRange.replaceAll('_', ' '),
                    );

                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfBytes,
                      name: 'Hissab_All_Books_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withAlpha(40),
                    child: Text(currency.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                  ),
                  title: Text('Export ${currency.code} (${currency.name}) Only', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Only books and transactions using ${currency.code}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pdfBytes = await _backupRepository.generateMultiBookPdfReport(
                      books: books,
                      transactions: _allTransactions,
                      parties: _allParties,
                      dateRangeLabel: _dateRange.replaceAll('_', ' '),
                      specificCurrency: currency.code,
                    );

                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfBytes,
                      name: 'Hissab_${currency.code}_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exportCsv(BuildContext context, BookModel book, List<TransactionModel> filteredTxs, CurrencyConfig currency) async {
    final csvString = _backupRepository.exportCsvData(
      book: book,
      transactions: filteredTxs,
      currency: currency,
    );

    await SharePlus.instance.share(
      ShareParams(
        text: csvString,
        subject: 'Hissab Cashbook CSV Export - ${book.name} (${currency.code})',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final catController = context.watch<CategoryController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allBooks = bookController.books;

    if (allBooks.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No books available. Create a book to view reports.')),
      );
    }

    // Determine targeted books based on scope
    final List<BookModel> activeBooks = _selectedBookScope == 'ALL'
        ? allBooks
        : allBooks.where((b) => b.id == _selectedBookScope).toList();

    // Identify all unique currencies among active books
    final List<String> availableCurrencies = activeBooks
        .map((b) => b.currency.toUpperCase())
        .toSet()
        .toList();

    if (availableCurrencies.isEmpty) {
      availableCurrencies.add('SAR');
    }

    if (_selectedCurrency == null || !availableCurrencies.contains(_selectedCurrency)) {
      _selectedCurrency = availableCurrencies.first;
    }

    final activeCurrencyCode = _selectedCurrency!;
    final currencyConfig = Currencies.findByCode(activeCurrencyCode);

    // Filter books belonging strictly to the selected currency
    final List<BookModel> booksInSelectedCurrency = activeBooks
        .where((b) => b.currency.toUpperCase() == activeCurrencyCode)
        .toList();

    final Set<String> bookIdsInCurrency = booksInSelectedCurrency.map((b) => b.id).toSet();

    // Filter transactions for this currency and date range
    final dateFilteredTxs = _filterTransactionsByDate(_allTransactions);
    final currencyFilteredTxs = dateFilteredTxs
        .where((tx) => bookIdsInCurrency.contains(tx.bookId))
        .toList();

    // Filter parties belonging to books of this currency
    final partiesInCurrency = _allParties
        .where((p) => bookIdsInCurrency.contains(p.bookId) && !p.isDeleted)
        .toList();

    // 1. Calculate Cash In and Cash Out
    int totalIn = 0;
    int totalOut = 0;
    final Map<String, int> expenseCategoryTotals = {};

    for (final tx in currencyFilteredTxs) {
      if (tx.type.isMoneyIn) {
        totalIn += tx.amountMinorUnit;
      } else if (tx.type.isMoneyOut) {
        totalOut += tx.amountMinorUnit;
        final catId = tx.categoryId ?? 'Uncategorized';
        expenseCategoryTotals[catId] = (expenseCategoryTotals[catId] ?? 0) + tx.amountMinorUnit;
      }
    }
    final netCashFlow = totalIn - totalOut;

    // 2. Calculate Total Udhar / Loan Given & Taken for this currency
    int totalLoanGiven = 0; // Receivable (You will get / Jo Diya)
    int totalLoanTaken = 0; // Payable (You will give / Jo Liya)

    for (final party in partiesInCurrency) {
      final pTxs = _allTransactions.where((tx) => !tx.isDeleted && tx.bookId == party.bookId).toList();
      final summary = AccountingEngine.calculatePartySummary(
        partyId: party.id,
        partyType: party.type,
        transactions: pTxs,
      );

      if (party.type.toLowerCase() == 'customer') {
        if (summary.outstandingMinor > 0) {
          totalLoanGiven += summary.outstandingMinor;
        }
      } else {
        if (summary.outstandingMinor > 0) {
          totalLoanTaken += summary.outstandingMinor;
        }
      }
    }

    // Book-wise breakdown under this currency
    final bookStats = <_BookReportStat>[];
    for (final b in booksInSelectedCurrency) {
      final bTxs = currencyFilteredTxs.where((tx) => tx.bookId == b.id).toList();
      int bIn = 0;
      int bOut = 0;
      for (final tx in bTxs) {
        if (tx.type.isMoneyIn) bIn += tx.amountMinorUnit;
        if (tx.type.isMoneyOut) bOut += tx.amountMinorUnit;
      }

      int bRec = 0;
      int bPay = 0;
      final bParties = partiesInCurrency.where((p) => p.bookId == b.id).toList();
      final bAllTxs = _allTransactions.where((tx) => !tx.isDeleted && tx.bookId == b.id).toList();
      for (final bp in bParties) {
        final s = AccountingEngine.calculatePartySummary(partyId: bp.id, partyType: bp.type, transactions: bAllTxs);
        if (bp.type.toLowerCase() == 'customer') {
          if (s.outstandingMinor > 0) bRec += s.outstandingMinor;
        } else {
          if (s.outstandingMinor > 0) bPay += s.outstandingMinor;
        }
      }

      bookStats.add(_BookReportStat(
        book: b,
        totalIn: bIn,
        totalOut: bOut,
        netFlow: bIn - bOut,
        loanGiven: bRec,
        loanTaken: bPay,
      ));
    }

    final allCats = [...catController.incomeCategories, ...catController.expenseCategories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial & Loan Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Reports',
            onPressed: _loadReportData,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download PDF Report',
            onPressed: () => _exportPdf(context, activeBooks, currencyConfig),
          ),
          if (booksInSelectedCurrency.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.table_view_outlined),
              tooltip: 'Export CSV',
              onPressed: () => _exportCsv(context, booksInSelectedCurrency.first, currencyFilteredTxs, currencyConfig),
            ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReportData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Book Scope & Currency Banner
                    _buildScopeAndCurrencySelector(
                      allBooks: allBooks,
                      availableCurrencies: availableCurrencies,
                      activeCurrency: activeCurrencyCode,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 14),

                    // Date Period Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPeriodChip('Today', 'TODAY'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('This Week', 'THIS_WEEK'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('This Month', 'THIS_MONTH'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('This Year', 'THIS_YEAR'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('All Time', 'ALL'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Strict Currency Notice Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_clock, color: Colors.blue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Currency Isolation: Showing ${_selectedBookScope == "ALL" ? "All Books" : "Selected Book"} for $activeCurrencyCode (${currencyConfig.symbol}). Har currency ka total alag alag count hota hai.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4 Main Metric Cards (Cash In, Cash Out, Udhar Diya, Udhar Liya)
                    _buildPrimaryMetricsGrid(
                      totalIn: totalIn,
                      totalOut: totalOut,
                      netCashFlow: netCashFlow,
                      loanGiven: totalLoanGiven,
                      loanTaken: totalLoanTaken,
                      currency: currencyConfig,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 24),

                    // Candle / Column Comparison Chart
                    _buildCandleChartSection(
                      totalIn: totalIn,
                      totalOut: totalOut,
                      loanGiven: totalLoanGiven,
                      loanTaken: totalLoanTaken,
                      currency: currencyConfig,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 24),

                    // Books Breakdown under this Currency
                    _buildBooksBreakdownSection(
                      bookStats: bookStats,
                      currency: currencyConfig,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 24),

                    // Expense Breakdown Donut Chart
                    if (expenseCategoryTotals.isNotEmpty) ...[
                      const Text(
                        'Expense Breakdown by Category',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildExpenseDonutChart(
                        expenseCategoryTotals: expenseCategoryTotals,
                        totalOut: totalOut,
                        allCats: allCats,
                        currency: currencyConfig,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Export PDF Bottom Action Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(
                        'Download Complete PDF Report (${currencyConfig.code})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () => _exportPdf(context, activeBooks, currencyConfig),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScopeAndCurrencySelector({
    required List<BookModel> allBooks,
    required List<String> availableCurrencies,
    required String activeCurrency,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Book Filter / Scope:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBookScope,
                  isDense: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                  items: [
                    const DropdownMenuItem(
                      value: 'ALL',
                      child: Text('📚 All Books Combined'),
                    ),
                    ...allBooks.map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.name} (${b.currency})'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBookScope = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Text(
                'Currency:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableCurrencies.map((c) {
                      final isSelected = c == activeCurrency;
                      final cfg = Currencies.findByCode(c);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text('${cfg.code} (${cfg.symbol})'),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedCurrency = c);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryMetricsGrid({
    required int totalIn,
    required int totalOut,
    required int netCashFlow,
    required int loanGiven,
    required int loanTaken,
    required CurrencyConfig currency,
    required bool isDark,
  }) {
    return Column(
      children: [
        // Cash Flow Row
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total In (آمدنی)',
                value: CurrencyFormatter.format(totalIn, currency),
                icon: Icons.arrow_downward,
                color: AppColors.moneyIn,
                bgColor: AppColors.moneyInContainer,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Total Out (خرچ)',
                value: CurrencyFormatter.format(totalOut, currency),
                icon: Icons.arrow_upward,
                color: AppColors.moneyOut,
                bgColor: AppColors.moneyOutContainer,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Net Cash Flow Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    netCashFlow >= 0 ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
                    color: netCashFlow >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Net Cash Flow (خالص بچت)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                CurrencyFormatter.format(netCashFlow, currency),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: netCashFlow >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Loan / Udhar Row
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Udhar Diya (قرض دیا)',
                subtitle: "You'll Get / Receivable",
                value: CurrencyFormatter.format(loanGiven, currency),
                icon: Icons.call_made,
                color: Colors.blueAccent,
                bgColor: Colors.blue.withAlpha(25),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Udhar Liya (قرض لیا)',
                subtitle: "You'll Give / Payable",
                value: CurrencyFormatter.format(loanTaken, currency),
                icon: Icons.call_received,
                color: Colors.orangeAccent,
                bgColor: Colors.orange.withAlpha(25),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    String? subtitle,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandleChartSection({
    required int totalIn,
    required int totalOut,
    required int loanGiven,
    required int loanTaken,
    required CurrencyConfig currency,
    required bool isDark,
  }) {
    final values = [
      totalIn.toDouble(),
      totalOut.toDouble(),
      loanGiven.toDouble(),
      loanTaken.toDouble(),
    ];
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxVal > 0 ? maxVal * 1.25 : 100.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Financial & Loan Candles',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'آمدنی، خرچ اور قرض موازنہ (${currency.code})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currency.code,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4 Visual Candle Pillars with Top Value Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildCandlePillar(
                label: 'Cash In',
                subLabel: 'آمدنی',
                valueMinor: totalIn,
                currency: currency,
                color: AppColors.moneyIn,
                ratio: maxVal > 0 ? (totalIn / maxVal).clamp(0.05, 1.0) : 0.05,
              ),
              _buildCandlePillar(
                label: 'Cash Out',
                subLabel: 'خرچ',
                valueMinor: totalOut,
                currency: currency,
                color: AppColors.moneyOut,
                ratio: maxVal > 0 ? (totalOut / maxVal).clamp(0.05, 1.0) : 0.05,
              ),
              _buildCandlePillar(
                label: 'Udhar Diya',
                subLabel: 'قرض دیا',
                valueMinor: loanGiven,
                currency: currency,
                color: Colors.blueAccent,
                ratio: maxVal > 0 ? (loanGiven / maxVal).clamp(0.05, 1.0) : 0.05,
              ),
              _buildCandlePillar(
                label: 'Udhar Liya',
                subLabel: 'قرض لیا',
                valueMinor: loanTaken,
                currency: currency,
                color: Colors.orangeAccent,
                ratio: maxVal > 0 ? (loanTaken / maxVal).clamp(0.05, 1.0) : 0.05,
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          // fl_chart Interactive Bar Chart
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: chartMaxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final titles = ['Cash In', 'Cash Out', 'Udhar Diya', 'Udhar Liya'];
                      return BarTooltipItem(
                        '${titles[group.x]}\n${CurrencyFormatter.format(rod.toY.toInt(), currency)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final titles = ['In', 'Out', 'Diya', 'Liya'];
                        final idx = val.toInt();
                        if (idx >= 0 && idx < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              titles[idx],
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: totalIn.toDouble(),
                        color: AppColors.moneyIn,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: totalOut.toDouble(),
                        color: AppColors.moneyOut,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: loanGiven.toDouble(),
                        color: Colors.blueAccent,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(
                        toY: loanTaken.toDouble(),
                        color: Colors.orangeAccent,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandlePillar({
    required String label,
    required String subLabel,
    required int valueMinor,
    required CurrencyConfig currency,
    required Color color,
    required double ratio,
  }) {
    const double maxHeight = 130.0;
    final double pillarHeight = maxHeight * ratio;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Formatted Amount on Top of Candle
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              CurrencyFormatter.format(valueMinor, currency),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Candle Wick / Pin
        Container(
          width: 3,
          height: 8,
          decoration: BoxDecoration(
            color: color.withAlpha(180),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Candle Body
        Container(
          width: 38,
          height: pillarHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color,
                color.withAlpha(190),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(50),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Labels
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        Text(
          subLabel,
          style: const TextStyle(fontSize: 9.5, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBooksBreakdownSection({
    required List<_BookReportStat> bookStats,
    required CurrencyConfig currency,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Books Breakdown',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                '${bookStats.length} Book(s) in ${currency.code}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bookStats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('No books found for this currency.')),
            )
          else
            ...bookStats.map((bs) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bs.book.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Net: ${CurrencyFormatter.format(bs.netFlow, currency)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: bs.netFlow >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'In: ${CurrencyFormatter.format(bs.totalIn, currency)}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.moneyIn, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Out: ${CurrencyFormatter.format(bs.totalOut, currency)}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.moneyOut, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Udhar Diya: ${CurrencyFormatter.format(bs.loanGiven, currency)}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Udhar Liya: ${CurrencyFormatter.format(bs.loanTaken, currency)}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.orangeAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildExpenseDonutChart({
    required Map<String, int> expenseCategoryTotals,
    required int totalOut,
    required List<dynamic> allCats,
    required CurrencyConfig currency,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 45,
                sections: expenseCategoryTotals.entries.map((e) {
                  final cat = allCats.where((c) => c.id == e.key);
                  final color = cat.isNotEmpty ? Color(cat.first.color) : Colors.grey;
                  final pct = DecimalCalculator.calculatePercentage(e.value, totalOut);

                  return PieChartSectionData(
                    value: e.value.toDouble(),
                    title: '${pct.toStringAsFixed(0)}%',
                    color: color,
                    radius: 35,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          ...expenseCategoryTotals.entries.map((e) {
            final cat = allCats.where((c) => c.id == e.key);
            final name = cat.isNotEmpty ? cat.first.name : 'Uncategorized';
            final color = cat.isNotEmpty ? Color(cat.first.color) : Colors.grey;
            final pct = DecimalCalculator.calculatePercentage(e.value, totalOut);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    CurrencyFormatter.format(e.value, currency),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _dateRange == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) setState(() => _dateRange = value);
      },
    );
  }
}

class _BookReportStat {
  final BookModel book;
  final int totalIn;
  final int totalOut;
  final int netFlow;
  final int loanGiven;
  final int loanTaken;

  _BookReportStat({
    required this.book,
    required this.totalIn,
    required this.totalOut,
    required this.netFlow,
    required this.loanGiven,
    required this.loanTaken,
  });
}
