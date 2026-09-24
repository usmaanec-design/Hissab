import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/presentation/controllers/app_controller.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/account_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/screens/home/main_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _nameController = TextEditingController(text: 'Main Business');
  final TextEditingController _openingBalController = TextEditingController(text: '0');
  CurrencyConfig _selectedCurrency = Currencies.sar;
  String _selectedUsage = 'Business';

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _openingBalController.dispose();
    super.dispose();
  }

  void _finishOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final minorUnits =
        DecimalCalculator.parseToMinorUnits(_openingBalController.text, _selectedCurrency) ?? 0;

    final bookController = context.read<BookController>();
    final appController = context.read<AppController>();
    final txController = context.read<TransactionController>();
    final partyController = context.read<PartyController>();
    final accController = context.read<AccountController>();
    final catController = context.read<CategoryController>();
    final navigator = Navigator.of(context);

    final newBook = await bookController.createBook(
      name: name,
      currency: _selectedCurrency.code,
      openingBalanceMinor: minorUnits,
      openingBalanceDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    await appController.setActiveBookId(newBook.id);
    await txController.loadForBook(newBook);
    await partyController.loadForBook(newBook.id);
    await accController.loadForBook(newBook.id);
    await catController.loadForBook(newBook.id);

    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Page 1: Welcome
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.account_balance_wallet, size: 40, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Hissab CashBook',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Professional, offline-first digital cashbook and ledger with deterministic financial precision.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page 2: Create First Book
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'Create Your First Book',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A Book keeps its own independent accounts and balance.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Book Name',
                            hintText: 'e.g. Main Business, Personal',
                            prefixIcon: Icon(Icons.book_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<CurrencyConfig>(
                          value: _selectedCurrency,
                          decoration: const InputDecoration(
                            labelText: 'Base Currency',
                            prefixIcon: Icon(Icons.monetization_on_outlined),
                          ),
                          items: Currencies.all
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text('${c.code} - ${c.name} (${c.symbol})'),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCurrency = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _openingBalController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Opening Balance (${_selectedCurrency.code})',
                            hintText: '0.00',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page 3: Usage Type
                  Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'How will you use Hissab?',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This tailors your categories and initial defaults.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildUsageOption('Small Business / Trading', 'Sales, Expenses, Supplier & Customer Khatas', Icons.storefront),
                        const SizedBox(height: 12),
                        _buildUsageOption('Personal Expense Tracker', 'Daily spending, food, fuel, bills, and savings', Icons.person),
                        const SizedBox(height: 12),
                        _buildUsageOption('Shop / Retail Ledger', 'Cash counter register and customer credit book', Icons.point_of_sale),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      3,
                      (idx) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == idx ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == idx ? AppColors.primary : Colors.grey.withAlpha(50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      if (_currentPage < 2) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finishOnboarding();
                      }
                    },
                    child: Text(_currentPage == 2 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageOption(String title, String subtitle, IconData icon) {
    final isSelected = _selectedUsage == title;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedUsage = title),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryLight : Colors.grey, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primaryLight, size: 20),
          ],
        ),
      ),
    );
  }
}
