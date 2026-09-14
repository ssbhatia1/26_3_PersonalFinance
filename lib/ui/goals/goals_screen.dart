import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/tracer_chart.dart';
import '../../data/models/financial_goal.dart';
import '../../providers/account_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import 'goal_form_dialog.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  void _openAdd(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const GoalFormDialog(),
    );
  }

  void _openContribute(BuildContext context, WidgetRef ref, FinancialGoal goal) {
    final controller = TextEditingController();
    final accounts = ref.read(accountProvider).accounts;
    final curr = ref.read(settingsProvider).currency;

    String? selectedAccountId;
    if (goal.linkedAccountId != null && accounts.any((a) => a.id == goal.linkedAccountId)) {
      selectedAccountId = goal.linkedAccountId;
    } else if (accounts.isNotEmpty) {
      selectedAccountId = accounts.first.id;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isInterAccountTransfer = goal.linkedAccountId != null &&
              goal.linkedAccountId!.isNotEmpty &&
              selectedAccountId != null &&
              goal.linkedAccountId != selectedAccountId;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.savings_rounded, color: AppColors.income),
                const SizedBox(width: 8),
                Expanded(child: Text('Contribute to ${goal.name}')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select account to pay from:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: accounts.map((a) {
                      return DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.name} (${CurrencyFormatter.format(a.currentBalance, symbol: curr)})',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setModalState(() => selectedAccountId = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Contribution Amount *',
                      prefixText: '$curr ',
                      hintText: '0.00',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isInterAccountTransfer
                                ? 'Will transfer funds from selected account into goal\'s account.'
                                : 'Will debit selected account and record as goal savings expense.',
                            style: const TextStyle(fontSize: 11, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(controller.text.trim()) ?? 0.0;
                  if (val > 0 && selectedAccountId != null) {
                    ref.read(goalProvider.notifier).contribute(
                          goal.id,
                          val,
                          fundingAccountId: selectedAccountId,
                          goalAccountId: goal.linkedAccountId,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Contributed ${CurrencyFormatter.format(val, symbol: curr)} to ${goal.name}!'),
                        backgroundColor: AppColors.income,
                      ),
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Confirm & Debit'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openWithdraw(BuildContext context, WidgetRef ref, FinancialGoal goal) {
    final controller = TextEditingController();
    final accounts = ref.read(accountProvider).accounts;
    final curr = ref.read(settingsProvider).currency;

    String? selectedAccountId;
    if (goal.linkedAccountId != null && accounts.any((a) => a.id == goal.linkedAccountId)) {
      selectedAccountId = goal.linkedAccountId;
    } else if (accounts.isNotEmpty) {
      selectedAccountId = accounts.first.id;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.outbox_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text('Withdraw from ${goal.name}')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available in Goal: ${CurrencyFormatter.format(goal.currentAmount, symbol: curr)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select account to receive funds (Optional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: selectedAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None (Just decrease Goal balance)')),
                      ...accounts.map((a) {
                        return DropdownMenuItem<String?>(
                          value: a.id,
                          child: Text(
                            '${a.name} (${CurrencyFormatter.format(a.currentBalance, symbol: curr)})',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      setModalState(() => selectedAccountId = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Withdrawal Amount *',
                      prefixText: '$curr ',
                      hintText: '0.00',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: () {
                  final val = double.tryParse(controller.text.trim()) ?? 0.0;
                  if (val > 0) {
                    ref.read(goalProvider.notifier).withdraw(
                          goal.id,
                          val,
                          receivingAccountId: selectedAccountId,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Withdrew ${CurrencyFormatter.format(val, symbol: curr)} from ${goal.name}!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Confirm & Withdraw'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalProvider);
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Goals & Targets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Goal',
            onPressed: () => _openAdd(context),
          ),
        ],
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_circle_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No financial goals yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Track milestones like Emergency Fund, Vacation, or Down Payment.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openAdd(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Your First Goal'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildGoalTracerGraph(goals, curr),
              const SizedBox(height: 16),
              ...goals.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildGoalCard(context, ref, g, curr),
                  )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildGoalTracerGraph(List<FinancialGoal> goals, String curr) {
    final totalSaved = goals.fold(0.0, (s, g) => s + g.currentAmount);
    final totalTarget = goals.fold(0.0, (s, g) => s + g.targetAmount);

    final months = ['M-5', 'M-4', 'M-3', 'M-2', 'M-1', 'Now'];
    final spots = <FlSpot>[];

    for (int i = 0; i < 6; i++) {
      final ratio = (i + 1) / 6.0;
      final val = totalSaved * ratio;
      spots.add(FlSpot(i.toDouble(), max(0.0, val)));
    }

    return TracerLineChart(
      spots: spots,
      xLabels: months,
      currency: curr,
      lineColor: AppColors.goal,
      title: 'Goals Accumulation & Target Velocity (Tracer Graph)',
      subtitle: 'Interactive crosshairs track target savings progression (${CurrencyFormatter.formatCompact(totalSaved, symbol: curr)} / ${CurrencyFormatter.formatCompact(totalTarget, symbol: curr)})',
      height: 220,
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, FinancialGoal g, String curr) {
    final pct = g.progressPercentage;
    final isComplete = g.isCompleted || pct >= 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      backgroundColor: isComplete ? AppColors.primary.withAlpha(40) : AppColors.goal.withAlpha(30),
                      child: Icon(
                        isComplete ? Icons.check_circle_rounded : Icons.flag_rounded,
                        color: isComplete ? AppColors.primary : AppColors.goal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          'Target Date: ${DateFormatter.formatFullDate(g.targetDate)} (${g.daysRemaining} days left)',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  onPressed: () => ref.read(goalProvider.notifier).deleteGoal(g.id),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: AppColors.darkBorder,
                color: isComplete ? AppColors.primary : AppColors.goal,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved: ${CurrencyFormatter.format(g.currentAmount, symbol: curr)} (${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isComplete ? AppColors.primary : AppColors.goal,
                  ),
                ),
                Text(
                  'Goal: ${CurrencyFormatter.format(g.targetAmount, symbol: curr)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isComplete ? 'Goal Achieved!' : 'Remaining: ${CurrencyFormatter.format(g.remainingAmount, symbol: curr)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isComplete ? AppColors.primary : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openWithdraw(context, ref, g),
                      icon: const Icon(Icons.remove, size: 14),
                      label: const Text('Withdraw', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _openContribute(context, ref, g),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add Funds', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
