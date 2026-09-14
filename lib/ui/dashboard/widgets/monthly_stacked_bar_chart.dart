import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction.dart';

class MonthlyStackedBarChart extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String currency;
  final double height;
  final DateTime? startDate;
  final DateTime? endDate;

  const MonthlyStackedBarChart({
    super.key,
    this.transactions = const [],
    required this.currency,
    this.height = 320.0,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month - 3, 1);
    final end = endDate ?? now;
    final diffDays = max(1, end.difference(start).inDays);

    final List<DateTime> timePoints;
    final bool isMonthly;

    if (diffDays <= 31) {
      isMonthly = false;
      final count = min(8, max(4, (diffDays / 7).round() + 1));
      final step = diffDays / max(1, count - 1);
      timePoints = List.generate(count, (i) => start.add(Duration(seconds: (i * step * 86400).round())));
    } else {
      isMonthly = true;
      final startMonth = DateTime(start.year, start.month, 1);
      final endMonth = DateTime(end.year, end.month, 1);
      final list = <DateTime>[];
      var curr = startMonth;
      while (!curr.isAfter(endMonth) && list.length < 12) {
        list.add(curr);
        curr = DateTime(curr.year, curr.month + 1, 1);
      }
      timePoints = list.isEmpty ? [startMonth] : list;
    }

    // Colors for stack components
    const colorIncome = AppColors.income;     // Green (Inflow)
    const colorExpense = AppColors.expense;   // Red/Coral (Outflow)
    const colorTransfer = Color(0xFF3B82F6);  // Blue (Transfers)

    final dataStacks = <List<double>>[];
    double maxMonthTotal = 0.0;
    int totalTransactionsInWindow = 0;

    for (final pt in timePoints) {
      List<TransactionModel> ptTxs;

      if (isMonthly) {
        ptTxs = transactions.where((t) {
          return t.date.year == pt.year && t.date.month == pt.month;
        }).toList();
      } else {
        final ptStart = DateTime(pt.year, pt.month, pt.day);
        final ptEnd = DateTime(pt.year, pt.month, pt.day, 23, 59, 59);
        ptTxs = transactions.where((t) {
          return !t.date.isBefore(ptStart) && !t.date.isAfter(ptEnd);
        }).toList();
      }

      totalTransactionsInWindow += ptTxs.length;

      final inc = ptTxs.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
      final exp = ptTxs.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
      final trans = ptTxs.where((t) => t.isTransfer).fold(0.0, (s, t) => s + t.amount);

      final total = inc + exp + trans;
      if (total > maxMonthTotal) maxMonthTotal = total;

      dataStacks.add([inc, exp, trans]);
    }

    if (totalTransactionsInWindow == 0 || maxMonthTotal <= 0) {
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
              Icon(Icons.bar_chart_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No transaction data in selected timeframe',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Capital allocation trends will appear when transactions are recorded.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final double maxTotal = max(100.0, maxMonthTotal * 1.25);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < timePoints.length; i++) {
      final stack = dataStacks[i];
      final r1 = stack[0]; // Income
      final r2 = r1 + stack[1]; // Expense
      final r3 = r2 + stack[2]; // Transfers

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: r3,
              rodStackItems: [
                if (r1 > 0) BarChartRodStackItem(0, r1, colorIncome),
                if (stack[1] > 0) BarChartRodStackItem(r1, r2, colorExpense),
                if (stack[2] > 0) BarChartRodStackItem(r2, r3, colorTransfer),
              ],
              width: timePoints.length > 8 ? 14 : 22,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      );
    }

    final xInterval = max(1.0, (timePoints.length / 6).floorToDouble());

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Capital Movement (Stacked Bar Chart)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Actual income, expense, and account transfers in timeframe',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _buildLegend(colorIncome, 'Income'),
                  _buildLegend(colorExpense, 'Expense'),
                  _buildLegend(colorTransfer, 'Transfers'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxTotal,
                barGroups: groups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          CurrencyFormatter.formatCompact(value, symbol: currency),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: xInterval,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) return const SizedBox.shrink();
                        final idx = value.round();
                        if (idx >= 0 && idx < timePoints.length) {
                          final dt = timePoints[idx];
                          final label = isMonthly ? DateFormat('MMM').format(dt) : DateFormat('d MMM').format(dt);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final stack = dataStacks[groupIndex];
                      final dt = timePoints[groupIndex];
                      final title = isMonthly ? DateFormat('MMMM yyyy').format(dt) : DateFormat('d MMMM yyyy').format(dt);
                      return BarTooltipItem(
                        '$title\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        children: [
                          TextSpan(
                            text: 'Income: ${CurrencyFormatter.format(stack[0], symbol: currency)}\n',
                            style: const TextStyle(color: colorIncome, fontSize: 11),
                          ),
                          TextSpan(
                            text: 'Expense: ${CurrencyFormatter.format(stack[1], symbol: currency)}\n',
                            style: const TextStyle(color: colorExpense, fontSize: 11),
                          ),
                          TextSpan(
                            text: 'Transfers: ${CurrencyFormatter.format(stack[2], symbol: currency)}',
                            style: const TextStyle(color: colorTransfer, fontSize: 11),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
