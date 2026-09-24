import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import '../database/app_database.dart';
import '../database/tables.dart';
import '../models/book_model.dart';
import '../models/transaction_model.dart';

class BackupRepository {
  final AppDatabase _dbProvider = AppDatabase.instance;

  /// Export complete database as structured JSON
  Future<String> exportCompleteJsonBackup() async {
    final db = await _dbProvider.database;
    final books = await db.query(Tables.books);
    final accounts = await db.query(Tables.accounts);
    final categories = await db.query(Tables.categories);
    final parties = await db.query(Tables.parties);
    final transactions = await db.query(Tables.transactions);
    final auditLogs = await db.query(Tables.auditLogs);

    final data = {
      'app': 'Hissab',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'tables': {
        'books': books,
        'accounts': accounts,
        'categories': categories,
        'parties': parties,
        'transactions': transactions,
        'audit_logs': auditLogs,
      }
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Restore complete database from JSON backup with atomic rollback safety
  Future<bool> restoreCompleteJsonBackup(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      if (decoded['app'] != 'Hissab' || !decoded.containsKey('tables')) {
        return false;
      }

      final tables = decoded['tables'] as Map<String, dynamic>;
      final db = await _dbProvider.database;

      await db.transaction((txn) async {
        // Clear existing tables
        await txn.delete(Tables.transactions);
        await txn.delete(Tables.categories);
        await txn.delete(Tables.parties);
        await txn.delete(Tables.accounts);
        await txn.delete(Tables.auditLogs);
        await txn.delete(Tables.books);

        // Insert restored records
        for (final item in (tables['books'] as List? ?? [])) {
          await txn.insert(Tables.books, Map<String, dynamic>.from(item));
        }
        for (final item in (tables['accounts'] as List? ?? [])) {
          await txn.insert(Tables.accounts, Map<String, dynamic>.from(item));
        }
        for (final item in (tables['categories'] as List? ?? [])) {
          await txn.insert(Tables.categories, Map<String, dynamic>.from(item));
        }
        for (final item in (tables['parties'] as List? ?? [])) {
          await txn.insert(Tables.parties, Map<String, dynamic>.from(item));
        }
        for (final item in (tables['transactions'] as List? ?? [])) {
          await txn.insert(Tables.transactions, Map<String, dynamic>.from(item));
        }
        for (final item in (tables['audit_logs'] as List? ?? [])) {
          await txn.insert(Tables.auditLogs, Map<String, dynamic>.from(item));
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generates CSV format for Excel/Sheets with accurate running balance
  String exportCsvData({
    required BookModel book,
    required List<TransactionModel> transactions,
    required CurrencyConfig currency,
  }) {
    final rows = <List<dynamic>>[];

    // CSV Header
    rows.add([
      'Date',
      'Time',
      'Transaction ID',
      'Type',
      'Description',
      'Payment Method',
      'Reference',
      'Money In (${currency.code})',
      'Money Out (${currency.code})',
      'Balance (${currency.code})',
    ]);

    // Initial Opening Balance row
    int runningBalance = book.openingBalanceMinor;
    rows.add([
      book.openingBalanceDate,
      '00:00',
      'OPENING_BALANCE',
      'OPENING_BALANCE',
      'Opening Balance',
      'Initial',
      '-',
      DecimalCalculator.formatDecimal(book.openingBalanceMinor, currency),
      '0.00',
      DecimalCalculator.formatDecimal(runningBalance, currency),
    ]);

    // Chronological order for running balance calculation
    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final tx in sorted) {
      if (tx.isDeleted) continue;

      String moneyInStr = '0.00';
      String moneyOutStr = '0.00';

      if (tx.type.isMoneyIn) {
        moneyInStr = DecimalCalculator.formatDecimal(tx.amountMinorUnit, currency);
        runningBalance += tx.amountMinorUnit;
      } else if (tx.type.isMoneyOut) {
        moneyOutStr = DecimalCalculator.formatDecimal(tx.amountMinorUnit, currency);
        runningBalance -= tx.amountMinorUnit;
      }

      rows.add([
        tx.date,
        tx.time,
        tx.id,
        tx.type.toDbString(),
        tx.description ?? '',
        tx.paymentMethod ?? 'Cash',
        tx.referenceNumber ?? '',
        moneyInStr,
        moneyOutStr,
        DecimalCalculator.formatDecimal(runningBalance, currency),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate professional PDF report of the Book statement
  Future<Uint8List> generatePdfReport({
    required BookModel book,
    required List<TransactionModel> transactions,
    required CurrencyConfig currency,
    required String dateRangeLabel,
  }) async {
    final pdf = pw.Document();

    int totalIn = 0;
    int totalOut = 0;
    for (final tx in transactions) {
      if (tx.isDeleted) continue;
      if (tx.type.isMoneyIn) totalIn += tx.amountMinorUnit;
      if (tx.type.isMoneyOut) totalOut += tx.amountMinorUnit;
    }
    final netCashFlow = totalIn - totalOut;
    final closingBalance = book.openingBalanceMinor + netCashFlow;

    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('HISSAB CASHBOOK',
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text('Book: ${book.name}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Currency: ${book.currency} | Generated: ${DateTime.now().toString().substring(0, 16)}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Period: $dateRangeLabel',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Closing Balance:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      CurrencyFormatter.format(closingBalance, currency),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: closingBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 12),

          // Summary Cards
          pw.Row(
            children: [
              _buildPdfStatBox('Opening Balance', CurrencyFormatter.format(book.openingBalanceMinor, currency), PdfColors.grey800),
              pw.SizedBox(width: 8),
              _buildPdfStatBox('Total In', CurrencyFormatter.format(totalIn, currency), PdfColors.green800),
              pw.SizedBox(width: 8),
              _buildPdfStatBox('Total Out', CurrencyFormatter.format(totalOut, currency), PdfColors.red800),
              pw.SizedBox(width: 8),
              _buildPdfStatBox('Net Flow', CurrencyFormatter.format(netCashFlow, currency), netCashFlow >= 0 ? PdfColors.green800 : PdfColors.red800),
            ],
          ),
          pw.SizedBox(height: 16),

          // Transactions Table
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Description', 'Method', 'In (+)', 'Out (-)'],
            data: sorted.map((tx) {
              final inStr = tx.type.isMoneyIn ? DecimalCalculator.formatDecimal(tx.amountMinorUnit, currency) : '-';
              final outStr = tx.type.isMoneyOut ? DecimalCalculator.formatDecimal(tx.amountMinorUnit, currency) : '-';
              return [
                tx.date,
                tx.description?.isNotEmpty == true ? tx.description! : tx.type.toDbString(),
                tx.paymentMethod ?? 'Cash',
                inStr,
                outStr,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Hissab Accounting Engine - Deterministic & Offline-First',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfStatBox(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  /// Generate professional Printable Receipt PDF
  Future<Uint8List> generateReceiptPdf({
    required String businessName,
    required String receiptNumber,
    required String date,
    required String receivedFrom,
    required int amountMinorUnit,
    required CurrencyConfig currency,
    required String paymentMethod,
    String? purpose,
    String? notes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(businessName.toUpperCase(),
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('PAYMENT RECEIPT',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Receipt No: $receiptNumber', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              pw.Text('Received With Thanks From:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text(receivedFrom, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Amount Received:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      CurrencyFormatter.format(amountMinorUnit, currency),
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              if (purpose != null && purpose.isNotEmpty) ...[
                pw.Text('Purpose / Towards: $purpose', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 6),
              ],
              pw.Text('Payment Method: $paymentMethod', style: const pw.TextStyle(fontSize: 10)),
              if (notes != null && notes.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text('Notes: $notes', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey500),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }
}
