import 'package:flutter/material.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/core/utils/date_formatter.dart';
import 'package:hissab/data/models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final CurrencyConfig currency;
  final String? categoryName;
  final String? partyName;
  final VoidCallback onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
    this.categoryName,
    this.partyName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMoneyIn = transaction.type.isMoneyIn;
    final isTransfer = transaction.type == TransactionType.transferIn ||
        transaction.type == TransactionType.transferOut;

    Color amountColor;
    Color iconBgColor;
    IconData iconData;

    if (isTransfer) {
      amountColor = AppColors.transfer;
      iconBgColor = AppColors.transferContainer;
      iconData = Icons.swap_horiz_rounded;
    } else if (isMoneyIn) {
      amountColor = isDark ? AppColors.moneyInDark : AppColors.moneyIn;
      iconBgColor = isDark ? AppColors.moneyInContainerDark : AppColors.moneyInContainer;
      iconData = Icons.arrow_downward_rounded;
    } else {
      amountColor = isDark ? AppColors.moneyOutDark : AppColors.moneyOut;
      iconBgColor = isDark ? AppColors.moneyOutContainerDark : AppColors.moneyOutContainer;
      iconData = Icons.arrow_upward_rounded;
    }

    final title = transaction.description?.isNotEmpty == true
        ? transaction.description!
        : (categoryName ?? transaction.type.toDbString());

    final subInfo = [
      if (partyName != null && partyName!.isNotEmpty) partyName!,
      if (categoryName != null && categoryName!.isNotEmpty && transaction.description?.isNotEmpty == true)
        categoryName!,
      DateFormatter.formatDisplayTime(transaction.time),
    ].join(' • ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            // Directional Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: amountColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subInfo,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount Display with Explicit Sign
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(
                    transaction.amountMinorUnit,
                    currency,
                    showExplicitPlus: isMoneyIn && !isTransfer,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                if (transaction.paymentMethod != null && transaction.paymentMethod!.isNotEmpty)
                  Text(
                    transaction.paymentMethod!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
