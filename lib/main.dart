import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'presentation/controllers/account_controller.dart';
import 'presentation/controllers/app_controller.dart';
import 'presentation/controllers/book_controller.dart';
import 'presentation/controllers/category_controller.dart';
import 'presentation/controllers/party_controller.dart';
import 'presentation/controllers/transaction_controller.dart';
import 'presentation/screens/home/main_scaffold.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/security/pin_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop FFI initialization for SQLite
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const HissabApp());
}

class HissabApp extends StatelessWidget {
  const HissabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppController()),
        ChangeNotifierProvider(create: (_) => BookController()),
        ChangeNotifierProvider(create: (_) => TransactionController()),
        ChangeNotifierProvider(create: (_) => PartyController()),
        ChangeNotifierProvider(create: (_) => CategoryController()),
        ChangeNotifierProvider(create: (_) => AccountController()),
      ],
      child: const _HissabAppView(),
    );
  }
}

class _HissabAppView extends StatefulWidget {
  const _HissabAppView();

  @override
  State<_HissabAppView> createState() => _HissabAppViewState();
}

class _HissabAppViewState extends State<_HissabAppView> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _bootstrapApp();
  }

  Future<void> _bootstrapApp() async {
    final appController = context.read<AppController>();
    final bookController = context.read<BookController>();

    final txController = context.read<TransactionController>();
    final partyController = context.read<PartyController>();
    final catController = context.read<CategoryController>();
    final accController = context.read<AccountController>();

    await appController.initialize();
    await bookController.loadBooks(preferredActiveBookId: appController.activeBookId);

    final activeBook = bookController.activeBook;
    if (activeBook != null) {
      await txController.loadForBook(activeBook);
      await partyController.loadForBook(activeBook.id);
      await catController.loadForBook(activeBook.id);
      await accController.loadForBook(activeBook.id);
    }

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appController = context.watch<AppController>();
    final bookController = context.watch<BookController>();

    return MaterialApp(
      title: 'Hissab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appController.themeMode,
      locale: appController.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
      ],
      home: !_isInitialized
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : (appController.isPinProtected && !appController.isUnlocked)
              ? PinLockScreen(
                  onUnlocked: () {
                    // AppController handles state and notifies listeners
                  },
                )
              : (bookController.books.isEmpty)
                  ? const OnboardingScreen()
                  : const MainScaffold(),
    );
  }
}
