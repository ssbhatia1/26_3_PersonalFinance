import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class KpiMetricsSection extends StatelessWidget {
  final double netWorth;
  final double income;
  final double expense;
  final double liquidAssets;
  final String currency;

  const KpiMetricsSection({
    super.key,
    required this.netWorth,
    required this.income,
    required this.expense,
    required this.liquidAssets,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final savings = income - expense;
    final savingsRate = income > 0 ? ((savings / income) * 100).clamp(-100.0, 100.0) : 0.0;
    final runwayMonths = expense > 0 ? (liquidAssets / expense) : (liquidAssets > 0 ? 12.0 : 0.0);

    final hasFinancialActivity = netWorth != 0 || income != 0 || expense != 0 || liquidAssets != 0;

    // Calculate Financial Health Score (0 to 100)
    double healthScore = 50.0;
    if (savingsRate > 20) {
      healthScore += 25;
    } else if (savingsRate > 0) {
      healthScore += 10;
    } else {
      healthScore -= 20;
    }

    if (runwayMonths >= 6) {
      healthScore += 25;
    } else if (runwayMonths >= 3) {
      healthScore += 15;
    } else {
      healthScore -= 15;
    }
    healthScore = healthScore.clamp(10.0, 99.0);

    final isWide = MediaQuery.of(context).size.width >= 1100;
    final isTablet = MediaQuery.of(context).size.width >= 650;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text(
              'Key Financial Performance Indicators',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    hasFinancialActivity
                        ? 'Health Index: ${healthScore.toInt()}/100'
                        : 'Health Index: Awaiting Data',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: isWide ? 4 : (isTablet ? 2 : 1),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.45 : (isTablet ? 1.8 : 2.4),
          children: [
            _buildKpiCard(
              context: context,
              title: 'Total Net Worth',
              value: CurrencyFormatter.format(netWorth, symbol: currency),
              subtitle: 'Assets less Liabilities',
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              trend: hasFinancialActivity ? 'Solvent & Stable' : 'Awaiting Data',
            ),
            _buildKpiCard(
              context: context,
              title: 'Monthly Cash Flow',
              value: CurrencyFormatter.format(savings, symbol: currency),
              subtitle: 'Net Inflow vs Outflow',
              icon: savings >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: savings >= 0 ? AppColors.income : AppColors.error,
              trend: (income > 0 || expense > 0)
                  ? '${savings >= 0 ? "+" : ""}${savingsRate.toStringAsFixed(1)}% savings rate'
                  : 'No Cash Flow Activity',
            ),
            _buildKpiCard(
              context: context,
              title: 'Liquid Safety Runway',
              value: '${runwayMonths.toStringAsFixed(1)} Months',
              subtitle: 'Expenses covered by cash',
              icon: Icons.shield_rounded,
              color: runwayMonths >= 3 ? AppColors.asset : AppColors.liability,
              trend: liquidAssets > 0
                  ? (runwayMonths >= 6 ? 'Optimal Buffer' : 'Needs Expansion')
                  : 'No Liquid Buffer',
            ),
            _buildKpiCard(
              context: context,
              title: 'Burn Efficiency',
              value: income > 0 ? '${((expense / income) * 100).toStringAsFixed(0)}%' : '0%',
              subtitle: 'Outflow ratio to income',
              icon: Icons.pie_chart_outline_rounded,
              color: expense < income ? AppColors.investment : AppColors.error,
              trend: income > 0
                  ? (expense < income ? 'Within Healthy Range' : 'Deficit Alert')
                  : 'No Outflow/Inflow',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
