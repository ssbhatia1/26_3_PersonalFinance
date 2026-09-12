import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class BudgetProgressCard extends StatelessWidget {
  final double totalBudgeted;
  final double totalSpent;
  final String currency;
  final double height;

  const BudgetProgressCard({
    super.key,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.currency,
    this.height = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasBudget = totalBudgeted > 0;

    if (!hasBudget) {
      return Container(
        height: height,
        padding: const EdgeInsets.all(24),
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
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No active budget limits configured',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Create a monthly budget in the Budgets section to track your spending limits.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final double progressFraction = (totalSpent / totalBudgeted).clamp(0.0, 1.0);
    final int progressPercent = (progressFraction * 100).round();

    final Color progressColor = progressPercent > 90
        ? AppColors.expense
        : (progressPercent > 75 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

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
          const Text(
            'Budget Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                // Circular Progress Gauge
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SizedBox(
                      width: 104,
                      height: 104,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 104,
                            height: 104,
                            child: CircularProgressIndicator(
                              value: progressFraction,
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$progressPercent%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Monthly Budget',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Subtext / Details
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetricRow(
                        label: 'Spent',
                        value: CurrencyFormatter.format(hasBudget ? totalSpent : 0.0, symbol: currency),
                        color: progressColor,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'Budget Limit',
                        value: CurrencyFormatter.format(hasBudget ? totalBudgeted : 0.0, symbol: currency),
                        color: isDark ? Colors.grey[300]! : const Color(0xFF334155),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'Remaining',
                        value: CurrencyFormatter.format(
                          hasBudget ? (totalBudgeted - totalSpent).clamp(0.0, totalBudgeted) : 0.0,
                          symbol: currency,
                        ),
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
