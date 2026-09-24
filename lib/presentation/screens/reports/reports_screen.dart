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
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/data/repositories/backup_repository.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _dateRange = 'THIS_MONTH'; // THIS_MONTH, THIS_WEEK, TODAY, THIS_YEAR, ALL
  final BackupRepository _backupRepository = BackupRepository();

  List<TransactionModel> _filterTransactions(List<TransactionModel> all) {
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
      return all;
    }

    final startStr = DateFormatter.toIsoDate(start);
    final endStr = DateFormatter.toIsoDate(end);

    return all.where((tx) => !tx.isDeleted && tx.date.compareTo(startStr) >= 0 && tx.date.compareTo(endStr) <= 0).toList();
  }

  void _exportPdf(BuildContext context, BookModel book, List<TransactionModel> filteredTxs, CurrencyConfig currency) async {
    final pdfBytes = await _backupRepository.generatePdfReport(
      book: book,
      transactions: filteredTxs,
      currency: currency,
      dateRangeLabel: _dateRange.replaceAll('_', ' '),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Hissab_Report_${book.name}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
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
        subject: 'Hissab Cashbook CSV Export - ${book.name}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final txController = context.watch<TransactionController>();
    final catController = context.watch<CategoryController>();

    final book = bookController.activeBook;
    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (book == null) {
      return const Scaffold(body: Center(child: Text('No active book selected.')));
    }

    final filteredTxs = _filterTransactions(txController.transactions);

    // Calculate Totals
    int totalIn = 0;
    int totalOut = 0;
    final Map<String, int> expenseCategoryTotals = {};
    final Map<String, int> incomeCategoryTotals = {};

    for (final tx in filteredTxs) {
      if (tx.type.isMoneyIn) {
        totalIn += tx.amountMinorUnit;
        final catId = tx.categoryId ?? 'Uncategorized';
        incomeCategoryTotals[catId] = (incomeCategoryTotals[catId] ?? 0) + tx.amountMinorUnit;
      } else if (tx.type.isMoneyOut) {
        totalOut += tx.amountMinorUnit;
        final catId = tx.categoryId ?? 'Uncategorized';
        expenseCategoryTotals[catId] = (expenseCategoryTotals[catId] ?? 0) + tx.amountMinorUnit;
      }
    }

    final netCashFlow = totalIn - totalOut;
    final allCats = [...catController.incomeCategories, ...catController.expenseCategories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(context, book, filteredTxs, currency),
          ),
          IconButton(
            icon: const Icon(Icons.table_view_outlined),
            tooltip: 'Export CSV / Excel',
            onPressed: () => _exportCsv(context, book, filteredTxs, currency),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter Range Selector
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

            // Summary Card (Income, Expense, Net)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryColumn('Total Income', CurrencyFormatter.format(totalIn, currency), AppColors.moneyIn),
                      Container(width: 1, height: 40, color: Colors.grey.withAlpha(50)),
                      _buildSummaryColumn('Total Expense', CurrencyFormatter.format(totalOut, currency), AppColors.moneyOut),
                      Container(width: 1, height: 40, color: Colors.grey.withAlpha(50)),
                      _buildSummaryColumn(
                        'Net Cash Flow',
                        CurrencyFormatter.format(netCashFlow, currency),
                        netCashFlow >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Expense Breakdown Chart Section
            const Text(
              'Expense Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (expenseCategoryTotals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Center(
                  child: Text(
                    'No expenses recorded for this period.',
                    style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    // Donut Chart
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

                    // Category Breakdown List
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
              ),
            ],

            const SizedBox(height: 24),

            // Export Actions Section
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    onPressed: () => _exportPdf(context, book, filteredTxs, currency),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text('Share CSV'),
                    onPressed: () => _exportCsv(context, book, filteredTxs, currency),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildSummaryColumn(String title, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
