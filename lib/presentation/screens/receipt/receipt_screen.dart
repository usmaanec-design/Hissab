import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/data/repositories/backup_repository.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';

class ReceiptScreen extends StatefulWidget {
  final TransactionModel transaction;
  final String partyName;

  const ReceiptScreen({
    super.key,
    required this.transaction,
    required this.partyName,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final TextEditingController _businessNameController = TextEditingController(text: 'My Business');
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late String _receiptNumber;

  @override
  void initState() {
    super.initState();
    final year = DateTime.now().year;
    final shortId = widget.transaction.id.substring(0, 6).toUpperCase();
    _receiptNumber = 'HS-$year-$shortId';
    _purposeController.text = widget.transaction.description ?? 'General Payment';
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _printOrShareReceipt(BuildContext context, CurrencyConfig currency) async {
    final repo = BackupRepository();
    final bytes = await repo.generateReceiptPdf(
      businessName: _businessNameController.text.trim().isEmpty
          ? 'HISSAB BUSINESS'
          : _businessNameController.text.trim(),
      receiptNumber: _receiptNumber,
      date: widget.transaction.date,
      receivedFrom: widget.partyName,
      amountMinorUnit: widget.transaction.amountMinorUnit,
      currency: currency,
      paymentMethod: widget.transaction.paymentMethod ?? 'Cash',
      purpose: _purposeController.text.trim(),
      notes: _notesController.text.trim(),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Receipt_$_receiptNumber.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print / Save PDF',
            onPressed: () => _printOrShareReceipt(context, currency),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Receipt Card
            Container(
              padding: const EdgeInsets.all(20),
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
                      Text(
                        _businessNameController.text.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.moneyInContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'RECEIPT',
                          style: TextStyle(
                            color: AppColors.moneyIn,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Receipt No: $_receiptNumber', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Date: ${widget.transaction.date}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  const Text('Received With Thanks From:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    widget.partyName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Received:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          CurrencyFormatter.format(widget.transaction.amountMinorUnit, currency),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.moneyIn,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text('Payment Method: ${widget.transaction.paymentMethod ?? "Cash"}',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Purpose: ${_purposeController.text}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(width: 120, child: Divider(thickness: 1.5)),
                        Text('Authorized Signature', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Form Customization
            const Text('Receipt Customization', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _businessNameController,
              decoration: const InputDecoration(labelText: 'Business Name', prefixIcon: Icon(Icons.business)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _purposeController,
              decoration: const InputDecoration(labelText: 'Purpose / Details', prefixIcon: Icon(Icons.description)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Custom Note (optional)', prefixIcon: Icon(Icons.note)),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moneyIn,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print / Share Receipt (PDF)'),
              onPressed: () => _printOrShareReceipt(context, currency),
            ),
          ],
        ),
      ),
    );
  }
}
