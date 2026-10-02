import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hissab/data/database/app_database.dart';
import 'package:hissab/data/database/tables.dart';

// Conditional import or safe IO check for portable image handling
import 'dart:io' as io;

class BackupExportService {
  final AppDatabase _dbProvider;

  BackupExportService({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  /// Creates a complete logical Hissab backup JSON string
  Future<String> exportLogicalBackupJson({
    required String googleAccountId,
    String appVersion = '1.0.0',
    Database? overrideDb,
  }) async {
    final data = await createLogicalBackupData(
      googleAccountId: googleAccountId,
      appVersion: appVersion,
      overrideDb: overrideDb,
    );
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Creates raw Map for the backup payload
  Future<Map<String, dynamic>> createLogicalBackupData({
    required String googleAccountId,
    String appVersion = '1.0.0',
    Database? overrideDb,
  }) async {
    final db = overrideDb ?? await _dbProvider.database;

    // 1. Export all tables
    final rawBooks = await db.query(Tables.books);
    final accounts = await db.query(Tables.accounts);
    final categories = await db.query(Tables.categories);
    final parties = await db.query(Tables.parties);
    final transactions = await db.query(Tables.transactions);
    final auditLogs = await db.query(Tables.auditLogs);
    final descriptionHistory = await db.query(Tables.descriptionHistory);
    final categoryLearnings = await db.query(Tables.categoryLearnings);
    final contactHistory = await db.query(Tables.contactHistory);

    // 2. Portable Book Logos (Requirement 8)
    // Convert any local device file paths into portable Base64 data so they survive cross-device restore
    final portableBooks = <Map<String, dynamic>>[];
    for (final b in rawBooks) {
      final bookMap = Map<String, dynamic>.from(b);
      final logo = bookMap['logo'] as String?;
      if (logo != null && logo.isNotEmpty) {
        bookMap['logo'] = _makeLogoPortable(logo);
      }
      portableBooks.add(bookMap);
    }

    // 3. User Settings & Preferences
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{
      'hissab_locale': prefs.getString('hissab_locale'),
      'hissab_theme_mode': prefs.getString('hissab_theme_mode'),
      'hissab_active_book_id': prefs.getString('hissab_active_book_id'),
    };

    // 4. Calculate verification totals (using integer minor units - no floating point!)
    int totalMoneyInMinor = 0;
    int totalMoneyOutMinor = 0;
    for (final tx in transactions) {
      if ((tx['is_deleted'] as int? ?? 0) == 1) continue;
      final type = tx['type'] as String? ?? '';
      final amt = tx['amount_minor'] as int? ?? 0;
      if (type == 'in' || type.toLowerCase().contains('in')) {
        totalMoneyInMinor += amt;
      } else if (type == 'out' || type.toLowerCase().contains('out')) {
        totalMoneyOutMinor += amt;
      }
    }

    return {
      'format': 'hissab_backup',
      'formatVersion': 1,
      'schemaVersion': 3,
      'appVersion': appVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'user': {
        'googleAccountId': googleAccountId,
      },
      'summary': {
        'booksCount': portableBooks.length,
        'transactionsCount': transactions.length,
        'partiesCount': parties.length,
        'accountsCount': accounts.length,
        'totalMoneyInMinor': totalMoneyInMinor,
        'totalMoneyOutMinor': totalMoneyOutMinor,
        'netBalanceMinor': totalMoneyInMinor - totalMoneyOutMinor,
      },
      'tables': {
        'books': portableBooks,
        'accounts': accounts,
        'categories': categories,
        'parties': parties,
        'transactions': transactions,
        'audit_logs': auditLogs,
        'description_history': descriptionHistory,
        'category_learnings': categoryLearnings,
        'contact_history': contactHistory,
      },
      'settings': settings,
    };
  }

  /// Converts a local file path into portable Base64 data URI
  String _makeLogoPortable(String logo) {
    if (logo.startsWith('bank:') ||
        logo.startsWith('assets/') ||
        logo.startsWith('data:image/') ||
        logo.length > 200) {
      // Already a bank catalog key, asset, or Base64 URI
      return logo;
    }

    // Local file path on disk
    if (!kIsWeb && (logo.startsWith('/') || logo.startsWith('file:') || logo.contains(r':\'))) {
      try {
        final filePath = logo.startsWith('file:') ? logo.substring(5) : logo;
        final file = io.File(filePath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          final b64 = base64Encode(bytes);
          return 'data:image/png;base64,$b64';
        }
      } catch (_) {
        // Fallback to original string if cannot be read
      }
    }
    return logo;
  }
}
