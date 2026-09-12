import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/budget.dart';
import '../../../providers/budget_provider.dart';
import '../budget_form_dialog.dart';

class BudgetCard extends ConsumerWidget {
  final Budget budget;
  final String currency;
  final VoidCallback? onTap;

  const BudgetCard({
    super.key,
    required this.budget,
    required this.currency,
    this.onTap,
  });

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

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: Text(
          'Are you sure you want to delete "${budget.displayName}"? Previous transactions in your ledger will not be affected.',
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
      await ref.read(budgetProvider.notifier).deleteBudget(budget.id);
    }
  }

  void _openEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => BudgetFormDialog(budgetToEdit: budget),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = budget;
    final pct = b.percentageUsed;
    final isOver = b.isOverspent;
    final statusColor = _getStatusColor(b.alertLevel);
    final dateFormat = DateFormat('MMM d');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOver
            ? const BorderSide(color: AppColors.error, width: 1.2)
            : (b.alertLevel != BudgetAlertLevel.normal
                ? BorderSide(color: statusColor.withAlpha(120), width: 1)
                : BorderSide.none),
      ),
      elevation: isOver ? 3 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Category Icon + Title + Status Badge + Popup Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: statusColor.withAlpha(25),
                    child: Icon(
                      b.scope == 'overall'
                          ? Icons.all_inclusive_rounded
                          : (b.categoryIcon != null
                              ? Icons.category_rounded
                              : Icons.pie_chart_rounded),
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                b.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (b.isLongTerm) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.transfer.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_month_rounded, size: 10, color: AppColors.transfer),
                                    SizedBox(width: 2),
                                    Text(
                                      'Long-Term',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.transfer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (b.isRecurring) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.repeat_rounded, size: 10, color: AppColors.primary),
                                    SizedBox(width: 2),
                                    Text(
                                      'Recurring',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${b.periodType.toUpperCase()} • ${dateFormat.format(b.startDate)} - ${dateFormat.format(b.endDate)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        // Staying duration & safe pace
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (b.daysRemaining <= 3 && b.daysRemaining >= 0
                                    ? AppColors.warning
                                    : (b.daysRemaining < 0 ? Colors.grey : AppColors.primary)).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.hourglass_bottom_rounded,
                                    size: 11,
                                    color: b.daysRemaining <= 3 && b.daysRemaining >= 0
                                        ? AppColors.warning
                                        : (b.daysRemaining < 0 ? Colors.grey : AppColors.primary),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    b.remainingDaysLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: b.daysRemaining <= 3 && b.daysRemaining >= 0
                                          ? AppColors.warning
                                          : (b.daysRemaining < 0 ? Colors.grey : AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (b.dailyAllowance > 0)
                              Text(
                                '~${CurrencyFormatter.format(b.dailyAllowance, symbol: currency)}/day pace',
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withAlpha(70)),
                    ),
                    child: Text(
                      b.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      if (val == 'details' && onTap != null) {
                        onTap!();
                      } else if (val == 'edit') {
                        _openEditDialog(context);
                      } else if (val == 'delete') {
                        _confirmDelete(context, ref);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Edit Budget'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct > 1.0 ? 1.0 : pct,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 10),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        const TextSpan(
                          text: 'Spent: ',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        TextSpan(
                          text: CurrencyFormatter.format(b.spentAmount, symbol: currency),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${CurrencyFormatter.format(b.amountLimit, symbol: currency)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isOver
                        ? 'Over: ${CurrencyFormatter.format(b.spentAmount - b.amountLimit, symbol: currency)}'
                        : 'Left: ${CurrencyFormatter.format(b.remainingAmount, symbol: currency)}',
                    style: TextStyle(
                      fontSize: 12,
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
  }
}
