import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hissab/core/services/book_appearance_service.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/domain/services/dashboard_summary_service.dart';
import 'package:hissab/presentation/controllers/account_controller.dart';
import 'package:hissab/presentation/controllers/app_controller.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/screens/accounts/accounts_screen.dart';
import 'package:hissab/presentation/screens/books/books_screen.dart';
import 'package:hissab/presentation/screens/categories/categories_screen.dart';
import 'package:hissab/presentation/screens/parties/parties_screen.dart';
import 'package:hissab/presentation/screens/transactions/add_transaction_screen.dart';
import 'package:hissab/presentation/screens/transactions/transactions_screen.dart';
import 'package:hissab/presentation/widgets/balance_card.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';
import 'package:hissab/presentation/widgets/all_books_horizontal_bars.dart';
import 'package:hissab/presentation/widgets/my_books_carousel.dart';
import 'package:hissab/presentation/widgets/quick_action_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardSummaryService _summaryService = DashboardSummaryService();
  GlobalDashboardData _globalData = GlobalDashboardData.empty;

  @override
  void initState() {
    super.initState();
    _refreshGlobalSummary();
  }

  Future<void> _refreshGlobalSummary() async {
    if (!mounted) return;
    try {
      final data = await _summaryService.getGlobalDashboardData();
      if (mounted) {
        setState(() {
          _globalData = data;
        });
      }
    } catch (_) {}
  }

  void _openAddTransaction(BuildContext context, TransactionType type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: type),
      ),
    );
    _refreshGlobalSummary();
  }

  Future<void> _switchActiveBook(BuildContext context, String bookId) async {
    final bookController = context.read<BookController>();
    final appController = context.read<AppController>();
    final txController = context.read<TransactionController>();
    final partyController = context.read<PartyController>();
    final catController = context.read<CategoryController>();
    final accController = context.read<AccountController>();

    await bookController.selectBook(bookId);
    await appController.setActiveBookId(bookId);

    final active = bookController.activeBook;
    if (active != null) {
      await txController.loadForBook(active);
      await partyController.loadForBook(active.id);
      await catController.loadForBook(active.id);
      await accController.loadForBook(active.id);
    }
    _refreshGlobalSummary();
  }

  void _showBookSwitcherSheet(BuildContext context) {
    final bookController = context.read<BookController>();
    final books = bookController.books;
    final activeId = bookController.activeBook?.id;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Book',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Book'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BooksScreen()),
                      ).then((_) => _refreshGlobalSummary());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: books.length,
                  itemBuilder: (_, i) {
                    final b = books[i];
                    final isSelected = b.id == activeId;
                    return ListTile(
                      leading: BookAvatarWidget(
                        bookName: b.name,
                        bookColor: b.color,
                        logo: b.logo,
                        size: 36,
                        borderRadius: 10,
                      ),
                      title: Text(
                        b.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Color(b.color) : null,
                        ),
                      ),
                      subtitle: Text(b.currency),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Color(b.color))
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchActiveBook(context, b.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final txController = context.watch<TransactionController>();

    final book = bookController.activeBook;
    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _showBookSwitcherSheet(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BookAvatarWidget(
                  bookName: book?.name ?? 'Hissab',
                  bookColor: book?.color ?? BookAppearanceService.defaultColor,
                  logo: book?.logo,
                  size: 28,
                  borderRadius: 8,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          book?.name ?? 'Select Book',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                    Text(
                      'Hissab CashBook • ${currency.code}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Internal Transfer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              ).then((_) => _refreshGlobalSummary());
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Manage Books',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BooksScreen()),
              ).then((_) => _refreshGlobalSummary());
            },
          ),
        ],
      ),
      body: txController.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (book != null) {
                  await txController.loadForBook(book);
                }
                await _refreshGlobalSummary();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Top Dashboard Banner
                    BalanceCard(
                      book: book,
                      summary: txController.summary,
                      currency: currency,
                      onSwitchBook: () => _showBookSwitcherSheet(context),
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
                          icon: Icons.receipt_long_outlined,
                          label: 'Entries',
                          color: const Color(0xFF059669),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Dedicated "My Books" Section
                    MyBooksCarousel(
                      summaries: _globalData.bookSummaries,
                      activeBookId: book?.id,
                      onSelectBook: (id) => _switchActiveBook(context, id),
                      onAddBook: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BooksScreen()),
                        ).then((_) => _refreshGlobalSummary());
                      },
                    ),

                    const SizedBox(height: 24),

                    // Global Multi-Book Summary Horizontal Bars (Replaces Donut Chart)
                    // Represents ALL books and remains global even when switching books
                    AllBooksHorizontalBars(
                      globalData: _globalData,
                      displayCurrency: currency,
                      onBookTap: (id) => _switchActiveBook(context, id),
                    ),

                    const SizedBox(height: 80), // Padding for QuickActionBar
                  ],
                ),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
