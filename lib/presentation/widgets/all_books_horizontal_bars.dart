import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/constants/currencies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money_display_formatter.dart';
import '../../domain/services/dashboard_summary_service.dart';
import 'book_avatar_widget.dart';
import 'responsive_money_text.dart';

/// Modern, responsive horizontal card and bar visualization for All Books Overview & Activity.
///
/// Features:
/// - Horizontally scrollable collection of overview & activity cards matching My Books.
/// - Drag-and-drop reordering following canonical Book.displayOrder.
/// - Global across all books; never filtered by active book.
/// - Proportional Income (green) and Expense (red) visual bars per book.
/// - Overflow-safe across all screen widths and extreme numbers (billions/trillions).
/// - Tap to view exact mathematical totals in modal sheet.
class AllBooksHorizontalBars extends StatelessWidget {
  final GlobalDashboardData globalData;
  final CurrencyConfig displayCurrency;
  final Function(String bookId)? onBookTap;
  final Function(int oldIndex, int newIndex)? onReorder;
  final Function(int index, int offset)? onMoveByOffset;

  const AllBooksHorizontalBars({
    super.key,
    required this.globalData,
    required this.displayCurrency,
    this.onBookTap,
    this.onReorder,
    this.onMoveByOffset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaries = globalData.bookSummaries;
    final canReorder = (onReorder != null || onMoveByOffset != null) && summaries.length > 1;

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
            'No books found. Create a book to view overview.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Determine the maximum activity across all books to scale horizontal bars proportionally
    int maxActivity = 1;
    for (final s in summaries) {
      final act = math.max(s.totalIncomeMinor, s.totalExpenseMinor);
      if (act > maxActivity) {
        maxActivity = act;
      }
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
          // 1. Header with book count badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 22, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  const Text(
                    'All Books Overview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (canReorder) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 12, color: AppColors.primaryLight),
                          SizedBox(width: 2),
                          Text(
                            'Arrows to Adjust',
                            style: TextStyle(fontSize: 9.5, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
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

          const SizedBox(height: 16),

          // 2. Global Totals Card (Overflow-safe 3-column layout)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildGlobalMetricColumn(
                    context,
                    label: 'TOTAL INCOME',
                    minorUnits: globalData.globalIncomeMinor,
                    currency: displayCurrency,
                    color: AppColors.moneyIn,
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: Colors.grey.withAlpha(50),
                ),
                Expanded(
                  child: _buildGlobalMetricColumn(
                    context,
                    label: 'TOTAL EXPENSE',
                    minorUnits: globalData.globalExpenseMinor,
                    currency: displayCurrency,
                    color: AppColors.moneyOut,
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: Colors.grey.withAlpha(50),
                ),
                Expanded(
                  child: _buildGlobalMetricColumn(
                    context,
                    label: 'TOTAL NET',
                    minorUnits: globalData.globalBalanceMinor,
                    currency: displayCurrency,
                    color: globalData.globalBalanceMinor >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Book Activity & Comparison',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Text(
                'Swipe & Tap',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 4. Horizontally Scrollable & Reorderable Cards (Part 2 & Part 3)
          SizedBox(
            height: 148,
            child: canReorder && onReorder != null
                ? ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: summaries.length,
                    onReorder: (oldIndex, newIndex) {
                      onReorder!(oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final animValue = Curves.easeInOut.transform(animation.value);
                          final elevation = ui.lerpDouble(0, 10, animValue)!;
                          final scale = ui.lerpDouble(1, 1.04, animValue)!;
                          return Transform.scale(
                            scale: scale,
                            child: Material(
                              elevation: elevation,
                              color: Colors.transparent,
                              shadowColor: Colors.black45,
                              borderRadius: BorderRadius.circular(14),
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final s = summaries[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey('all_book_activity_${s.book.id}'),
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 270,
                            child: _buildBookBarCard(context, s, maxActivity, index, summaries.length),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: summaries.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final s = summaries[index];
                      return SizedBox(
                        width: 270,
                        child: _buildBookBarCard(context, s, maxActivity, index, summaries.length),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalMetricColumn(
    BuildContext context, {
    required String label,
    required int minorUnits,
    required CurrencyConfig currency,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        ResponsiveMoneyText(
          minorUnits: minorUnits,
          currency: currency,
          smart: true,
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          alignment: Alignment.center,
        ),
      ],
    );
  }

  Widget _buildBookBarCard(BuildContext context, BookFinancialSummary s, int maxActivity, int index, int totalCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookCurr = Currencies.findByCode(s.book.currency);
    final bookColor = Color(s.book.color);

    final safeMax = maxActivity > 0 ? maxActivity : 1;
    final incomeFactor = s.totalIncomeMinor > 0
        ? (s.totalIncomeMinor / safeMax).clamp(0.0, 1.0)
        : 0.0;
    final expenseFactor = s.totalExpenseMinor > 0
        ? (s.totalExpenseMinor / safeMax).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: () {
        _showBookDetailsModal(context, s, bookCurr);
        onBookTap?.call(s.book.id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface.withAlpha(120) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: bookColor.withAlpha(isDark ? 70 : 40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Avatar + Name + Net Balance + Reorder Arrows
            Row(
              children: [
                BookAvatarWidget(
                  bookName: s.book.name,
                  bookColor: s.book.color,
                  logo: s.book.logo,
                  size: 26,
                  borderRadius: 6,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.book.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (s.currentBalanceMinor >= 0 ? AppColors.moneyIn : AppColors.moneyOut).withAlpha(18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Net: ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                        Flexible(
                          child: ResponsiveMoneyText(
                            minorUnits: s.currentBalanceMinor,
                            currency: bookCurr,
                            smart: true,
                            color: s.currentBalanceMinor >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (totalCount > 1 && onMoveByOffset != null) ...[
                  const SizedBox(width: 4),
                  _buildArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: index > 0 ? () => onMoveByOffset!(index, -1) : null,
                    tooltip: 'Move Left',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 2),
                  _buildArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onPressed: index < totalCount - 1 ? () => onMoveByOffset!(index, 1) : null,
                    tooltip: 'Move Right',
                    isDark: isDark,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Income Horizontal Bar
            _buildBarRow(
              context,
              label: 'In',
              factor: incomeFactor,
              barColor: AppColors.moneyIn,
              minorUnits: s.totalIncomeMinor,
              currency: bookCurr,
            ),

            const SizedBox(height: 5),

            // Expense Horizontal Bar
            _buildBarRow(
              context,
              label: 'Out',
              factor: expenseFactor,
              barColor: AppColors.moneyOut,
              minorUnits: s.totalExpenseMinor,
              currency: bookCurr,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarRow(
    BuildContext context, {
    required String label,
    required double factor,
    required Color barColor,
    required int minorUnits,
    required CurrencyConfig currency,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              if (!maxWidth.isFinite || maxWidth <= 0) {
                return const SizedBox.shrink();
              }
              final validFactor = (factor.isFinite && !factor.isNaN)
                  ? factor.clamp(0.0, 1.0)
                  : 0.0;
              final minBarWidth = maxWidth >= 4.0 ? 4.0 : maxWidth;
              final barWidth = validFactor > 0
                  ? (maxWidth * validFactor).clamp(minBarWidth, maxWidth)
                  : 0.0;

              return Stack(
                children: [
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  if (barWidth > 0)
                    Container(
                      width: barWidth,
                      height: 7,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 85,
          child: ResponsiveMoneyText(
            minorUnits: minorUnits,
            currency: currency,
            smart: true,
            color: barColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            alignment: Alignment.centerRight,
          ),
        ),
      ],
    );
  }

  void _showBookDetailsModal(BuildContext context, BookFinancialSummary s, CurrencyConfig currency) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BookAvatarWidget(
                      bookName: s.book.name,
                      bookColor: s.book.color,
                      logo: s.book.logo,
                      size: 38,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.book.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Currency: ${s.book.currency}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildExactDetailRow('Opening Balance', s.book.openingBalanceMinor, currency, Colors.grey[700]!),
                const SizedBox(height: 8),
                _buildExactDetailRow('Total Income', s.totalIncomeMinor, currency, AppColors.moneyIn),
                const SizedBox(height: 8),
                _buildExactDetailRow('Total Expense', s.totalExpenseMinor, currency, AppColors.moneyOut),
                const Divider(height: 20),
                _buildExactDetailRow(
                  'Current Net Balance',
                  s.currentBalanceMinor,
                  currency,
                  s.currentBalanceMinor >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                  isBold: true,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExactDetailRow(String label, int minorUnits, CurrencyConfig currency, Color color, {bool isBold = false}) {
    final exact = MoneyDisplayFormatter.formatExact(minorUnits, currency);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        SelectableText(
          exact,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: onPressed != null
                ? (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: onPressed != null
                  ? (isDark ? Colors.white24 : Colors.black12)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            size: 13,
            color: onPressed != null
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }
}

