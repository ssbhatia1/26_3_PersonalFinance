import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/account.dart';
import '../../data/models/financial_goal.dart';
import '../../data/models/transaction.dart';

class PdfExporter {
  static Future<Uint8List> generateReportPdf({
    String? accountName,
    DateTime? startDate,
    DateTime? endDate,
    required String currency,
    required List<Account> accounts,
    required List<TransactionModel> transactions,
    List<FinancialGoal> goals = const [],
    Map<String, double> summary = const {},
  }) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('dd MMM yyyy');
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // Calculate Summary Metrics
    final double totalAssets = summary['totalAssets'] ??
        accounts
            .where((a) => a.isAsset)
            .fold(0.0, (s, a) => s + (a.currentBalance ?? 0.0));
    final double totalLiabilities = summary['totalLiabilities'] ??
        accounts
            .where((a) => a.isLiability)
            .fold(0.0, (s, a) => s + (a.currentBalance?.abs() ?? 0.0));
    final double netWorth = summary['netWorth'] ?? (totalAssets - totalLiabilities);

    final totalIncome = transactions
        .where((t) => t.isIncome)
        .fold(0.0, (s, t) => s + t.amount);
    final totalExpense = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (s, t) => s + t.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.teal, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PERSONAL FINANCE',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                    pw.Text(
                      accountName != null
                          ? 'Account Statement: $accountName'
                          : 'Financial Performance & Ledger Report',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: $nowStr',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                    if (startDate != null && endDate != null)
                      pw.Text(
                        'Period: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '100% Private Offline Financial Statement',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // KPI Summary Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpi(
                    'Net Worth',
                    '$currency ${netWorth.toStringAsFixed(2)}',
                    PdfColors.teal700,
                  ),
                  _buildPdfKpi(
                    'Total Assets',
                    '$currency ${(totalAssets ?? 0.0).toStringAsFixed(2)}',
                    PdfColors.green700,
                  ),
                  _buildPdfKpi(
                    'Liabilities',
                    '$currency ${(totalLiabilities ?? 0.0).toStringAsFixed(2)}',
                    PdfColors.orange800,
                  ),
                  _buildPdfKpi(
                    'Total Inflow',
                    '$currency ${totalIncome.toStringAsFixed(2)}',
                    PdfColors.green700,
                  ),
                  _buildPdfKpi(
                    'Total Outflow',
                    '$currency ${totalExpense.toStringAsFixed(2)}',
                    PdfColors.red700,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Accounts Overview Table
            if (accountName == null && accounts.isNotEmpty) ...[
              pw.Text(
                'Accounts & Portfolios Overview',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                headers: ['Account Name', 'Type', 'Institution', 'Current Balance'],
                data: accounts.map((a) {
                  return [
                    a.name,
                    a.type,
                    a.institution ?? '-',
                    '$currency ${a.currentBalance.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // Financial Goals (if any)
            if (goals.isNotEmpty) ...[
              pw.Text(
                'Financial Goals & Targets',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                headers: ['Goal Name', 'Target Amount', 'Current Saved', 'Target Date', 'Status'],
                data: goals.map((g) {
                  final pct = (g.progressPercentage * 100).toStringAsFixed(0);
                  return [
                    g.name,
                    '$currency ${g.targetAmount.toStringAsFixed(2)}',
                    '$currency ${g.currentAmount.toStringAsFixed(2)} ($pct%)',
                    dateFormat.format(g.targetDate),
                    g.isCompleted ? 'Completed' : 'In Progress',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // Transactions Table
            pw.Text(
              'Detailed Transaction History (${transactions.length} Records)',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal900,
              ),
            ),
            pw.SizedBox(height: 6),
            if (transactions.isEmpty)
              pw.Text(
                'No transaction records found for the selected filter.',
                style: const pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              )
            else
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                headers: ['Date', 'Type', 'Category / Payee', 'Amount', 'Description'],
                data: transactions.take(300).map((t) {
                  final typeStr = t.type.toUpperCase();
                  final payee = t.payeePayer ?? t.categoryName ?? '-';
                  final amountPrefix = t.isExpense
                      ? '-'
                      : (t.isIncome ? '+' : '');
                  return [
                    dateFormat.format(t.date),
                    typeStr,
                    payee,
                    '$amountPrefix$currency ${t.amount.toStringAsFixed(2)}',
                    t.description ?? '-',
                  ];
                }).toList(),
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfKpi(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static Future<String?> exportPdfToFile({
    required Uint8List pdfBytes,
    required String defaultFileName,
  }) async {
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save PDF Report',
        fileName: defaultFileName,
        bytes: pdfBytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (uri != null) {
        final path = uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
        final file = File(path);
        if (!await file.exists()) {
          await file.writeAsBytes(pdfBytes);
        }
        return path;
      }
    } catch (e) {
      // Fallback
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final outputFile = '${docDir.path}/$defaultFileName';
      final file = File(outputFile);
      await file.writeAsBytes(pdfBytes);
      return outputFile;
    } catch (_) {
      return null;
    }
  }
}
