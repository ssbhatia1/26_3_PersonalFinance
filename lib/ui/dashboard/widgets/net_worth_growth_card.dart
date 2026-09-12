import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction.dart';

class NetWorthGrowthCard extends StatelessWidget {
  final double currentNetWorth;
  final List<TransactionModel> transactions;
  final String currency;
  final double height;

  const NetWorthGrowthCard({
    super.key,
    required this.currentNetWorth,
    required this.transactions,
    required this.currency,
    this.height = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentNetWorth <= 0 && transactions.isEmpty) {
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
              Icon(Icons.show_chart_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No net worth history available',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Add accounts and record transactions to view actual wealth progression.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    // 6-month monthly timeline
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
    final monthSpots = <FlSpot>[];

    // Compute cumulative balance trajectory across 6 months
    final sortedTxs = List<TransactionModel>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate total net flow after each month cut-off
    double maxVal = 10.0;
    double minVal = 0.0;

    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      final endOfMonth = DateTime(m.year, m.month + 1, 0, 23, 59, 59);

      if (i == months.length - 1) {
        // Current point is current net worth
        final y = currentNetWorth;
        monthSpots.add(FlSpot(i.toDouble(), y));
        if (y > maxVal) maxVal = y;
        if (y < minVal) minVal = y;
      } else {
        // Retroactively estimate net worth backwards by subtracting net inflows that occurred after endOfMonth
        final flowsAfter = sortedTxs.where((t) => t.date.isAfter(endOfMonth)).fold<double>(
          0.0,
          (sum, t) => sum + (t.isIncome ? t.amount : -t.amount),
        );
        final estimated = currentNetWorth - flowsAfter;
        final y = estimated < 0 && currentNetWorth >= 0 ? 0.0 : estimated;
        monthSpots.add(FlSpot(i.toDouble(), y));
        if (y > maxVal) maxVal = y;
        if (y < minVal) minVal = y;
      }
    }

    final firstVal = monthSpots.first.y;
    final lastVal = monthSpots.last.y;
    final growthPct = firstVal > 0 ? ((lastVal - firstVal) / firstVal * 100) : 0.0;
    final isPositive = growthPct >= 0;
    final growthText = '${isPositive ? '+' : ''}${growthPct.toStringAsFixed(1)}% ↗';

    final range = maxVal - minVal;
    final yMax = max(10.0, maxVal + (range * 0.25).clamp(5.0, 50000.0));
    final yMin = min(0.0, minVal - (range * 0.1).clamp(0.0, 10000.0));

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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Worth Growth',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPositive ? const Color(0xFF10B981) : AppColors.expense).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  growthText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? const Color(0xFF10B981) : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart Area
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: yMin,
                maxY: yMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              DateFormat('MMM').format(months[idx]),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
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
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final idx = s.x.toInt();
                        final mName = idx >= 0 && idx < months.length
                            ? DateFormat('MMMM yyyy').format(months[idx])
                            : '';
                        return LineTooltipItem(
                          '$mName\n${CurrencyFormatter.format(s.y, symbol: currency)}',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: monthSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF10B981),
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: const Color(0xFF10B981),
                          strokeWidth: 2,
                          strokeColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF10B981).withOpacity(0.35),
                          const Color(0xFF10B981).withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
