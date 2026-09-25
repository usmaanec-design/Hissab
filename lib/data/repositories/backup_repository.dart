import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:hissab/core/constants/app_assets.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/core/services/pdf_font_service.dart';
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
    final theme = await PdfFontService.instance.getPdfTheme();
    final pdf = pw.Document(theme: theme);

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

    final isBookNameRtl = PdfFontService.isRtlText(book.name);

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load(AppAssets.logo);
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      try {
        final logoBytes = await rootBundle.load(AppAssets.logoAlias);
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 44,
                      height: 44,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.ClipRRect(
                        horizontalRadius: 8,
                        verticalRadius: 8,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('HISSAB CASHBOOK',
                          style: pw.TextStyle(
                              fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Directionality(
                        textDirection: isBookNameRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                        child: pw.Text('Book: ${book.name}',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Text('Currency: ${book.currency} | Generated: ${DateTime.now().toString().substring(0, 16)}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
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
                    pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      child: pw.Text(
                        CurrencyFormatter.format(closingBalance, currency),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: closingBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
                        ),
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

          // Summary Cards (Overflow-safe with FittedBox)
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

          // Transactions Table with full Unicode & RTL Directionality support
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(65),
              1: const pw.FlexColumnWidth(3.2),
              2: const pw.FixedColumnWidth(65),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(1.6),
            },
            children: [
              // Table Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _buildPdfTableCell('Date', isHeader: true),
                  _buildPdfTableCell('Description', isHeader: true),
                  _buildPdfTableCell('Method', isHeader: true),
                  _buildPdfTableCell('In (+)', isHeader: true, align: pw.TextAlign.right),
                  _buildPdfTableCell('Out (-)', isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              // Table Data
              ...sorted.map((tx) {
                final desc = tx.description?.isNotEmpty == true ? tx.description! : tx.type.toDbString();
                final isDescRtl = PdfFontService.isRtlText(desc);
                final inStr = tx.type.isMoneyIn ? DecimalCalculator.formatDecimal(tx.amountMinorUnit, currency) : '-';
                final outStr = tx.type.isMoneyOut ? DecimalCalculator.formatDecimal(tx.amountMinorUnit, currency) : '-';

                return pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                  ),
                  children: [
                    _buildPdfTableCell(tx.date),
                    _buildPdfTableCell(desc, isRtl: isDescRtl),
                    _buildPdfTableCell(tx.paymentMethod ?? 'Cash'),
                    _buildPdfTableCell(inStr, align: pw.TextAlign.right, color: tx.type.isMoneyIn ? PdfColors.green800 : PdfColors.grey800),
                    _buildPdfTableCell(outStr, align: pw.TextAlign.right, color: tx.type.isMoneyOut ? PdfColors.red800 : PdfColors.grey800),
                  ],
                );
              }),
            ],
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

  pw.Widget _buildPdfTableCell(
    String text, {
    bool isHeader = false,
    bool isRtl = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    final style = pw.TextStyle(
      fontSize: isHeader ? 9.5 : 8.5,
      fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Directionality(
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        child: pw.Text(
          text,
          style: style,
          textAlign: isRtl ? pw.TextAlign.right : align,
        ),
      ),
    );
  }

  pw.Widget _buildPdfStatBox(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600), maxLines: 1),
            pw.SizedBox(height: 3),
            pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate professional Printable Receipt PDF with full Unicode & RTL support
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
    final theme = await PdfFontService.instance.getPdfTheme();
    final pdf = pw.Document(theme: theme);

    final isBizRtl = PdfFontService.isRtlText(businessName);
    final isReceivedRtl = PdfFontService.isRtlText(receivedFrom);
    final isPurposeRtl = purpose != null && PdfFontService.isRtlText(purpose);
    final isNotesRtl = notes != null && PdfFontService.isRtlText(notes);

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load(AppAssets.logo);
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      try {
        final logoBytes = await rootBundle.load(AppAssets.logoAlias);
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {}
    }

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
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 32,
                          height: 32,
                          margin: const pw.EdgeInsets.only(right: 8),
                          child: pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        ),
                      pw.Directionality(
                        textDirection: isBizRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                        child: pw.Text(
                          businessName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 8),
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
              pw.Directionality(
                textDirection: isReceivedRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                child: pw.Text(
                  receivedFrom,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  textAlign: isReceivedRtl ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              ),
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
                    pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      child: pw.Text(
                        CurrencyFormatter.format(amountMinorUnit, currency),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              if (purpose != null && purpose.isNotEmpty) ...[
                pw.Directionality(
                  textDirection: isPurposeRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  child: pw.Text('Purpose / Towards: $purpose',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: isPurposeRtl ? pw.TextAlign.right : pw.TextAlign.left),
                ),
                pw.SizedBox(height: 6),
              ],
              pw.Text('Payment Method: $paymentMethod', style: const pw.TextStyle(fontSize: 10)),
              if (notes != null && notes.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Directionality(
                  textDirection: isNotesRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  child: pw.Text('Notes: $notes',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      textAlign: isNotesRtl ? pw.TextAlign.right : pw.TextAlign.left),
                ),
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
