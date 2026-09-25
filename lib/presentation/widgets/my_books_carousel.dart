import 'package:flutter/material.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/domain/services/dashboard_summary_service.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';
import 'package:hissab/presentation/widgets/responsive_money_text.dart';

/// Horizontal carousel or responsive grid displaying all user books on the Dashboard.
class MyBooksCarousel extends StatelessWidget {
  final List<BookFinancialSummary> summaries;
  final String? activeBookId;
  final Function(String bookId) onSelectBook;
  final VoidCallback onAddBook;

  const MyBooksCarousel({
    super.key,
    required this.summaries,
    required this.activeBookId,
    required this.onSelectBook,
    required this.onAddBook,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_stories_rounded, size: 18, color: AppColors.primaryLight),
                SizedBox(width: 8),
                Text(
                  'My Books',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: summaries.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == summaries.length) {
                return _buildAddBookCard(context, isDark);
              }
              final summary = summaries[index];
              final isActive = summary.book.id == activeBookId;
              return _buildBookCard(context, summary, isActive, isDark);
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
  ) {
    final book = summary.book;
    final bookColor = Color(book.color);
    final currency = Currencies.findByCode(book.currency);

    return InkWell(
      onTap: () => onSelectBook(book.id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 190,
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
            // Top Row: Avatar + Book Name + Active Indicator
            Row(
              children: [
                BookAvatarWidget(
                  bookName: book.name,
                  bookColor: book.color,
                  logo: book.logo,
                  size: 32,
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
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: bookColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: bookColor,
                      ),
                    ),
                  ),
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
}
