import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/domain/services/dashboard_summary_service.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';

/// Global Multi-Book Donut Chart & Aggregate Financial Breakdown.
/// This widget remains global across all user books and does not filter by active book.
class MultiBookDonutChart extends StatelessWidget {
  final GlobalDashboardData globalData;
  final CurrencyConfig displayCurrency;
  final Function(String bookId)? onBookTap;

  const MultiBookDonutChart({
    super.key,
    required this.globalData,
    required this.displayCurrency,
    this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaries = globalData.bookSummaries;

    if (summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: const Center(
          child: Text(
            'No books found. Create a book to view summary.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Build chart sections based on total activity (income + expense) or balance
    int totalActivity = 0;
    for (final s in summaries) {
      totalActivity += (s.totalIncomeMinor + s.totalExpenseMinor).abs();
    }

    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < summaries.length; i++) {
      final s = summaries[i];
      final bookColor = Color(s.book.color);
      final activity = (s.totalIncomeMinor + s.totalExpenseMinor).abs();
      final double value = totalActivity > 0 ? (activity / totalActivity) * 100 : 100.0 / summaries.length;

      sections.add(
        PieChartSectionData(
          color: bookColor,
          value: value,
          title: '${value.toStringAsFixed(0)}%',
          radius: 28,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, size: 20, color: AppColors.primaryLight),
                  SizedBox(width: 8),
                  Text(
                    'All Books Overview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${summaries.length} ${summaries.length == 1 ? "Book" : "Books"}',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Donut Chart with Center Global Total
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 52,
                    sections: sections,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL NET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          CurrencyFormatter.format(globalData.globalBalanceMinor, displayCurrency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: globalData.globalBalanceMinor >= 0
                                ? AppColors.moneyIn
                                : AppColors.moneyOut,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Global Totals Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGlobalMetric(
                  'Total In',
                  CurrencyFormatter.format(globalData.globalIncomeMinor, displayCurrency),
                  AppColors.moneyIn,
                ),
                Container(width: 1, height: 28, color: Colors.grey.withAlpha(60)),
                _buildGlobalMetric(
                  'Total Out',
                  CurrencyFormatter.format(globalData.globalExpenseMinor, displayCurrency),
                  AppColors.moneyOut,
                ),
                Container(width: 1, height: 28, color: Colors.grey.withAlpha(60)),
                _buildGlobalMetric(
                  'Total Net',
                  CurrencyFormatter.format(globalData.globalBalanceMinor, displayCurrency),
                  globalData.globalBalanceMinor >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Per-Book Breakdown Cards
          const Text(
            'Book Breakdown',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          ...summaries.map((s) {
            final bookCurr = Currencies.findByCode(s.book.currency);
            final bookColor = Color(s.book.color);

            return InkWell(
              onTap: () => onBookTap?.call(s.book.id),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Row(
                  children: [
                    BookAvatarWidget(
                      bookName: s.book.name,
                      bookColor: s.book.color,
                      logo: s.book.logo,
                      size: 32,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.book.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'In: ${CurrencyFormatter.format(s.totalIncomeMinor, bookCurr)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.moneyIn),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Out: ${CurrencyFormatter.format(s.totalExpenseMinor, bookCurr)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.moneyOut),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(s.currentBalanceMinor, bookCurr),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: s.currentBalanceMinor >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: bookColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGlobalMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
