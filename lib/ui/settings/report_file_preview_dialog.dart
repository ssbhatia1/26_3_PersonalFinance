import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo.dart';

class ReportFilePreviewDialog extends StatelessWidget {
  final String title;
  final String formatType; // 'pdf', 'csv', 'json'
  final String? textContent;
  final List<List<String>>? csvRows;
  final Map<String, dynamic>? pdfDataSummary;
  final VoidCallback? onSavePressed;

  const ReportFilePreviewDialog({
    super.key,
    required this.title,
    required this.formatType,
    this.textContent,
    this.csvRows,
    this.pdfDataSummary,
    this.onSavePressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getFormatColor(formatType).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getFormatIcon(formatType),
                      color: _getFormatColor(formatType),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'In-App File & Document Preview (${formatType.toUpperCase()})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Content Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildPreviewBody(isDark),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      if (textContent != null && textContent!.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: textContent!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${formatType.toUpperCase()} content copied to clipboard!',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Content'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      if (onSavePressed != null) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getFormatColor(formatType),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            onSavePressed!();
                          },
                          icon: const Icon(Icons.save_alt_rounded, size: 18),
                          label: Text('Save ${formatType.toUpperCase()} File'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBody(bool isDark) {
    if (formatType == 'pdf' && pdfDataSummary != null) {
      return _buildPdfVisualPreview(isDark);
    } else if (formatType == 'csv' && csvRows != null && csvRows!.isNotEmpty) {
      return _buildCsvTablePreview(isDark);
    } else if (textContent != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          textContent!,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.4,
          ),
        ),
      );
    }
    return const Center(child: Text('No preview content available'));
  }

  Widget _buildPdfVisualPreview(bool isDark) {
    final title = pdfDataSummary!['title'] as String? ?? 'Financial Statement';
    final currency = pdfDataSummary!['currency'] as String? ?? '₹';
    final netWorth = pdfDataSummary!['netWorth'] as double? ?? 0.0;
    final totalAssets = pdfDataSummary!['totalAssets'] as double? ?? 0.0;
    final totalLiabilities = pdfDataSummary!['totalLiabilities'] as double? ?? 0.0;
    final totalIncome = pdfDataSummary!['totalIncome'] as double? ?? 0.0;
    final totalExpense = pdfDataSummary!['totalExpense'] as double? ?? 0.0;
    final txList = (pdfDataSummary!['transactions'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const AppLogo(size: 36, borderRadius: 8),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Offline Financial Performance & Account Statement',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PDF DOCUMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // KPI Summary Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _previewKpiItem('Net Worth', '$currency ${netWorth.toStringAsFixed(2)}', AppColors.primary),
                _previewKpiItem('Total Assets', '$currency ${totalAssets.toStringAsFixed(2)}', AppColors.income),
                _previewKpiItem('Liabilities', '$currency ${totalLiabilities.toStringAsFixed(2)}', AppColors.liability),
                _previewKpiItem('Inflow', '$currency ${totalIncome.toStringAsFixed(2)}', AppColors.income),
                _previewKpiItem('Outflow', '$currency ${totalExpense.toStringAsFixed(2)}', AppColors.expense),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Transactions Table Header
          Text(
            'Transaction Records (${txList.length} Entries)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Transactions Table
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                    children: const [
                      Padding(padding: EdgeInsets.all(8), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    ],
                  ),
                  ...txList.take(50).map((t) {
                    final isExpense = t.type == 'expense';
                    final isIncome = t.type == 'income';
                    final amtColor = isExpense
                        ? AppColors.expense
                        : (isIncome ? AppColors.income : Colors.blue);
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(t.date.toString().split(' ').first, style: const TextStyle(fontSize: 10))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(t.type.toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(t.categoryName ?? '-', style: const TextStyle(fontSize: 10))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('$currency ${t.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: amtColor))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(t.description ?? '-', style: const TextStyle(fontSize: 10))),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewKpiItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCsvTablePreview(bool isDark) {
    final headers = csvRows!.first;
    final rows = csvRows!.skip(1).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
          columns: headers
              .map((h) => DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ))
              .toList(),
          rows: rows.take(100).map((r) {
            return DataRow(
              cells: r.map((c) => DataCell(Text(c, style: const TextStyle(fontSize: 10)))).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getFormatIcon(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'csv':
        return Icons.table_chart_rounded;
      case 'json':
      default:
        return Icons.code_rounded;
    }
  }

  Color _getFormatColor(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'csv':
        return Colors.green;
      case 'json':
      default:
        return Colors.blue;
    }
  }
}
