import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class FinancialFunnelChart extends StatelessWidget {
  final double grossInflow;
  final double budgetAllocated;
  final double actualOutflow;
  final double netSavings;
  final String currency;
  final double height;

  const FinancialFunnelChart({
    super.key,
    required this.grossInflow,
    required this.budgetAllocated,
    required this.actualOutflow,
    required this.netSavings,
    required this.currency,
    this.height = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show clean empty state when no actual transactions exist in the period
    if (grossInflow <= 0 && actualOutflow <= 0) {
      return Container(
        height: height,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No income or expense data in this period',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Financial conversion flow will display when actual transaction data exists.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final baseInflow = grossInflow;
    final budgetVal = budgetAllocated;
    final outflowVal = actualOutflow;
    final surplusVal = netSavings;

    final budgetPct = baseInflow > 0 ? ((budgetVal / baseInflow) * 100).clamp(0.0, 999.0) : 0.0;
    final outflowPct = baseInflow > 0 ? ((outflowVal / baseInflow) * 100).clamp(0.0, 999.0) : (outflowVal > 0 ? 100.0 : 0.0);
    final surplusPct = baseInflow > 0 ? ((surplusVal / baseInflow) * 100) : 0.0;

    final stages = [
      _FunnelStageData(
        title: 'Stage 1: Gross Cash Inflow',
        amount: baseInflow,
        percentage: 100.0,
        color: const Color(0xFF0284C7), // Blue
        description: 'Total actual earnings, salary, dividends, and receivables',
        icon: Icons.login_rounded,
      ),
      _FunnelStageData(
        title: 'Stage 2: Budget Allocation',
        amount: budgetVal,
        percentage: budgetPct,
        color: const Color(0xFF0D9488), // Teal
        description: budgetVal > 0 ? 'Approved spending budget limit' : 'No category budget configured',
        icon: Icons.tune_rounded,
      ),
      _FunnelStageData(
        title: 'Stage 3: Actual Realized Outflow',
        amount: outflowVal,
        percentage: outflowPct,
        color: const Color(0xFFF59E0B), // Amber
        description: 'Actual incurred essential and discretionary expenditures',
        icon: Icons.shopping_bag_outlined,
      ),
      _FunnelStageData(
        title: 'Stage 4: Net Retained Wealth',
        amount: surplusVal,
        percentage: surplusPct,
        color: surplusVal >= 0 ? const Color(0xFF10B981) : AppColors.expense,
        description: surplusVal >= 0 ? 'Final wealth surplus retained from income' : 'Net deficit (outflow exceeded income)',
        icon: surplusVal >= 0 ? Icons.savings_rounded : Icons.trending_down_rounded,
      ),
    ];

    final conversionRate = baseInflow > 0 ? (surplusVal / baseInflow * 100).clamp(-100.0, 100.0) : 0.0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Financial Conversion Flow (Funnel Chart)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Inflow conversion efficiency through budgeting, expenditure, to wealth retention',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (conversionRate >= 0 ? AppColors.income : AppColors.expense).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  conversionRate >= 0 ? '${conversionRate.toStringAsFixed(1)}% Conversion' : '${conversionRate.toStringAsFixed(1)}% Deficit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: conversionRate >= 0 ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: [
                for (int idx = 0; idx < stages.length; idx++) ...[
                  Expanded(
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: (1.0 - (idx * 0.12)).clamp(0.45, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                stages[idx].color.withOpacity(isDark ? 0.25 : 0.15),
                                stages[idx].color.withOpacity(isDark ? 0.12 : 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: stages[idx].color.withOpacity(isDark ? 0.6 : 0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: stages[idx].color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(stages[idx].icon, size: 14, color: stages[idx].color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 320,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                stages[idx].title,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              CurrencyFormatter.format(stages[idx].amount, symbol: currency),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                                color: stages[idx].color,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 1),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                stages[idx].description,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: stages[idx].color.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${stages[idx].percentage.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: stages[idx].color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (idx < stages.length - 1)
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                      size: 14,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelStageData {
  final String title;
  final double amount;
  final double percentage;
  final Color color;
  final String description;
  final IconData icon;

  _FunnelStageData({
    required this.title,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.description,
    required this.icon,
  });
}
