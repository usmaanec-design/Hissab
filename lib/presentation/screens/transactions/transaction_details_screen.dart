import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/core/utils/date_formatter.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/models/party_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/screens/receipt/receipt_screen.dart';
import 'add_transaction_screen.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailsScreen({super.key, required this.transaction});

  void _confirmDelete(BuildContext context, BookModel book) {
    final currency = Currencies.findByCode(book.currency);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete this transaction for ${CurrencyFormatter.format(transaction.amountMinorUnit, currency)}?\n\nIt will be moved to deleted items and your balance will be recalculated immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moneyOut,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<TransactionController>().deleteTransaction(transaction.id, book);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction deleted. Balance updated.'),
                    backgroundColor: AppColors.moneyOut,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final catController = context.watch<CategoryController>();
    final partyController = context.watch<PartyController>();

    final book = bookController.activeBook;
    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isIncome = transaction.type.isMoneyIn;
    final themeColor = isIncome ? AppColors.moneyIn : AppColors.moneyOut;

    // Resolve category name
    String? categoryName;
    if (transaction.categoryId != null) {
      final allCats = [...catController.incomeCategories, ...catController.expenseCategories];
      final found = allCats.where((c) => c.id == transaction.categoryId);
      if (found.isNotEmpty) categoryName = found.first.name;
    }

    // Resolve party name
    PartyModel? party;
    if (transaction.partyId != null) {
      final found = partyController.parties.where((p) => p.id == transaction.partyId);
      if (found.isNotEmpty) party = found.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Generate Receipt',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptScreen(
                    transaction: transaction,
                    partyName: party?.name ?? 'General Customer',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(
                    initialType: transaction.type,
                    editTransaction: transaction,
                  ),
                ),
              );
            },
          ),
          if (book != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.moneyOut),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, book),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Amount Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isIncome ? 'MONEY IN' : 'MONEY OUT',
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CurrencyFormatter.format(
                      transaction.amountMinorUnit,
                      currency,
                      showExplicitPlus: isIncome,
                    ),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: themeColor,
                    ),
                  ),
                  if (transaction.description != null && transaction.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      transaction.description!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Details List
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    context,
                    Icons.calendar_today_outlined,
                    'Date & Time',
                    '${DateFormatter.formatSmartDate(transaction.date)} at ${DateFormatter.formatDisplayTime(transaction.time)}',
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context,
                    Icons.category_outlined,
                    'Category',
                    categoryName ?? 'General',
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context,
                    Icons.person_outline,
                    'Party / Contact',
                    party != null ? '${party.name} (${party.type})' : 'None',
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context,
                    Icons.payment_outlined,
                    'Payment Method',
                    transaction.paymentMethod ?? 'Cash',
                  ),
                  if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) ...[
                    const Divider(),
                    _buildDetailRow(
                      context,
                      Icons.tag,
                      'Reference #',
                      transaction.referenceNumber!,
                    ),
                  ],
                  const Divider(),
                  _buildDetailRow(
                    context,
                    Icons.fingerprint,
                    'Transaction ID',
                    transaction.id,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Share / Print Receipt Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Generate / Share Receipt'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceiptScreen(
                      transaction: transaction,
                      partyName: party?.name ?? 'General Contact',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
