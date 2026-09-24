import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/data/models/account_model.dart';
import 'package:hissab/presentation/controllers/account_controller.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  void _showTransferDialog(BuildContext context) {
    final accController = context.read<AccountController>();
    final bookController = context.read<BookController>();
    final book = bookController.activeBook;
    if (book == null || accController.accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 accounts are required for an internal transfer.')),
      );
      return;
    }

    final currency = bookController.activeCurrency;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    AccountModel fromAccount = accController.accounts.first;
    AccountModel toAccount = accController.accounts[1];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Internal Account Transfer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Move money between Cash, Bank, and Wallets without affecting net income/expenses.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<AccountModel>(
                  value: fromAccount,
                  decoration: const InputDecoration(labelText: 'From Account (Source)'),
                  items: accController.accounts
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => fromAccount = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountModel>(
                  value: toAccount,
                  decoration: const InputDecoration(labelText: 'To Account (Destination)'),
                  items: accController.accounts
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => toAccount = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Transfer Amount (${currency.code})',
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. ATM withdrawal, Bank deposit',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (fromAccount.id == toAccount.id) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Source and destination accounts must be different.')),
                  );
                  return;
                }

                final minorUnits = DecimalCalculator.parseToMinorUnits(amountController.text, currency);
                if (minorUnits == null || minorUnits <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an amount greater than 0.')),
                  );
                  return;
                }

                final now = DateTime.now();
                await context.read<TransactionController>().transfer(
                      book: book,
                      sourceAccountId: fromAccount.id,
                      destinationAccountId: toAccount.id,
                      amountMinorUnit: minorUnits,
                      date: DateFormat('yyyy-MM-dd').format(now),
                      time: DateFormat('HH:mm').format(now),
                      description: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    );

                if (!context.mounted) return;
                await context.read<AccountController>().loadForBook(book.id);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Internal transfer completed successfully!'),
                    backgroundColor: AppColors.transfer,
                  ),
                );
              },
              child: const Text('Execute Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    String selectedType = 'bank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Account / Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name', hintText: 'e.g. Al Rajhi Bank'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash in Hand')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                  DropdownMenuItem(value: 'mada', child: Text('Card / Mada')),
                  DropdownMenuItem(value: 'wallet', child: Text('Digital Wallet / STC Pay')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Opening Balance', hintText: '0.00'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final bookController = context.read<BookController>();
                final book = bookController.activeBook;
                if (book != null) {
                  final minor = DecimalCalculator.parseToMinorUnits(
                          balanceController.text, bookController.activeCurrency) ??
                      0;
                  await context.read<AccountController>().addAccount(
                        bookId: book.id,
                        name: name,
                        type: selectedType,
                        openingBalanceMinor: minor,
                      );
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final accController = context.watch<AccountController>();
    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts & Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Internal Transfer',
            onPressed: () => _showTransferDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Account',
            onPressed: () => _showAddAccountDialog(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: accController.accounts.length,
        itemBuilder: (context, index) {
          final acc = accController.accounts[index];
          final balanceMinor = accController.accountBalances[acc.id] ?? acc.openingBalanceMinor;

          IconData iconData = Icons.account_balance_wallet_outlined;
          if (acc.type == 'cash') iconData = Icons.payments_outlined;
          if (acc.type == 'bank') iconData = Icons.account_balance_outlined;
          if (acc.type == 'mada') iconData = Icons.credit_card_outlined;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: AppColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        acc.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(balanceMinor, currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: balanceMinor >= 0 ? AppColors.moneyIn : AppColors.moneyOut,
                      ),
                    ),
                    const Text('Ledger Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.transfer,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('New Internal Transfer (Cash ⇄ Bank)'),
            onPressed: () => _showTransferDialog(context),
          ),
        ),
      ),
    );
  }
}
