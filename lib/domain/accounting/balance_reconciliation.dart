import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'accounting_engine.dart';

enum ReconciliationStatus {
  balanced,
  mismatch,
}

class ReconciliationResult {
  final ReconciliationStatus status;
  final int ledgerCalculatedBalanceMinor;
  final int displayedBalanceMinor;
  final int discrepancyMinor;
  final String message;

  const ReconciliationResult({
    required this.status,
    required this.ledgerCalculatedBalanceMinor,
    required this.displayedBalanceMinor,
    required this.discrepancyMinor,
    required this.message,
  });

  bool get isHealthy => status == ReconciliationStatus.balanced;
}

class BalanceReconciliation {
  /// Audits the entire transaction journal for a given book against a test/displayed balance.
  static ReconciliationResult auditBook({
    required BookModel book,
    required List<TransactionModel> transactions,
    required int displayedBalanceMinor,
  }) {
    final summary = AccountingEngine.calculateBookSummary(
      book: book,
      transactions: transactions,
    );

    final ledgerBalance = summary.currentBalanceMinor;
    final discrepancy = ledgerBalance - displayedBalanceMinor;

    if (discrepancy == 0) {
      return ReconciliationResult(
        status: ReconciliationStatus.balanced,
        ledgerCalculatedBalanceMinor: ledgerBalance,
        displayedBalanceMinor: displayedBalanceMinor,
        discrepancyMinor: 0,
        message: 'Ledger is strictly balanced and 100% verified against journal records.',
      );
    } else {
      return ReconciliationResult(
        status: ReconciliationStatus.mismatch,
        ledgerCalculatedBalanceMinor: ledgerBalance,
        displayedBalanceMinor: displayedBalanceMinor,
        discrepancyMinor: discrepancy,
        message: 'BALANCE_MISMATCH: Ledger discrepancy of $discrepancy minor units detected!',
      );
    }
  }
}
