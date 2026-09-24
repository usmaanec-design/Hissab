import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/models/transaction_model.dart';

class BookSummary {
  final int openingBalanceMinor;
  final int totalMoneyInMinor;
  final int totalMoneyOutMinor;
  final int currentBalanceMinor;
  final int netCashFlowMinor; // totalMoneyIn - totalMoneyOut
  final int transactionCount;

  const BookSummary({
    required this.openingBalanceMinor,
    required this.totalMoneyInMinor,
    required this.totalMoneyOutMinor,
    required this.currentBalanceMinor,
    required this.netCashFlowMinor,
    required this.transactionCount,
  });
}

class PartyBalanceSummary {
  final int totalBilledMinor; // Total sales to customer or total purchases from supplier
  final int totalPaidOrReceivedMinor; // Total paid to supplier or received from customer
  final int outstandingMinor; // Net receivable or payable

  const PartyBalanceSummary({
    required this.totalBilledMinor,
    required this.totalPaidOrReceivedMinor,
    required this.outstandingMinor,
  });
}

class AccountingEngine {
  /// Computes accurate BookSummary from a list of transactions and the book's opening balance.
  /// Ignores deleted transactions (`isDeleted == true`).
  /// Internal transfers (TRANSFER_IN and TRANSFER_OUT) do NOT alter the global book net balance,
  /// preserving accounting neutrality.
  static BookSummary calculateBookSummary({
    required BookModel book,
    required List<TransactionModel> transactions,
  }) {
    int totalIn = 0;
    int totalOut = 0;
    int validTxCount = 0;

    for (final tx in transactions) {
      if (tx.isDeleted) continue;

      switch (tx.type) {
        case TransactionType.income:
        case TransactionType.paymentReceived:
          totalIn += tx.amountMinorUnit;
          validTxCount++;
          break;

        case TransactionType.expense:
        case TransactionType.paymentMade:
          totalOut += tx.amountMinorUnit;
          validTxCount++;
          break;

        case TransactionType.adjustment:
          // Adjustments can be positive or negative depending on context,
          // but if stored as signed minor units or marked as in/out:
          totalIn += tx.amountMinorUnit;
          validTxCount++;
          break;

        case TransactionType.transferIn:
        case TransactionType.transferOut:
          // Internal transfers cancel each other out at the book level
          validTxCount++;
          break;

        case TransactionType.receivable:
        case TransactionType.payable:
          // Memo/credit transactions; do not affect instant cash flow until paid
          validTxCount++;
          break;
      }
    }

    final netCashFlow = totalIn - totalOut;
    final currentBalance = book.openingBalanceMinor + netCashFlow;

    return BookSummary(
      openingBalanceMinor: book.openingBalanceMinor,
      totalMoneyInMinor: totalIn,
      totalMoneyOutMinor: totalOut,
      currentBalanceMinor: currentBalance,
      netCashFlowMinor: netCashFlow,
      transactionCount: validTxCount,
    );
  }

  /// Calculates individual account balance:
  /// Account Balance = Account Opening Balance + Transfers In - Transfers Out + Direct Account In - Direct Account Out
  static int calculateAccountBalance({
    required int openingBalanceMinor,
    required String accountId,
    required List<TransactionModel> transactions,
  }) {
    int balance = openingBalanceMinor;

    for (final tx in transactions) {
      if (tx.isDeleted || tx.accountId != accountId) continue;

      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.paymentReceived ||
          tx.type == TransactionType.transferIn) {
        balance += tx.amountMinorUnit;
      } else if (tx.type == TransactionType.expense ||
          tx.type == TransactionType.paymentMade ||
          tx.type == TransactionType.transferOut) {
        balance -= tx.amountMinorUnit;
      }
    }

    return balance;
  }

  /// Calculates Party ledger summary:
  /// For Customer:
  ///   totalBilled = Sales / Receivable (+ amount)
  ///   totalReceived = Payment Received / Income (- amount owed)
  ///   outstanding = totalBilled - totalReceived
  /// For Supplier:
  ///   totalBilled = Purchases / Payable (+ amount)
  ///   totalPaid = Payment Made / Expense (- amount owed)
  ///   outstanding = totalBilled - totalPaid
  static PartyBalanceSummary calculatePartySummary({
    required String partyId,
    required String partyType,
    required List<TransactionModel> transactions,
  }) {
    int totalBilled = 0;
    int totalPaidOrReceived = 0;

    for (final tx in transactions) {
      if (tx.isDeleted || tx.partyId != partyId) continue;

      if (partyType.toLowerCase() == 'customer') {
        if (tx.type == TransactionType.income ||
            tx.type == TransactionType.receivable) {
          totalBilled += tx.amountMinorUnit;
        } else if (tx.type == TransactionType.paymentReceived) {
          totalPaidOrReceived += tx.amountMinorUnit;
        }
      } else {
        // Supplier, Employee, Other
        if (tx.type == TransactionType.expense ||
            tx.type == TransactionType.payable) {
          totalBilled += tx.amountMinorUnit;
        } else if (tx.type == TransactionType.paymentMade) {
          totalPaidOrReceived += tx.amountMinorUnit;
        }
      }
    }

    final outstanding = totalBilled - totalPaidOrReceived;

    return PartyBalanceSummary(
      totalBilledMinor: totalBilled,
      totalPaidOrReceivedMinor: totalPaidOrReceived,
      outstandingMinor: outstanding,
    );
  }

  /// Diagnostic reconciliation verification
  static bool verifyReconciliation({
    required int displayedBalanceMinor,
    required BookModel book,
    required List<TransactionModel> transactions,
  }) {
    final summary = calculateBookSummary(book: book, transactions: transactions);
    return summary.currentBalanceMinor == displayedBalanceMinor;
  }
}
