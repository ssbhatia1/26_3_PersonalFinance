import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/budget.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';
import '../budget_detail_screen.dart';

class BudgetHistoryTab extends ConsumerStatefulWidget {
  const BudgetHistoryTab({super.key});

  @override
  ConsumerState<BudgetHistoryTab> createState() => _BudgetHistoryTabState();
}

class _BudgetHistoryTabState extends ConsumerState<BudgetHistoryTab> {
  List<Budget> _historyBudgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllHistory();
  }

  Future<void> _loadAllHistory() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref.read(budgetProvider.notifier).getAllBudgetHistory();
      if (mounted) {
        setState(() {
          _historyBudgets = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM yyyy');

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyBudgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 56, color: Colors.grey.withAlpha(120)),
              const SizedBox(height: 12),
              const Text(
                'No budget history available',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Budgets configured across current and prior periods will appear here for long-term tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Historical aggregations
    final totalHistoricalBudget = _historyBudgets.fold(0.0, (s, b) => s + b.amountLimit);
    final totalHistoricalSpent = _historyBudgets.fold(0.0, (s, b) => s + b.spentAmount);
    final netSaved = totalHistoricalBudget - totalHistoricalSpent;
    final stayedWithinCount = _historyBudgets.where((b) => !b.isOverspent).length;
    final exceededCount = _historyBudgets.where((b) => b.isOverspent).length;

    return RefreshIndicator(
      onRefresh: _loadAllHistory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Historical Summary Card
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
                      const Text(
                        'All-Time Budget Performance',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (netSaved >= 0 ? AppColors.income : AppColors.error).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          netSaved >= 0 ? 'Net Savings' : 'Net Deficit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: netSaved >= 0 ? AppColors.income : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _summaryCol('Total Budgeted', totalHistoricalBudget, curr),
                      _summaryCol('Total Spent', totalHistoricalSpent, curr),
                      _summaryCol(
                        netSaved >= 0 ? 'Total Saved' : 'Total Exceeded',
                        netSaved >= 0 ? netSaved : -netSaved,
                        curr,
                        color: netSaved >= 0 ? AppColors.income : AppColors.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: AppColors.income),
                      const SizedBox(width: 6),
                      Text(
                        '$stayedWithinCount periods within budget',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Icon(Icons.warning_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text(
                        '$exceededCount exceeded',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section Title
          const Text(
            'Past & Current Periods',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // List of historical budgets
          ..._historyBudgets.map((b) {
            final isOver = b.isOverspent;
            final variance = b.amountLimit - b.spentAmount;
            final pct = b.percentageUsed;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BudgetDetailScreen(budget: b),
                    ),
                  ).then((_) => _loadAllHistory());
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: (isOver ? AppColors.error : AppColors.primary).withAlpha(25),
                                child: Icon(
                                  b.scope == 'overall' ? Icons.all_inclusive_rounded : Icons.category_rounded,
                                  size: 16,
                                  color: isOver ? AppColors.error : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    dateFormat.format(b.startDate),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isOver ? AppColors.error : AppColors.income).withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOver ? 'Exceeded' : 'Within Budget',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOver ? AppColors.error : AppColors.income,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct > 1.0 ? 1.0 : pct,
                          minHeight: 6,
                          backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          color: isOver ? AppColors.error : (pct > 0.8 ? AppColors.warning : AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget: ${CurrencyFormatter.format(b.amountLimit, symbol: curr)}  •  Spent: ${CurrencyFormatter.format(b.spentAmount, symbol: curr)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            isOver
                                ? 'Over: ${CurrencyFormatter.format(b.spentAmount - b.amountLimit, symbol: curr)}'
                                : 'Saved: ${CurrencyFormatter.format(variance, symbol: curr)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOver ? AppColors.error : AppColors.income,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _summaryCol(String label, double amount, String curr, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.format(amount, symbol: curr),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }
}
