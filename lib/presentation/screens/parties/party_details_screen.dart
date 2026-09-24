import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/data/models/party_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/domain/accounting/accounting_engine.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/widgets/transaction_tile.dart';
import 'package:hissab/presentation/screens/transactions/transaction_details_screen.dart';
import 'package:hissab/presentation/screens/transactions/add_transaction_screen.dart';

class PartyDetailsScreen extends StatefulWidget {
  final PartyModel party;

  const PartyDetailsScreen({super.key, required this.party});

  @override
  State<PartyDetailsScreen> createState() => _PartyDetailsScreenState();
}

class _PartyDetailsScreenState extends State<PartyDetailsScreen> {
  List<TransactionModel> _partyTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    final book = context.read<BookController>().activeBook;
    if (book != null) {
      final txs = await context.read<PartyController>().getPartyTransactions(widget.party.id, book.id);
      setState(() {
        _partyTransactions = txs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final partyController = context.watch<PartyController>();
    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final summary = partyController.partySummaries[widget.party.id] ??
        const PartyBalanceSummary(totalBilledMinor: 0, totalPaidOrReceivedMinor: 0, outstandingMinor: 0);

    final isCustomer = widget.party.type.toLowerCase() == 'customer';
    final isReceivable = summary.outstandingMinor > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.party.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLedger,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Party Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.party.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                if (widget.party.phone != null && widget.party.phone!.isNotEmpty)
                                  Text(
                                    widget.party.phone!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.party.type.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Statement Balance Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isCustomer ? 'Total Sales / Invoiced:' : 'Total Purchases:',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              CurrencyFormatter.format(summary.totalBilledMinor, currency),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isCustomer ? 'Total Received:' : 'Total Paid:',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              CurrencyFormatter.format(summary.totalPaidOrReceivedMinor, currency),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isReceivable
                                ? AppColors.moneyInContainer
                                : AppColors.moneyOutContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isCustomer
                                    ? (isReceivable ? 'Outstanding Receivable:' : 'Customer Overpaid:')
                                    : (isReceivable ? 'Remaining Payable:' : 'Supplier Overpaid:'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isReceivable ? AppColors.moneyIn : AppColors.moneyOut,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(summary.outstandingMinor.abs(), currency),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isReceivable ? AppColors.moneyIn : AppColors.moneyOut,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick Action Buttons for Party
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.moneyIn,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(isCustomer ? 'Receive Payment' : 'New Purchase'),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddTransactionScreen(
                                  initialType: isCustomer ? TransactionType.paymentReceived : TransactionType.expense,
                                ),
                              ),
                            );
                            _loadLedger();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.moneyOut,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.remove, size: 18),
                          label: Text(isCustomer ? 'New Sale' : 'Make Payment'),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddTransactionScreen(
                                  initialType: isCustomer ? TransactionType.income : TransactionType.paymentMade,
                                ),
                              ),
                            );
                            _loadLedger();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Ledger Transactions
                  const Text(
                    'Ledger Statement',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  if (_partyTransactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No transactions recorded for this contact yet.',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._partyTransactions.map((tx) => TransactionTile(
                          transaction: tx,
                          currency: currency,
                          partyName: widget.party.name,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransactionDetailsScreen(transaction: tx),
                              ),
                            );
                            _loadLedger();
                          },
                        )),
                ],
              ),
            ),
    );
  }
}
