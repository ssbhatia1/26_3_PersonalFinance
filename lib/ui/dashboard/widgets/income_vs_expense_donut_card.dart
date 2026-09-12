import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class IncomeVsExpenseDonutCard extends StatelessWidget {
  final double income;
  final double expense;
  final String currency;
  final double height;

  const IncomeVsExpenseDonutCard({
    super.key,
    required this.income,
    required this.expense,
    required this.currency,
    this.height = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = income + expense;

    if (total <= 0) {
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
              Icon(Icons.donut_large_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No income or expense data in this period',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Actual cash flow breakdown will display when transactions occur.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final double incomePct = (income / total * 100);
    final double expensePct = (expense / total * 100);

    const colorIncome = Color(0xFF10B981); // Vibrant Green
    const colorExpense = Color(0xFFEF4444); // Coral Red

    final sections = <PieChartSectionData>[
      PieChartSectionData(
        color: colorIncome,
        value: income,
        radius: 20,
        showTitle: false,
      ),
      PieChartSectionData(
        color: colorExpense,
        value: expense,
        radius: 20,
        showTitle: false,
      ),
    ];

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
            'Income vs Expense',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                // Donut Chart
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          centerSpaceRadius: 38,
                          sectionsSpace: 3,
                          startDegreeOffset: -90,
                          pieTouchData: PieTouchData(enabled: false),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Legend
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Income Row
                      _buildLegendItem(
                        color: colorIncome,
                        label: 'Income',
                        percentage: incomePct,
                        amount: income,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      // Expense Row
                      _buildLegendItem(
                        color: colorExpense,
                        label: 'Expenses',
                        percentage: expensePct,
                        amount: expense,
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

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required double percentage,
    required double amount,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Text(
            CurrencyFormatter.format(amount, symbol: currency),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
