import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'platform/database_platform.dart';
import 'tables.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database using centralized platform resolution
  Future<Database> _initDatabase({String? customPath}) async {
    await DatabasePlatform.initialize();
    final dbPath = customPath ?? await DatabasePlatform.getDatabasePath('hissab_v1.db');

    final db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute(Tables.createBooksTable);
        await db.execute(Tables.createAccountsTable);
        await db.execute(Tables.createCategoriesTable);
        await db.execute(Tables.createPartiesTable);
        await db.execute(Tables.createTransactionsTable);
        await db.execute(Tables.createAuditLogsTable);
        await db.execute(Tables.createDescriptionHistoryTable);
        await db.execute(Tables.createCategoryLearningsTable);
        await db.execute(Tables.createContactHistoryTable);

        for (final idx in Tables.createIndexes) {
          await db.execute(idx);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE ${Tables.books} ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE ${Tables.books} ADD COLUMN color INTEGER NOT NULL DEFAULT 4280656875;');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE ${Tables.books} ADD COLUMN logo TEXT;');
          } catch (_) {}
          try {
            await db.execute(Tables.createDescriptionHistoryTable);
          } catch (_) {}
          try {
            await db.execute(Tables.createCategoryLearningsTable);
          } catch (_) {}
          try {
            await db.execute(Tables.createContactHistoryTable);
          } catch (_) {}
          for (final idx in Tables.createIndexes) {
            try {
              await db.execute(idx);
            } catch (_) {}
          }
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );

    return db;
  }

  /// Seed default categories for a newly created Book
  static Future<void> seedDefaultCategories(DatabaseExecutor db, String bookId) async {
    final now = DateTime.now().toIso8601String();
    const uuid = Uuid();

    final defaultIncome = [
      {'name': 'Sales', 'icon': 'shopping_bag', 'color': 0xFF059669},
      {'name': 'Salary', 'icon': 'payments', 'color': 0xFF10B981},
      {'name': 'Business Income', 'icon': 'store', 'color': 0xFF0D9488},
      {'name': 'Commission', 'icon': 'percent', 'color': 0xFF14B8A6},
      {'name': 'Refund', 'icon': 'replay', 'color': 0xFF06B6D4},
      {'name': 'Other Income', 'icon': 'attach_money', 'color': 0xFF3B82F6},
    ];

    final defaultExpense = [
      {'name': 'Food & Dining', 'icon': 'restaurant', 'color': 0xFFE11D48},
      {'name': 'Transport', 'icon': 'directions_car', 'color': 0xFFF43F5E},
      {'name': 'Fuel', 'icon': 'local_gas_station', 'color': 0xFFEA580C},
      {'name': 'Shopping', 'icon': 'shopping_cart', 'color': 0xFFD97706},
      {'name': 'Rent', 'icon': 'home', 'color': 0xFF8B5CF6},
      {'name': 'Utilities', 'icon': 'bolt', 'color': 0xFF6366F1},
      {'name': 'Salary Paid', 'icon': 'badge', 'color': 0xFFEC4899},
      {'name': 'Office Supplies', 'icon': 'business', 'color': 0xFF64748B},
      {'name': 'Maintenance', 'icon': 'build', 'color': 0xFF78716C},
      {'name': 'Medical', 'icon': 'medical_services', 'color': 0xFFEF4444},
      {'name': 'Education', 'icon': 'school', 'color': 0xFF0284C7},
      {'name': 'Travel', 'icon': 'flight', 'color': 0xFF0EA5E9},
      {'name': 'Other Expense', 'icon': 'more_horiz', 'color': 0xFF94A3B8},
    ];

    for (final item in defaultIncome) {
      await db.insert(Tables.categories, {
        'id': uuid.v4(),
        'book_id': bookId,
        'name': item['name'],
        'type': 'income',
        'icon': item['icon'],
        'color': item['color'],
        'is_default': 1,
        'is_deleted': 0,
        'created_at': now,
      });
    }

    for (final item in defaultExpense) {
      await db.insert(Tables.categories, {
        'id': uuid.v4(),
        'book_id': bookId,
        'name': item['name'],
        'type': 'expense',
        'icon': item['icon'],
        'color': item['color'],
        'is_default': 1,
        'is_deleted': 0,
        'created_at': now,
      });
    }
  }

  /// Seed default accounts (Cash, Bank, Card) for a newly created Book
  static Future<void> seedDefaultAccounts(DatabaseExecutor db, String bookId) async {
    final now = DateTime.now().toIso8601String();
    const uuid = Uuid();

    final defaults = [
      {'name': 'Cash in Hand', 'type': 'cash'},
      {'name': 'Bank Account', 'type': 'bank'},
      {'name': 'Card / Mada', 'type': 'mada'},
    ];

    for (final acc in defaults) {
      await db.insert(Tables.accounts, {
        'id': uuid.v4(),
        'book_id': bookId,
        'name': acc['name'],
        'type': acc['type'],
        'opening_balance_minor': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// For testing or clean in-memory usage
  static Future<Database> createInMemoryDatabase() async {
    await DatabasePlatform.initialize();
    return await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(Tables.createBooksTable);
        await db.execute(Tables.createAccountsTable);
        await db.execute(Tables.createCategoriesTable);
        await db.execute(Tables.createPartiesTable);
        await db.execute(Tables.createTransactionsTable);
        await db.execute(Tables.createAuditLogsTable);
        await db.execute(Tables.createDescriptionHistoryTable);
        await db.execute(Tables.createCategoryLearningsTable);
        await db.execute(Tables.createContactHistoryTable);
        for (final idx in Tables.createIndexes) {
          await db.execute(idx);
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
