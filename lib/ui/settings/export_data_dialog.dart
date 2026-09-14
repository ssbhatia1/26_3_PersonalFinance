import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/pdf_exporter.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../../providers/account_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import 'report_file_preview_dialog.dart';

class ExportDataDialog extends ConsumerStatefulWidget {
  final String? initialAccountId;

  const ExportDataDialog({super.key, this.initialAccountId});

  @override
  ConsumerState<ExportDataDialog> createState() => _ExportDataDialogState();
}

class _ExportDataDialogState extends ConsumerState<ExportDataDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filter Options
  String? _selectedAccountId;
  String _selectedPeriodPreset = 'all'; // 'all', 'this_month', 'last_30_days', 'this_year', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  bool _isExporting = false;
  String? _savedFilePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedAccountId = widget.initialAccountId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) _calculateDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriodPreset) {
      case 'this_month':
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59)
        );
      case 'last_30_days':
        return (now.subtract(const Duration(days: 30)), now);
      case 'this_year':
        return (
          DateTime(now.year, 1, 1),
          DateTime(now.year, 12, 31, 23, 59, 59)
        );
      case 'custom':
        return (_customStartDate, _customEndDate);
      case 'all':
      default:
        return (null, null);
    }
  }

  Future<void> _selectCustomDateRange() async {
    final initialRange = DateTimeRange(
      start: _customStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
      end: _customEndDate ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriodPreset = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  // ==========================================
  // PDF EXPORT & PREVIEW LOGIC
  // ==========================================
  Future<void> _exportPdfFile(List<Account> accounts) async {
    setState(() {
      _isExporting = true;
      _savedFilePath = null;
    });

    try {
      final range = _calculateDateRange();
      final curr = ref.read(settingsProvider).currency;
      final txState = ref.read(transactionProvider);
      final allTxs = ref.read(allTransactionsProvider).value ?? txState.transactions;
      final goals = ref.read(goalProvider).value ?? [];

      final filteredTxs = _filterTransactions(allTxs, range.$1, range.$2);
      final accName = (_selectedAccountId != null && accounts.isNotEmpty)
          ? (accounts.any((a) => a.id == _selectedAccountId)
              ? accounts.firstWhere((a) => a.id == _selectedAccountId).name
              : null)
          : null;

      final pdfBytes = await PdfExporter.generateReportPdf(
        accountName: accName,
        startDate: range.$1,
        endDate: range.$2,
        currency: curr,
        accounts: accounts,
        transactions: filteredTxs,
        goals: goals,
        summary: ref.read(accountProvider).netWorthSummary,
      );

      final fileName = accName != null
          ? 'Statement_${accName.replaceAll(' ', '_')}.pdf'
          : 'Financial_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      final path = await PdfExporter.exportPdfToFile(
        pdfBytes: pdfBytes,
        defaultFileName: fileName,
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _savedFilePath = path;
        });

        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF report exported successfully to $path'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _previewPdfReport(List<Account> accounts) async {
    final range = _calculateDateRange();
    final curr = ref.read(settingsProvider).currency;
    final txState = ref.read(transactionProvider);
    final allTxs = ref.read(allTransactionsProvider).value ?? txState.transactions;
    final filteredTxs = _filterTransactions(allTxs, range.$1, range.$2);
    final summary = ref.read(accountProvider).netWorthSummary;

    final accName = (_selectedAccountId != null && accounts.isNotEmpty)
        ? (accounts.any((a) => a.id == _selectedAccountId)
            ? accounts.firstWhere((a) => a.id == _selectedAccountId).name
            : null)
        : null;

    final pdfSummary = {
      'title': accName != null ? 'Account Statement: $accName' : 'Financial Performance Report',
      'currency': curr,
      'netWorth': summary['netWorth'] ?? 0.0,
      'totalAssets': summary['totalAssets'] ?? 0.0,
      'totalLiabilities': summary['totalLiabilities'] ?? 0.0,
      'totalIncome': filteredTxs.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount),
      'totalExpense': filteredTxs.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount),
      'transactions': filteredTxs,
    };

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => ReportFilePreviewDialog(
          title: accName != null ? '$accName PDF Preview' : 'Financial Report PDF Preview',
          formatType: 'pdf',
          pdfDataSummary: pdfSummary,
          onSavePressed: () => _exportPdfFile(accounts),
        ),
      );
    }
  }

  // ==========================================
  // CSV EXPORT & PREVIEW LOGIC
  // ==========================================
  Future<void> _exportCsvFile(List<Account> accounts) async {
    setState(() {
      _isExporting = true;
      _savedFilePath = null;
    });

    final range = _calculateDateRange();
    final accountName = (_selectedAccountId != null && accounts.isNotEmpty)
        ? (accounts.any((a) => a.id == _selectedAccountId)
            ? accounts.firstWhere((a) => a.id == _selectedAccountId).name
            : null)
        : null;

    final path = await ref.read(settingsProvider.notifier).exportTransactionsCsvToFile(
      accountId: _selectedAccountId,
      accountName: accountName,
      startDate: range.$1,
      endDate: range.$2,
    );

    if (mounted) {
      setState(() {
        _isExporting = false;
        _savedFilePath = path;
      });

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported successfully to $path'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _previewCsv() async {
    final range = _calculateDateRange();
    final csvStr = await ref.read(settingsProvider.notifier).exportCsv(
      accountId: _selectedAccountId,
      startDate: range.$1,
      endDate: range.$2,
    );

    final csvTable = csv.decode(csvStr);
    final csvRows = csvTable.map((row) => row.map((e) => e.toString()).toList()).toList();

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => ReportFilePreviewDialog(
          title: 'CSV Spreadsheet Preview',
          formatType: 'csv',
          textContent: csvStr,
          csvRows: csvRows,
          onSavePressed: () => _exportCsvFile(ref.read(accountProvider).accounts),
        ),
      );
    }
  }

  Future<void> _copyCsvToClipboard() async {
    final range = _calculateDateRange();
    final csv = await ref.read(settingsProvider.notifier).exportCsv(
      accountId: _selectedAccountId,
      startDate: range.$1,
      endDate: range.$2,
    );

    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV content copied to clipboard!')),
      );
    }
  }

  // ==========================================
  // JSON BACKUP & PREVIEW LOGIC
  // ==========================================
  Future<void> _exportJsonBackup() async {
    setState(() {
      _isExporting = true;
      _savedFilePath = null;
    });

    final path = await ref.read(settingsProvider.notifier).exportFullBackupToFile();

    if (mounted) {
      setState(() {
        _isExporting = false;
        _savedFilePath = path;
      });

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Full backup saved to $path'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _previewJson() async {
    final rawJson = await ref.read(settingsProvider.notifier).getFullBackupJsonString();
    String prettyJson = rawJson;
    try {
      final parsed = jsonDecode(rawJson);
      prettyJson = const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => ReportFilePreviewDialog(
          title: 'Full Backup JSON Preview',
          formatType: 'json',
          textContent: prettyJson,
          onSavePressed: _exportJsonBackup,
        ),
      );
    }
  }

  Future<void> _copyJsonToClipboard() async {
    final jsonStr = await ref.read(settingsProvider.notifier).getFullBackupJsonString();
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full backup JSON copied to clipboard!')),
      );
    }
  }

  List<TransactionModel> _filterTransactions(
    List<TransactionModel> txs,
    DateTime? start,
    DateTime? end,
  ) {
    return txs.where((t) {
      if (_selectedAccountId != null &&
          t.sourceAccountId != _selectedAccountId &&
          t.destinationAccountId != _selectedAccountId) {
        return false;
      }
      if (start != null && t.date.isBefore(start)) return false;
      if (end != null && t.date.isAfter(end)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Row(
                children: [
                  const AppLogo(
                    size: 40,
                    borderRadius: 10,
                    showShadow: true,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Financial Reports & Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Export & preview offline records in PDF, CSV, or JSON format',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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

              // Export Type Tabs
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.picture_as_pdf_rounded), text: 'PDF Report'),
                  Tab(icon: Icon(Icons.table_chart_rounded), text: 'CSV Table'),
                  Tab(icon: Icon(Icons.code_rounded), text: 'JSON Backup'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Contents
              Flexible(
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: 400,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPdfExportTab(accounts, isDark),
                        _buildCsvExportTab(accounts, isDark),
                        _buildJsonBackupTab(accounts, isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: PDF REPORT EXPORT
  // ==========================================
  Widget _buildPdfExportTab(List<Account> accounts, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAccountAndFilterControls(accounts),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withAlpha(60)),
          ),
          child: const Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Generates a formatted PDF statement with branded header, KPI net worth cards, account breakdown, and detailed transaction ledger.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        if (_savedFilePath != null) ...[
          const SizedBox(height: 12),
          _buildSavedFileCard(),
        ],

        const Spacer(),

        // Action Buttons Row
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isExporting ? null : () => _previewPdfReport(accounts),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Preview PDF Report'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: _isExporting ? null : () => _exportPdfFile(accounts),
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text(_isExporting ? 'Generating PDF...' : 'Save PDF File...'),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: CSV TRANSACTIONS EXPORT
  // ==========================================
  Widget _buildCsvExportTab(List<Account> accounts, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAccountAndFilterControls(accounts),
        const SizedBox(height: 16),

        if (_savedFilePath != null) ...[
          _buildSavedFileCard(),
          const SizedBox(height: 12),
        ],

        const Spacer(),

        // Action Buttons Row
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _previewCsv,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Preview CSV Table'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _copyCsvToClipboard,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy CSV'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: _isExporting ? null : () => _exportCsvFile(accounts),
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_alt_rounded, size: 18),
              label: Text(_isExporting ? 'Exporting...' : 'Save CSV File...'),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: FULL SYSTEM JSON BACKUP
  // ==========================================
  Widget _buildJsonBackupTab(List<Account> accounts, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.info.withAlpha(60)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A complete JSON backup archives your full database: accounts, transactions, categories, budgets, recurring rules, loans, and goals.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Entities Summary
        const Text('Included in this backup archive:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _backupTag('Accounts', '${accounts.length}', Icons.account_balance_rounded),
            _backupTag('Transactions', 'Ledger', Icons.receipt_long_rounded),
            _backupTag('Budgets', 'Active', Icons.pie_chart_rounded),
            _backupTag('Recurring', 'Schedules', Icons.schedule_rounded),
            _backupTag('Loans', 'Debts', Icons.handshake_rounded),
            _backupTag('Goals', 'Targets', Icons.flag_rounded),
          ],
        ),
        const SizedBox(height: 16),

        if (_savedFilePath != null) ...[
          _buildSavedFileCard(),
          const SizedBox(height: 12),
        ],

        const Spacer(),

        // Action Buttons Row
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _previewJson,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Preview JSON'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _copyJsonToClipboard,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy JSON'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: _isExporting ? null : _exportJsonBackup,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.backup_rounded, size: 18),
              label: Text(_isExporting ? 'Saving Backup...' : 'Save Full Backup (.json)...'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountAndFilterControls(List<Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account Selector
        DropdownButtonFormField<String>(
          value: _selectedAccountId,
          decoration: const InputDecoration(
            labelText: 'Filter by Account',
            isDense: true,
            prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Accounts (Complete Ledger)')),
            ...accounts.map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} (${a.type})'),
                )),
          ],
          onChanged: (val) => setState(() => _selectedAccountId = val),
        ),
        const SizedBox(height: 14),

        // Date Range Presets
        DropdownButtonFormField<String>(
          value: _selectedPeriodPreset,
          decoration: const InputDecoration(
            labelText: 'Timeframe',
            isDense: true,
            prefixIcon: Icon(Icons.calendar_month_outlined, size: 20),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Time (Entire History)')),
            DropdownMenuItem(value: 'this_month', child: Text('This Month')),
            DropdownMenuItem(value: 'last_30_days', child: Text('Last 30 Days')),
            DropdownMenuItem(value: 'this_year', child: Text('This Year')),
            DropdownMenuItem(value: 'custom', child: Text('Custom Date Range...')),
          ],
          onChanged: (val) {
            if (val == 'custom') {
              _selectCustomDateRange();
            } else {
              setState(() => _selectedPeriodPreset = val ?? 'all');
            }
          },
        ),

        if (_selectedPeriodPreset == 'custom' &&
            _customStartDate != null &&
            _customEndDate != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event_available_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Range: ${DateFormat('dd MMM yyyy').format(_customStartDate!)} — ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const Spacer(),
              TextButton(
                onPressed: _selectCustomDateRange,
                child: const Text('Change', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSavedFileCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('File Saved Successfully',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success)),
                Text(
                  _savedFilePath!,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy File Path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _savedFilePath!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File path copied!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _backupTag(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
