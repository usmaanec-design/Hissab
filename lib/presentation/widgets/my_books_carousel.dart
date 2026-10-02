import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/domain/services/dashboard_summary_service.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';
import 'package:hissab/presentation/widgets/responsive_money_text.dart';

/// Horizontal carousel displaying all user books on the Dashboard with persistent drag-and-drop reordering.
class MyBooksCarousel extends StatelessWidget {
  final List<BookFinancialSummary> summaries;
  final String? activeBookId;
  final Function(String bookId) onSelectBook;
  final VoidCallback onAddBook;
  final Function(int oldIndex, int newIndex)? onReorder;
  final Function(int index, int offset)? onMoveByOffset;

  const MyBooksCarousel({
    super.key,
    required this.summaries,
    required this.activeBookId,
    required this.onSelectBook,
    required this.onAddBook,
    this.onReorder,
    this.onMoveByOffset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canReorder = (onReorder != null || onMoveByOffset != null) && summaries.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_rounded, size: 18, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                const Text(
                  'My Books',
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
            TextButton.icon(
              onPressed: onAddBook,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('New Book', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 152,
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
                            borderRadius: BorderRadius.circular(16),
                            child: child,
                          ),
                        );
                      },
                      child: child,
                    );
                  },
                  footer: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildAddBookCard(context, isDark),
                  ),
                  itemBuilder: (context, index) {
                    final summary = summaries[index];
                    final isActive = summary.book.id == activeBookId;
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('my_book_${summary.book.id}'),
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Semantics(
                          label: 'Book ${summary.book.name}. Tap arrows to reorder.',
                          child: _buildBookCard(context, summary, isActive, isDark, index, summaries.length),
                        ),
                      ),
                    );
                  },
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: summaries.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == summaries.length) {
                      return _buildAddBookCard(context, isDark);
                    }
                    final summary = summaries[index];
                    final isActive = summary.book.id == activeBookId;
                    return _buildBookCard(context, summary, isActive, isDark, index, summaries.length);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    BookFinancialSummary summary,
    bool isActive,
    bool isDark,
    int index,
    int totalCount,
  ) {
    final book = summary.book;
    final bookColor = Color(book.color);
    final currency = Currencies.findByCode(book.currency);

    return InkWell(
      onTap: () => onSelectBook(book.id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? bookColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? bookColor.withAlpha(50)
                  : Colors.black.withAlpha(isDark ? 25 : 8),
              blurRadius: isActive ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Avatar + Book Name + Active Indicator + Reorder Arrows
            Row(
              children: [
                BookAvatarWidget(
                  bookName: book.name,
                  bookColor: book.color,
                  logo: book.logo,
                  size: 30,
                  borderRadius: 8,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currency.code,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: bookColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: bookColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (totalCount > 1 && onMoveByOffset != null) ...[
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

            // Middle: Income & Expense (Overflow-proof)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Income', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      const SizedBox(height: 2),
                      ResponsiveMoneyText(
                        minorUnits: summary.totalIncomeMinor,
                        currency: currency,
                        smart: true,
                        color: AppColors.moneyIn,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Expense', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      const SizedBox(height: 2),
                      ResponsiveMoneyText(
                        minorUnits: summary.totalExpenseMinor,
                        currency: currency,
                        smart: true,
                        color: AppColors.moneyOut,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        alignment: Alignment.centerRight,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom: Net Balance (Overflow-proof)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ResponsiveMoneyText(
                      minorUnits: summary.currentBalanceMinor,
                      currency: currency,
                      smart: true,
                      color: summary.currentBalanceMinor >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBookCard(BuildContext context, bool isDark) {
    return InkWell(
      onTap: onAddBook,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 32, color: AppColors.primaryLight),
            SizedBox(height: 8),
            Text(
              'Add Book',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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

