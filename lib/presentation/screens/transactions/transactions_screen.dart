import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/date_formatter.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/data/repositories/transaction_repository.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'transaction_details_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _selectedDateFilter = 'ALL'; // ALL, TODAY, YESTERDAY, THIS_WEEK, THIS_MONTH
  String _selectedTypeFilter = 'ALL'; // ALL, IN, OUT

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyCurrentFilter();
    });
  }

  void _applyCurrentFilter() {
    final book = context.read<BookController>().activeBook;
    if (book == null) return;

    String? startDate;
    String? endDate;
    final now = DateTime.now();

    if (_selectedDateFilter == 'TODAY') {
      startDate = DateFormatter.toIsoDate(now);
      endDate = startDate;
    } else if (_selectedDateFilter == 'YESTERDAY') {
      startDate = DateFormatter.toIsoDate(now.subtract(const Duration(days: 1)));
      endDate = startDate;
    } else if (_selectedDateFilter == 'THIS_WEEK') {
      startDate = DateFormatter.toIsoDate(DateFormatter.startOfWeek(now));
      endDate = DateFormatter.toIsoDate(now);
    } else if (_selectedDateFilter == 'THIS_MONTH') {
      startDate = DateFormatter.toIsoDate(DateFormatter.startOfMonth(now));
      endDate = DateFormatter.toIsoDate(DateFormatter.endOfMonth(now));
    }

    final filter = TransactionFilter(
      startDate: startDate,
      endDate: endDate,
      typeFilter: _selectedTypeFilter == 'ALL' ? null : _selectedTypeFilter,
      searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );

    context.read<TransactionController>().applyFilter(filter, book);
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final txController = context.watch<TransactionController>();
    final catController = context.watch<CategoryController>();
    final partyController = context.watch<PartyController>();

    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCats = [...catController.incomeCategories, ...catController.expenseCategories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.moneyIn),
            tooltip: 'Money In',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(initialType: TransactionType.income),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.moneyOut),
            tooltip: 'Money Out',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(initialType: TransactionType.expense),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search description, reference, amount...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applyCurrentFilter();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Filters Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Type Filter Chips
                _buildFilterChip('All Types', _selectedTypeFilter == 'ALL', () {
                  setState(() => _selectedTypeFilter = 'ALL');
                  _applyCurrentFilter();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Money In (+)', _selectedTypeFilter == 'IN', () {
                  setState(() => _selectedTypeFilter = 'IN');
                  _applyCurrentFilter();
                }, activeColor: AppColors.moneyIn),
                const SizedBox(width: 6),
                _buildFilterChip('Money Out (-)', _selectedTypeFilter == 'OUT', () {
                  setState(() => _selectedTypeFilter = 'OUT');
                  _applyCurrentFilter();
                }, activeColor: AppColors.moneyOut),
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: Colors.grey.withAlpha(50)),
                const SizedBox(width: 12),

                // Date Filter Chips
                _buildFilterChip('All Time', _selectedDateFilter == 'ALL', () {
                  setState(() => _selectedDateFilter = 'ALL');
                  _applyCurrentFilter();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Today', _selectedDateFilter == 'TODAY', () {
                  setState(() => _selectedDateFilter = 'TODAY');
                  _applyCurrentFilter();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Yesterday', _selectedDateFilter == 'YESTERDAY', () {
                  setState(() => _selectedDateFilter = 'YESTERDAY');
                  _applyCurrentFilter();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('This Week', _selectedDateFilter == 'THIS_WEEK', () {
                  setState(() => _selectedDateFilter = 'THIS_WEEK');
                  _applyCurrentFilter();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('This Month', _selectedDateFilter == 'THIS_MONTH', () {
                  setState(() => _selectedDateFilter = 'THIS_MONTH');
                  _applyCurrentFilter();
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Transaction List
          Expanded(
            child: txController.isLoading
                ? const Center(child: CircularProgressIndicator())
                : txController.transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 56,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions found.',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: txController.transactions.length,
                        itemBuilder: (context, index) {
                          final tx = txController.transactions[index];

                          // Resolve category name
                          String? catName;
                          if (tx.categoryId != null) {
                            final found = allCats.where((c) => c.id == tx.categoryId);
                            if (found.isNotEmpty) catName = found.first.name;
                          }

                          // Resolve party name
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
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onSelected, {Color? activeColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = activeColor ?? AppColors.primary;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }
}
