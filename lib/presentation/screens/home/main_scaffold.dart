import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/localization/app_localizations.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/screens/home/home_screen.dart';
import 'package:hissab/presentation/screens/parties/parties_screen.dart';
import 'package:hissab/presentation/screens/reports/reports_screen.dart';
import 'package:hissab/presentation/screens/settings/settings_screen.dart';
import 'package:hissab/presentation/screens/transactions/transactions_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    TransactionsScreen(),
    PartiesScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Refresh active book data when switching to tabs
          final book = context.read<BookController>().activeBook;
          if (book != null) {
            if (index == 0 || index == 1) {
              context.read<TransactionController>().loadForBook(book);
            } else if (index == 2) {
              context.read<PartyController>().loadForBook(book.id);
            }
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: loc.translate('nav.home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: loc.translate('nav.transactions'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            activeIcon: const Icon(Icons.people),
            label: loc.translate('nav.parties'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.insert_chart_outlined),
            activeIcon: const Icon(Icons.insert_chart),
            label: loc.translate('nav.reports'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: loc.translate('nav.settings'),
          ),
        ],
      ),
    );
  }
}
