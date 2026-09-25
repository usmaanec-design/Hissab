import 'package:sqflite/sqflite.dart';
import 'package:hissab/data/database/app_database.dart';
import 'package:hissab/data/database/tables.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/repositories/book_repository.dart';

/// Financial aggregate for a single book.
class BookFinancialSummary {
  final BookModel book;
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int currentBalanceMinor;

  const BookFinancialSummary({
    required this.book,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.currentBalanceMinor,
  });
}

/// Global financial aggregate across all user books.
class GlobalDashboardData {
  final int globalIncomeMinor;
  final int globalExpenseMinor;
  final int globalBalanceMinor;
  final List<BookFinancialSummary> bookSummaries;

  const GlobalDashboardData({
    required this.globalIncomeMinor,
    required this.globalExpenseMinor,
    required this.globalBalanceMinor,
    required this.bookSummaries,
  });

  static const GlobalDashboardData empty = GlobalDashboardData(
    globalIncomeMinor: 0,
    globalExpenseMinor: 0,
    globalBalanceMinor: 0,
    bookSummaries: [],
  );
}

/// Service providing efficient database-level aggregation across all books.
class DashboardSummaryService {
  final Database? _database;
  final BookRepository _bookRepository = BookRepository();

  DashboardSummaryService({Database? database}) : _database = database;

  Future<Database> get _db async => _database ?? await AppDatabase.instance.database;

  /// Efficiently computes global financial totals and per-book aggregates using a single SQL query.
  Future<GlobalDashboardData> getGlobalDashboardData() async {
    final db = await _db;
    final List<BookModel> books;
    if (_database != null) {
      final rows = await db.query(Tables.books, where: 'is_deleted = 0 AND is_archived = 0');
      books = rows.map(BookModel.fromMap).toList();
    } else {
      books = await _bookRepository.getBooks();
    }
    if (books.isEmpty) return GlobalDashboardData.empty;

    // Aggregate income and expense grouped by book_id in SQL for maximum efficiency
    final rows = await db.rawQuery('''
      SELECT
        book_id,
        COALESCE(SUM(CASE WHEN type = 'INCOME' AND is_deleted = 0 THEN amount_minor ELSE 0 END), 0) AS total_income,
        COALESCE(SUM(CASE WHEN type = 'EXPENSE' AND is_deleted = 0 THEN amount_minor ELSE 0 END), 0) AS total_expense
      FROM ${Tables.transactions}
      WHERE is_deleted = 0
      GROUP BY book_id
    ''');

    final Map<String, ({int income, int expense})> txMap = {};
    for (final row in rows) {
      final bId = row['book_id'] as String?;
      if (bId != null) {
        txMap[bId] = (
          income: (row['total_income'] as num? ?? 0).toInt(),
          expense: (row['total_expense'] as num? ?? 0).toInt(),
        );
      }
    }

    int globalIncome = 0;
    int globalExpense = 0;
    int globalBalance = 0;
    final List<BookFinancialSummary> summaries = [];

    for (final book in books) {
      final tx = txMap[book.id];
      final inc = tx?.income ?? 0;
      final exp = tx?.expense ?? 0;
      final balance = book.openingBalanceMinor + inc - exp;

      globalIncome += inc;
      globalExpense += exp;
      globalBalance += balance;

      summaries.add(
        BookFinancialSummary(
          book: book,
          totalIncomeMinor: inc,
          totalExpenseMinor: exp,
          currentBalanceMinor: balance,
        ),
      );
    }

    return GlobalDashboardData(
      globalIncomeMinor: globalIncome,
      globalExpenseMinor: globalExpense,
      globalBalanceMinor: globalBalance,
      bookSummaries: summaries,
    );
  }
}
