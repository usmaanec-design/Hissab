import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/widgets/balance_card.dart';
import 'package:hissab/presentation/widgets/transaction_tile.dart';
import 'package:hissab/presentation/widgets/quick_action_bar.dart';
import 'package:hissab/presentation/screens/books/books_screen.dart';
import 'package:hissab/presentation/screens/categories/categories_screen.dart';
import 'package:hissab/presentation/screens/parties/parties_screen.dart';
import 'package:hissab/presentation/screens/accounts/accounts_screen.dart';
import 'package:hissab/presentation/screens/transactions/add_transaction_screen.dart';
import 'package:hissab/presentation/screens/transactions/transaction_details_screen.dart';
import 'package:hissab/presentation/screens/transactions/transactions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openAddTransaction(BuildContext context, TransactionType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: type),
      ),
    );
  }

  void _openBookSwitcher(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BooksScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final txController = context.watch<TransactionController>();
    final catController = context.watch<CategoryController>();
    final partyController = context.watch<PartyController>();

    final book = bookController.activeBook;
    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCats = [...catController.incomeCategories, ...catController.expenseCategories];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryLight, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hissab CashBook', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Real-time Ledger', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Internal Transfer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'My Books',
            onPressed: () => _openBookSwitcher(context),
          ),
        ],
      ),
      body: txController.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Balance Card
                  BalanceCard(
                    book: book,
                    summary: txController.summary,
                    currency: currency,
                    onSwitchBook: () => _openBookSwitcher(context),
                  ),

                  const SizedBox(height: 16),

                  // Today's Summary Banner
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.today, size: 16, color: Colors.grey),
                            SizedBox(width: 6),
                            Text(
                              "Today's Activity",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('In: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                Text(
                                  CurrencyFormatter.format(txController.todayInMinor, currency),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.moneyIn,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('Out: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                Text(
                                  CurrencyFormatter.format(txController.todayOutMinor, currency),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.moneyOut,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Action Hub (Row of 4 icons: Parties, Categories, Accounts, Transfer)
                  Row(
                    children: [
                      _buildQuickTile(
                        context,
                        icon: Icons.people_outline,
                        label: 'Parties',
                        color: AppColors.primaryLight,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartiesScreen())),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickTile(
                        context,
                        icon: Icons.category_outlined,
                        label: 'Categories',
                        color: AppColors.accent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickTile(
                        context,
                        icon: Icons.account_balance_outlined,
                        label: 'Accounts',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickTile(
                        context,
                        icon: Icons.menu_book_outlined,
                        label: 'Books',
                        color: const Color(0xFFD97706),
                        onTap: () => _openBookSwitcher(context),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Recent Transactions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                          );
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Recent Transactions List
                  if (txController.recentTransactions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'Your transactions will appear here.',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap Money In or Money Out below to add your first record.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...txController.recentTransactions.map((tx) {
                      // Resolve Category Name
                      String? catName;
                      if (tx.categoryId != null) {
                        final found = allCats.where((c) => c.id == tx.categoryId);
                        if (found.isNotEmpty) catName = found.first.name;
                      }

                      // Resolve Party Name
                      String? pName;
                      if (tx.partyId != null) {
                        final found = partyController.parties.where((p) => p.id == tx.partyId);
                        if (found.isNotEmpty) pName = found.first.name;
                      }

                      return TransactionTile(
                        transaction: tx,
                        currency: currency,
                        categoryName: catName,
                        partyName: pName,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailsScreen(transaction: tx),
                            ),
                          );
                        },
                      );
                    }),

                  const SizedBox(height: 80), // Padding above bottom bar
                ],
              ),
            ),
      bottomSheet: QuickActionBar(
        onMoneyIn: () => _openAddTransaction(context, TransactionType.income),
        onMoneyOut: () => _openAddTransaction(context, TransactionType.expense),
      ),
    );
  }

  Widget _buildQuickTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
