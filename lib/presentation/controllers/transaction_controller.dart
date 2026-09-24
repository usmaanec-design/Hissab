import 'package:flutter/material.dart';
import 'package:hissab/core/utils/date_formatter.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/data/repositories/transaction_repository.dart';
import 'package:hissab/domain/accounting/accounting_engine.dart';
import 'package:hissab/domain/accounting/balance_reconciliation.dart';

class TransactionController extends ChangeNotifier {
  final TransactionRepository _transactionRepository = TransactionRepository();

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _recentTransactions = [];
  BookSummary _summary = const BookSummary(
    openingBalanceMinor: 0,
    totalMoneyInMinor: 0,
    totalMoneyOutMinor: 0,
    currentBalanceMinor: 0,
    netCashFlowMinor: 0,
    transactionCount: 0,
  );

  int _todayInMinor = 0;
  int _todayOutMinor = 0;
  bool _isLoading = false;
  TransactionFilter _currentFilter = const TransactionFilter();

  List<TransactionModel> get transactions => _transactions;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  BookSummary get summary => _summary;
  int get todayInMinor => _todayInMinor;
  int get todayOutMinor => _todayOutMinor;
  bool get isLoading => _isLoading;
  TransactionFilter get currentFilter => _currentFilter;

  /// Loads transactions and calculates exact ledger balance for the given book
  Future<void> loadForBook(BookModel? book, {TransactionFilter? filter}) async {
    if (book == null) {
      _transactions = [];
      _recentTransactions = [];
      _todayInMinor = 0;
      _todayOutMinor = 0;
      _summary = const BookSummary(
        openingBalanceMinor: 0,
        totalMoneyInMinor: 0,
        totalMoneyOutMinor: 0,
        currentBalanceMinor: 0,
        netCashFlowMinor: 0,
        transactionCount: 0,
      );
      notifyListeners();
      return;
    }

    _isLoading = true;
    if (filter != null) {
      _currentFilter = filter;
    }
    notifyListeners();

    try {
      // 1. Fetch filtered transactions for view
      _transactions = await _transactionRepository.getTransactions(
        bookId: book.id,
        filter: _currentFilter,
        limit: 100,
      );

      // 2. Fetch all active transactions to calculate exact auditable BookSummary
      final allActive = await _transactionRepository.getAllActiveTransactions(book.id);
      _summary = AccountingEngine.calculateBookSummary(
        book: book,
        transactions: allActive,
      );

      // 3. Compute today's summary using local date
      final todayStr = DateFormatter.toIsoDate(DateTime.now());
      int todayIn = 0;
      int todayOut = 0;
      for (final tx in allActive) {
        if (tx.date == todayStr) {
          if (tx.type.isMoneyIn) todayIn += tx.amountMinorUnit;
          if (tx.type.isMoneyOut) todayOut += tx.amountMinorUnit;
        }
      }
      _todayInMinor = todayIn;
      _todayOutMinor = todayOut;

      // 4. Recent transactions (first 10)
      _recentTransactions = _transactions.take(10).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(TransactionModel tx, BookModel book) async {
    await _transactionRepository.addTransaction(tx);
    await loadForBook(book);
  }

  Future<void> updateTransaction(TransactionModel tx, BookModel book) async {
    await _transactionRepository.updateTransaction(tx);
    await loadForBook(book);
  }

  Future<void> deleteTransaction(String txId, BookModel book) async {
    await _transactionRepository.softDeleteTransaction(txId, book.id);
    await loadForBook(book);
  }

  Future<void> restoreTransaction(String txId, BookModel book) async {
    await _transactionRepository.restoreTransaction(txId, book.id);
    await loadForBook(book);
  }

  Future<void> transfer({
    required BookModel book,
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountMinorUnit,
    required String date,
    required String time,
    String? description,
  }) async {
    await _transactionRepository.createInternalTransfer(
      bookId: book.id,
      sourceAccountId: sourceAccountId,
      destinationAccountId: destinationAccountId,
      amountMinorUnit: amountMinorUnit,
      date: date,
      time: time,
      description: description,
    );
    await loadForBook(book);
  }

  Future<void> applyFilter(TransactionFilter filter, BookModel book) async {
    _currentFilter = filter;
    await loadForBook(book, filter: filter);
  }

  Future<void> clearFilter(BookModel book) async {
    _currentFilter = const TransactionFilter();
    await loadForBook(book, filter: _currentFilter);
  }

  Future<ReconciliationResult> reconcile(BookModel book) async {
    final allActive = await _transactionRepository.getAllActiveTransactions(book.id);
    return BalanceReconciliation.auditBook(
      book: book,
      transactions: allActive,
      displayedBalanceMinor: _summary.currentBalanceMinor,
    );
  }
}
