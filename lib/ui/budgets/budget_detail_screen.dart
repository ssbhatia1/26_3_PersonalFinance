import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/budget.dart';
import '../../data/models/transaction.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import 'budget_form_dialog.dart';

class BudgetDetailScreen extends ConsumerStatefulWidget {
  final Budget budget;

  const BudgetDetailScreen({super.key, required this.budget});

  @override
  ConsumerState<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<BudgetDetailScreen> {
  late Budget _currentBudget;
  List<TransactionModel> _relatedExpenses = [];
  List<Budget> _budgetHistory = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _currentBudget = widget.budget;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoadingData = true);
    try {
      final notifier = ref.read(budgetProvider.notifier);
      final expenses = await notifier.getTransactionsForBudget(_currentBudget);
      final history = await notifier.getBudgetHistory(_currentBudget);

      // Also refresh current budget instance from latest state if available
      final stateBudgets = ref.read(budgetProvider).budgets;
      final matching = stateBudgets.where((b) => b.id == _currentBudget.id);
      if (matching.isNotEmpty) {
        _currentBudget = matching.first;
      }

      if (mounted) {
        setState(() {
          _relatedExpenses = expenses;
          _budgetHistory = history;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Color _getStatusColor(BudgetAlertLevel alertLevel) {
    switch (alertLevel) {
      case BudgetAlertLevel.overBudget100:
        return AppColors.error;
      case BudgetAlertLevel.critical90:
        return AppColors.warning;
      case BudgetAlertLevel.nearLimit75:
        return AppColors.warning;
      case BudgetAlertLevel.normal:
        return AppColors.primary;
    }
  }

  void _openEditDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => BudgetFormDialog(budgetToEdit: _currentBudget),
    );
    if (updated == true) {
      await _loadDetails();
    }
  }

  void _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: Text(
          'Are you sure you want to delete "${_currentBudget.displayName}"? Previous transactions in your ledger will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(budgetProvider.notifier).deleteBudget(_currentBudget.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _currentBudget;
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pct = b.percentageUsed;
    final isOver = b.isOverspent;
    final statusColor = _getStatusColor(b.alertLevel);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(b.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Budget',
            onPressed: _openEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Delete Budget',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Alert Banner (Feature 7: Budget Alerts)
            if (b.alertLevel != BudgetAlertLevel.normal) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withAlpha(90)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOver ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                      color: statusColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOver ? 'Over Budget Alert' : 'Budget Spending Alert',
                            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.alertMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[300] : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Top Summary Card with KPIs
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: statusColor.withAlpha(30),
                              child: Icon(
                                b.scope == 'overall' ? Icons.all_inclusive_rounded : Icons.category_rounded,
                                color: statusColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                ),
                                if (b.categoryName != null && b.name != null)
                                  Text(
                                    b.categoryName!,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withAlpha(90)),
                          ),
                          child: Text(
                            b.statusLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Progress Bar with Milestone Markers
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Budget Utilization',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(1)}%',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct > 1.0 ? 1.0 : pct,
                            minHeight: 10,
                            backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Threshold Markers (75%, 90%, 100%)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('0%', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(
                              '75% Limit',
                              style: TextStyle(
                                fontSize: 10,
                                color: pct >= 0.75 ? AppColors.warning : Colors.grey,
                                fontWeight: pct >= 0.75 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '90% Critical',
                              style: TextStyle(
                                fontSize: 10,
                                color: pct >= 0.90 ? AppColors.liability : Colors.grey,
                                fontWeight: pct >= 0.90 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '100% Max',
                              style: TextStyle(
                                fontSize: 10,
                                color: pct >= 1.0 ? AppColors.error : Colors.grey,
                                fontWeight: pct >= 1.0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // 4 KPI Columns
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _kpiItem('Budget Limit', CurrencyFormatter.format(b.amountLimit, symbol: curr)),
                        _kpiItem('Total Spent', CurrencyFormatter.format(b.spentAmount, symbol: curr), color: statusColor),
                        _kpiItem(
                          isOver ? 'Overspent' : 'Remaining',
                          CurrencyFormatter.format(isOver ? (b.spentAmount - b.amountLimit) : b.remainingAmount, symbol: curr),
                          color: isOver ? AppColors.error : AppColors.income,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Staying Duration & Timeline Card (How Many Days Budget Will Stay)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.hourglass_bottom_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Budget Staying Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (b.isLongTerm ? AppColors.transfer : AppColors.primary).withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            b.isLongTerm ? 'Long-Term' : '${b.totalDurationDays} Days Total',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: b.isLongTerm ? AppColors.transfer : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _infoRow(
                      Icons.timer_outlined,
                      'Days Remaining',
                      b.remainingDaysLabel,
                      valueColor: b.daysRemaining <= 3 && b.daysRemaining >= 0
                          ? AppColors.warning
                          : (b.daysRemaining < 0 ? Colors.grey : AppColors.primary),
                    ),
                    const Divider(height: 16),
                    _infoRow(
                      Icons.date_range_rounded,
                      'Period Range',
                      '${dateFormat.format(b.startDate)} - ${dateFormat.format(b.endDate)} (${b.totalDurationDays} days)',
                    ),
                    if (b.dailyAllowance > 0) ...[
                      const Divider(height: 16),
                      _infoRow(
                        Icons.speed_rounded,
                        'Safe Spending Pace',
                        '${CurrencyFormatter.format(b.dailyAllowance, symbol: curr)} / day remaining',
                        valueColor: AppColors.income,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Period & Configuration Info
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Budget Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    _infoRow(Icons.calendar_today_rounded, 'Period Frequency', b.periodType.toUpperCase()),
                    const Divider(height: 16),
                    _infoRow(Icons.date_range_rounded, 'Date Range', '${dateFormat.format(b.startDate)} - ${dateFormat.format(b.endDate)}'),
                    const Divider(height: 16),
                    _infoRow(Icons.category_rounded, 'Scope', b.scope == 'overall' ? 'Overall (All Expenses)' : (b.categoryName ?? 'Category')),
                    const Divider(height: 16),
                    _infoRow(Icons.repeat_rounded, 'Auto-Renew Recurring', b.isRecurring ? 'Enabled (Auto-creates next period)' : 'Disabled'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Feature 6: Related Expenses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Related Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${_relatedExpenses.length} transactions',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoadingData)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_relatedExpenses.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No expenses recorded in this period', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._relatedExpenses.map((tx) => _buildTransactionTile(tx, curr)),

            const SizedBox(height: 20),

            // Feature 8: Budget History for this Category
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Historical Periods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${_budgetHistory.length} recorded',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_budgetHistory.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('No previous period history available yet.', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              ..._budgetHistory.map((hb) => _buildHistoryCard(hb, curr)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _kpiItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(TransactionModel tx, String curr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.expense.withAlpha(25),
          child: const Icon(Icons.arrow_upward_rounded, color: AppColors.expense, size: 18),
        ),
        title: Text(
          tx.payeePayer ?? tx.description ?? 'Expense',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${DateFormatter.formatShortDate(tx.date)} • ${tx.sourceAccountName ?? "Account"}',
          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        trailing: Text(
          '-${CurrencyFormatter.format(tx.amount, symbol: curr)}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Budget hb, String curr) {
    final isOver = hb.isOverspent;
    final saved = hb.amountLimit - hb.spentAmount;
    final dateFormat = DateFormat('MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(hb.startDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Budget: ${CurrencyFormatter.format(hb.amountLimit, symbol: curr)}  •  Spent: ${CurrencyFormatter.format(hb.spentAmount, symbol: curr)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isOver ? AppColors.error : AppColors.income).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isOver
                    ? 'Over: ${CurrencyFormatter.format(hb.spentAmount - hb.amountLimit, symbol: curr)}'
                    : 'Saved: ${CurrencyFormatter.format(saved, symbol: curr)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isOver ? AppColors.error : AppColors.income,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
