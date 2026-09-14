import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/tracer_chart.dart';
import '../../../data/models/transaction.dart';

class CashFlowLineChart extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String currency;
  final double height;
  final DateTime? startDate;
  final DateTime? endDate;

  const CashFlowLineChart({
    super.key,
    required this.transactions,
    required this.currency,
    this.height = 320.0,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final start = startDate ??
        (transactions.isNotEmpty
            ? transactions.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b)
            : now.subtract(const Duration(days: 6)));
    final end = endDate ?? now;

    final diffDays = max(1, end.difference(start).inDays);

    final List<DateTime> timePoints;
    final bool isMonthly;

    if (diffDays <= 31) {
      isMonthly = false;
      final count = min(10, max(5, diffDays + 1));
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

    final List<FlSpot> incomeSpots = [];
    final List<FlSpot> expenseSpots = [];
    double maxVal = 10.0;

    for (int i = 0; i < timePoints.length; i++) {
      final pt = timePoints[i];
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

      final inc = ptTxs.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
      final exp = ptTxs.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);

      incomeSpots.add(FlSpot(i.toDouble(), inc));
      expenseSpots.add(FlSpot(i.toDouble(), exp));

      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }

    final hasActivity = incomeSpots.any((s) => s.y > 0) || expenseSpots.any((s) => s.y > 0);
    if (!hasActivity) {
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
              Icon(Icons.timeline_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No cash flow activity in selected timeframe',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Income and expense trajectory will display when transactions occur in this timeframe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    maxVal = max(10.0, maxVal * 1.25);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cash Flow Trajectory (Line Chart)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Income vs Expense trends for selected timeframe',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegend(AppColors.income, 'Inflow'),
                  const SizedBox(width: 14),
                  _buildLegend(AppColors.expense, 'Outflow'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max(0.0, (timePoints.length - 1).toDouble()),
                minY: 0,
                maxY: maxVal,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
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
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: AppColors.income,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.income,
                        strokeWidth: 2,
                        strokeColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.income.withOpacity(0.20),
                          AppColors.income.withOpacity(0.01),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: expenseSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: AppColors.expense,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.expense,
                        strokeWidth: 2,
                        strokeColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.expense.withOpacity(0.18),
                          AppColors.expense.withOpacity(0.01),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: buildTracerTouchData(
                  tracerColor: AppColors.primary,
                  currency: currency,
                  isDark: isDark,
                  xLabels: timePoints.map((dt) => isMonthly ? DateFormat('MMM yyyy').format(dt) : DateFormat('d MMM yyyy').format(dt)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
