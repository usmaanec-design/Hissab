import 'package:flutter/material.dart';
import 'package:hissab/data/models/account_model.dart';
import 'package:hissab/data/repositories/account_repository.dart';
import 'package:hissab/data/repositories/transaction_repository.dart';
import 'package:hissab/domain/accounting/accounting_engine.dart';

class AccountController extends ChangeNotifier {
  final AccountRepository _accountRepository = AccountRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  List<AccountModel> _accounts = [];
  Map<String, int> _accountBalances = {};
  bool _isLoading = false;

  List<AccountModel> get accounts => _accounts;
  Map<String, int> get accountBalances => _accountBalances;
  bool get isLoading => _isLoading;

  Future<void> loadForBook(String? bookId) async {
    if (bookId == null) {
      _accounts = [];
      _accountBalances = {};
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _accounts = await _accountRepository.getAccounts(bookId);
      final allTx = await _transactionRepository.getAllActiveTransactions(bookId);

      final Map<String, int> balances = {};
      for (final acc in _accounts) {
        final bal = AccountingEngine.calculateAccountBalance(
          openingBalanceMinor: acc.openingBalanceMinor,
          accountId: acc.id,
          transactions: allTx,
        );
        balances[acc.id] = bal;
      }
      _accountBalances = balances;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AccountModel> addAccount({
    required String bookId,
    required String name,
    required String type,
    int openingBalanceMinor = 0,
  }) async {
    final acc = await _accountRepository.createAccount(
      bookId: bookId,
      name: name,
      type: type,
      openingBalanceMinor: openingBalanceMinor,
    );
    await loadForBook(bookId);
    return acc;
  }

  Future<void> updateAccount(AccountModel account) async {
    await _accountRepository.updateAccount(account);
    await loadForBook(account.bookId);
  }
}
