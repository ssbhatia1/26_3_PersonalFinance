import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/tracer_chart.dart';
import '../../../data/models/transaction.dart';

class NetWorthAreaChart extends StatelessWidget {
  final double currentNetWorth;
  final List<TransactionModel> transactions;
  final String currency;
  final double height;
  final DateTime? startDate;
  final DateTime? endDate;

  const NetWorthAreaChart({
    super.key,
    required this.currentNetWorth,
    required this.transactions,
    required this.currency,
    this.height = 380.0,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentNetWorth <= 0 && transactions.isEmpty) {
      return Container(
        height: height,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No net worth history available',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Add accounts and record transactions to build your wealth progression curve.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month - 5, 1);
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

    final sortedTxs = List<TransactionModel>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = <FlSpot>[];

    for (int i = 0; i < timePoints.length; i++) {
      final pt = timePoints[i];
      final ptEnd = isMonthly
          ? DateTime(pt.year, pt.month + 1, 0, 23, 59, 59)
          : DateTime(pt.year, pt.month, pt.day, 23, 59, 59);

      if (i == timePoints.length - 1) {
        spots.add(FlSpot(i.toDouble(), currentNetWorth));
      } else {
        final afterTxs = sortedTxs.where((t) => t.date.isAfter(ptEnd));
        final afterInflow = afterTxs.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
        final afterOutflow = afterTxs.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
        final afterNetChange = afterInflow - afterOutflow;

        final netWorthAtPt = currentNetWorth - afterNetChange;
        spots.add(FlSpot(i.toDouble(), netWorthAtPt));
      }
    }

    final peakVal = spots.fold(currentNetWorth, (prev, s) => max(prev, s.y));
    final minVal = spots.fold(currentNetWorth, (prev, s) => min(prev, s.y));
    final double maxY = max(100.0, peakVal + (peakVal.abs() * 0.2).clamp(10.0, 50000.0));
    final double minY = min(0.0, minVal - (minVal.abs() * 0.1).clamp(0.0, 10000.0));
    final xInterval = max(1.0, (timePoints.length / 6).floorToDouble());

    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
                      'Cumulative Wealth Progression (Area Chart)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Historical equity buildup derived from actual cash flow data',
                      style: TextStyle(
                        fontSize: 12,
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
                  color: AppColors.income.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.income),
                    const SizedBox(width: 4),
                    Text(
                      'Current: ${CurrencyFormatter.formatCompact(currentNetWorth, symbol: currency)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max(0.0, (timePoints.length - 1).toDouble()),
                minY: minY,
                maxY: maxY,
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
                          final label = isMonthly ? DateFormat('MMM yy').format(dt) : DateFormat('d MMM').format(dt);
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
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary,
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
                          AppColors.primary.withOpacity(0.35),
                          AppColors.primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: buildTracerTouchData(
                  tracerColor: AppColors.primary,
                  currency: currency,
                  isDark: isDark,
                  xLabels: timePoints.map((dt) => isMonthly ? DateFormat('MMM yy').format(dt) : DateFormat('d MMM yy').format(dt)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
