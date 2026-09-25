import 'package:flutter/material.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/domain/accounting/accounting_engine.dart';

import 'package:hissab/core/services/book_appearance_service.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';
import 'package:hissab/presentation/widgets/responsive_money_text.dart';

class BalanceCard extends StatelessWidget {
  final BookModel? book;
  final BookSummary summary;
  final CurrencyConfig currency;
  final VoidCallback onSwitchBook;

  const BalanceCard({
    super.key,
    required this.book,
    required this.summary,
    required this.currency,
    required this.onSwitchBook,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = summary.currentBalanceMinor < 0;
    final bookColor = Color(book?.color ?? BookAppearanceService.defaultColor);
    final bannerGradient = BookAppearanceService.getBannerGradient(bookColor);
    final textColor = BookAppearanceService.getContrastTextColor(bookColor);
    final subtextColor = BookAppearanceService.getContrastSubtextColor(bookColor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: bannerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bookColor.withAlpha(80),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book Switcher Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onSwitchBook,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BookAvatarWidget(
                        bookName: book?.name ?? 'Book',
                        bookColor: book?.color ?? BookAppearanceService.defaultColor,
                        logo: book?.logo,
                        size: 22,
                        borderRadius: 6,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        book?.name ?? 'Select Book',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 18),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currency.code,
                  style: TextStyle(
                    color: textColor.withAlpha(200),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Total Balance Label & Big Amount
          Text(
            'Current Balance',
            style: TextStyle(
              color: subtextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(summary.currentBalanceMinor, currency),
              style: TextStyle(
                color: isNegative ? const Color(0xFFFECDD3) : textColor,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Sub Stats Row (Money In, Money Out, Net Flow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(40),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Money In
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.moneyIn,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_downward, color: Colors.white, size: 10),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Money In',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ResponsiveMoneyText(
                        minorUnits: summary.totalMoneyInMinor,
                        currency: currency,
                        smart: true,
                        color: const Color(0xFFA7F3D0),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ),
                ),

                Container(width: 1, height: 32, color: Colors.white24),
                const SizedBox(width: 12),

                // Money Out
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.moneyOut,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward, color: Colors.white, size: 10),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Money Out',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ResponsiveMoneyText(
                        minorUnits: summary.totalMoneyOutMinor,
                        currency: currency,
                        smart: true,
                        color: const Color(0xFFFECDD3),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ),
                ),

                Container(width: 1, height: 32, color: Colors.white24),
                const SizedBox(width: 12),

                // Net Cash Flow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Net Flow',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      ResponsiveMoneyText(
                        minorUnits: summary.netCashFlowMinor,
                        currency: currency,
                        smart: true,
                        color: summary.netCashFlowMinor >= 0
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFECDD3),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
