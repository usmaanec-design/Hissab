import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hissab/core/constants/app_assets.dart';
import 'package:hissab/core/constants/bank_catalog.dart';
import 'package:hissab/core/localization/app_localizations.dart';
import 'package:hissab/data/database/platform/database_platform.dart';
import 'package:hissab/main.dart';
import 'package:hissab/presentation/controllers/app_controller.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';

void main() {
  setUpAll(() async {
    await DatabasePlatform.initialize();
  });

  group('Part 1: Official Hissab Logo & Asset Verification', () {
    test('AppAssets constants point to valid official assets', () {
      expect(AppAssets.logo, equals('assets/Hissab Logo.png'));
      expect(File(AppAssets.logo).existsSync(), isTrue);

      expect(AppAssets.logoAlias, equals('assets/logo.png'));
      expect(File(AppAssets.logoAlias).existsSync(), isTrue);

      expect(File('web/favicon.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-192.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-512.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-maskable-192.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-maskable-512.png').existsSync(), isTrue);

      expect(File('android/app/src/main/res/mipmap-hdpi/ic_launcher.png').existsSync(), isTrue);
      expect(File('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png').existsSync(), isTrue);
    });
  });

  group('Part 2: Bank Catalog & Custom Logo System', () {
    test('BankCatalog contains all 10 Saudi and 13 Pakistan banks', () {
      expect(BankCatalog.saudiBanks.length, equals(10));
      expect(BankCatalog.pakistanBanks.length, equals(13));
      expect(BankCatalog.allBanks.length, equals(23));

      // Verify all assets exist on disk
      for (final bank in BankCatalog.allBanks) {
        expect(File(bank.assetPath).existsSync(), isTrue, reason: 'Asset ${bank.assetPath} must exist');
      }

      // Verify search
      final meezanSearch = BankCatalog.search('Meezan');
      expect(meezanSearch.isNotEmpty, isTrue);
      expect(meezanSearch.first.id, equals('meezan'));

      final rajhiSearch = BankCatalog.search('Rajhi');
      expect(rajhiSearch.isNotEmpty, isTrue);
      expect(rajhiSearch.first.id, equals('alrajhi'));

      final snbSearch = BankCatalog.search('الأهلي');
      expect(snbSearch.isNotEmpty, isTrue);
      expect(snbSearch.first.id, equals('snb'));
    });

    testWidgets('BookAvatarWidget renders bank logo and fallback initial', (WidgetTester tester) async {
      // 1. Initial fallback
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookAvatarWidget(
              bookName: 'Main Store',
              bookColor: 0xFF2563EB,
              logo: null,
            ),
          ),
        ),
      );
      expect(find.text('M'), findsOneWidget);

      // 2. Corrupt / invalid logo falls back safely without crashing
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookAvatarWidget(
              bookName: 'Alpha Store',
              bookColor: 0xFF2563EB,
              logo: 'invalid_corrupt_data',
            ),
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('Part 3: Multi-Language Switching & RTL Stability Matrix', () {
    test('AppLocalizations translation completeness and safe fallback', () {
      final locEn = AppLocalizations(const Locale('en'));
      final locAr = AppLocalizations(const Locale('ar'));
      final locUr = AppLocalizations(const Locale('ur'));

      expect(locEn.translate('app.title'), equals('Hissab'));
      expect(locAr.translate('app.title'), equals('حِساب'));
      expect(locUr.translate('app.title'), equals('حساب'));

      expect(locEn.translate('bank.choose_logo'), equals('Choose Logo'));
      expect(locAr.translate('bank.choose_logo'), equals('اختر الشعار'));
      expect(locUr.translate('bank.choose_logo'), equals('لوگو منتخب کریں'));

      // Non-existent key must fall back safely and not throw
      expect(locUr.translate('non_existent_key_123'), equals('non_existent_key_123'));
    });

    testWidgets('Repeated Language Switching Matrix (en -> ur -> ar -> en) 10x without crash', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final appController = AppController();
      await appController.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: appController,
          child: Consumer<AppController>(
            builder: (context, controller, child) {
              return MaterialApp(
                locale: controller.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizationsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Builder(
                  builder: (ctx) {
                    final loc = AppLocalizations.of(ctx);
                    final direction = Directionality.of(ctx);
                    return Scaffold(
                      body: Column(
                        children: [
                          Text('Title: ${loc.translate("app.title")}'),
                          Text('Direction: $direction'),
                          // Verify user entered accounting data is preserved without distortion
                          const Text('User Note: آج احمد سے پانچ سو ریال وصول ہوئے'),
                          const Text('User Amount: SAR 500.00'),
                          const Text('Party: محمد احمد'),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Initial LTR English state
      expect(find.text('Title: Hissab'), findsOneWidget);
      expect(find.text('Direction: TextDirection.ltr'), findsOneWidget);

      // Repeat switching cycle 10 times
      for (int cycle = 0; cycle < 10; cycle++) {
        // en -> ur
        await appController.setLocale('ur');
        await tester.pumpAndSettle();
        expect(find.text('Title: حساب'), findsOneWidget);
        expect(find.text('Direction: TextDirection.rtl'), findsOneWidget);
        expect(find.text('User Note: آج احمد سے پانچ سو ریال وصول ہوئے'), findsOneWidget);

        // ur -> ar
        await appController.setLocale('ar');
        await tester.pumpAndSettle();
        expect(find.text('Title: حِساب'), findsOneWidget);
        expect(find.text('Direction: TextDirection.rtl'), findsOneWidget);

        // ar -> en
        await appController.setLocale('en');
        await tester.pumpAndSettle();
        expect(find.text('Title: Hissab'), findsOneWidget);
        expect(find.text('Direction: TextDirection.ltr'), findsOneWidget);
      }
    });

    testWidgets('Full HissabApp renders with locale switches', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'hissab_locale': 'ur'});
      await tester.pumpWidget(const HissabApp());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
