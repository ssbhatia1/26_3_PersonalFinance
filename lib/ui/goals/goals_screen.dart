import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, idx) {
              final g = goals[idx];
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
                          Text(
                            isComplete ? 'Goal Achieved!' : 'Remaining: ${CurrencyFormatter.format(g.remainingAmount, symbol: curr)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isComplete ? AppColors.primary : null,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openContribute(context, ref, g),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Funds'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
