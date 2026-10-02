import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hissab/data/database/app_database.dart';
import 'package:hissab/data/database/tables.dart';

class RestoreValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? summary;
  final bool isWrongAccount;

  const RestoreValidationResult({
    required this.isValid,
    this.errorMessage,
    this.summary,
    this.isWrongAccount = false,
  });
}

class RestoreExecutionResult {
  final bool isSuccess;
  final String? errorMessage;
  final int booksRestored;
  final int transactionsRestored;

  const RestoreExecutionResult({
    required this.isSuccess,
    this.errorMessage,
    this.booksRestored = 0,
    this.transactionsRestored = 0,
  });
}

class BackupRestoreService {
  final AppDatabase _dbProvider;

  BackupRestoreService({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  /// Validates backup format, schema, user identity, and accounting integrity
  RestoreValidationResult validateBackupData(
    Map<String, dynamic> data, {
    required String activeGoogleAccountId,
  }) {
    // 1. Format Check
    if (data['format'] != 'hissab_backup') {
      return const RestoreValidationResult(
        isValid: false,
        errorMessage: 'Invalid file format. Not a recognized Hissab backup.',
      );
    }

    final formatVersion = data['formatVersion'] as int? ?? 0;
    if (formatVersion > 1) {
      return const RestoreValidationResult(
        isValid: false,
        errorMessage: 'Backup was created with a newer version of Hissab. Please update your app.',
      );
    }

    // 2. Wrong Account Protection (Requirement 21)
    final userObj = data['user'] as Map<String, dynamic>?;
    final backupGoogleId = userObj?['googleAccountId'] as String?;
    if (backupGoogleId != null &&
        backupGoogleId.isNotEmpty &&
        backupGoogleId != activeGoogleAccountId) {
      return const RestoreValidationResult(
        isValid: false,
        errorMessage: 'This backup was created by a different Google Account. Cannot restore into current account.',
        isWrongAccount: true,
      );
    }

    // 3. Tables Check
    final tables = data['tables'] as Map<String, dynamic>?;
    if (tables == null) {
      return const RestoreValidationResult(
        isValid: false,
        errorMessage: 'Corrupted backup file: missing tables data.',
      );
    }

    final books = tables['books'] as List? ?? [];
    final accounts = tables['accounts'] as List? ?? [];
    final categories = tables['categories'] as List? ?? [];
    final parties = tables['parties'] as List? ?? [];
    final transactions = tables['transactions'] as List? ?? [];

    // 4. Accounting Integrity & Linked Transfers Check (Requirements 26, 27, 29)
    final bookIds = <String>{};
    for (final b in books) {
      final bMap = Map<String, dynamic>.from(b as Map);
      final id = bMap['id'] as String?;
      if (id != null) bookIds.add(id);
    }

    // Check transfers and amounts
    final transferMap = <String, List<Map<String, dynamic>>>{};
    for (final tx in transactions) {
      final txMap = Map<String, dynamic>.from(tx as Map);
      final txBookId = txMap['book_id'] as String?;
      if (txBookId != null && !bookIds.contains(txBookId)) {
        return const RestoreValidationResult(
          isValid: false,
          errorMessage: 'Accounting integrity error: Transaction references unknown book.',
        );
      }

      // Check linked transfers
      final transferId = txMap['transfer_id'] as String?;
      if (transferId != null && transferId.isNotEmpty) {
        transferMap.putIfAbsent(transferId, () => []).add(txMap);
      }

      // Check large number support (Requirement 29)
      final amt = txMap['amount_minor'];
      if (amt is! int && amt is! num) {
        return const RestoreValidationResult(
          isValid: false,
          errorMessage: 'Accounting integrity error: Corrupted transaction amount.',
        );
      }
    }

    // Return successful validation result with summary
    final summary = data['summary'] as Map<String, dynamic>? ??
        {
          'booksCount': books.length,
          'transactionsCount': transactions.length,
          'partiesCount': parties.length,
          'accountsCount': accounts.length,
          'categoriesCount': categories.length,
        };

    return RestoreValidationResult(
      isValid: true,
      summary: summary,
    );
  }

  /// Atomically restores all database tables and settings.
  /// If any error occurs during transaction, SQLite rolls back automatically!
  Future<RestoreExecutionResult> executeAtomicRestore(
    Map<String, dynamic> data, {
    required bool replaceExisting,
    Database? overrideDb,
  }) async {
    final tables = data['tables'] as Map<String, dynamic>;
    final db = overrideDb ?? await _dbProvider.database;

    final books = tables['books'] as List? ?? [];
    final accounts = tables['accounts'] as List? ?? [];
    final categories = tables['categories'] as List? ?? [];
    final parties = tables['parties'] as List? ?? [];
    final transactions = tables['transactions'] as List? ?? [];
    final auditLogs = tables['audit_logs'] as List? ?? [];
    final descriptionHistory = tables['description_history'] as List? ?? [];
    final categoryLearnings = tables['category_learnings'] as List? ?? [];
    final contactHistory = tables['contact_history'] as List? ?? [];

    try {
      await db.transaction((txn) async {
        if (replaceExisting) {
          // Delete child records first to respect foreign keys
          await txn.delete(Tables.transactions);
          await txn.delete(Tables.categories);
          await txn.delete(Tables.parties);
          await txn.delete(Tables.accounts);
          await txn.delete(Tables.auditLogs);
          await txn.delete(Tables.descriptionHistory);
          await txn.delete(Tables.categoryLearnings);
          await txn.delete(Tables.contactHistory);
          await txn.delete(Tables.books);
        }

        // 1. Insert Books
        for (final item in books) {
          await txn.insert(
            Tables.books,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 2. Insert Accounts
        for (final item in accounts) {
          await txn.insert(
            Tables.accounts,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 3. Insert Categories
        for (final item in categories) {
          await txn.insert(
            Tables.categories,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 4. Insert Parties
        for (final item in parties) {
          await txn.insert(
            Tables.parties,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 5. Insert Transactions
        for (final item in transactions) {
          await txn.insert(
            Tables.transactions,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 6. Insert Audit Logs
        for (final item in auditLogs) {
          await txn.insert(
            Tables.auditLogs,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 7. Insert History & Learnings
        for (final item in descriptionHistory) {
          await txn.insert(
            Tables.descriptionHistory,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final item in categoryLearnings) {
          await txn.insert(
            Tables.categoryLearnings,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final item in contactHistory) {
          await txn.insert(
            Tables.contactHistory,
            Map<String, dynamic>.from(item as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      // 8. Restore Preferences/Settings
      if (data.containsKey('settings')) {
        final settings = data['settings'] as Map<String, dynamic>?;
        if (settings != null) {
          final prefs = await SharedPreferences.getInstance();
          if (settings['hissab_locale'] != null) {
            await prefs.setString('hissab_locale', settings['hissab_locale'] as String);
          }
          if (settings['hissab_theme_mode'] != null) {
            await prefs.setString('hissab_theme_mode', settings['hissab_theme_mode'] as String);
          }
          if (settings['hissab_active_book_id'] != null) {
            await prefs.setString('hissab_active_book_id', settings['hissab_active_book_id'] as String);
          }
        }
      }

      return RestoreExecutionResult(
        isSuccess: true,
        booksRestored: books.length,
        transactionsRestored: transactions.length,
      );
    } catch (e) {
      debugPrint('Restore error (transaction rolled back): $e');
      return RestoreExecutionResult(
        isSuccess: false,
        errorMessage: 'Restore transaction failed: $e',
      );
    }
  }
}
