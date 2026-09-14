import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/tracer_chart.dart';
import '../../../data/models/investment.dart';

class InvestmentPortfolioCard extends StatelessWidget {
  final List<Investment> investments;
  final double totalInvestmentsValuation;
  final String currency;
  final double height;
  final DateTime? startDate;
  final DateTime? endDate;

  const InvestmentPortfolioCard({
    super.key,
    required this.investments,
    required this.totalInvestmentsValuation,
    required this.currency,
    this.height = 320.0,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate total invested and total current value
    final activeInv = investments.where((i) => !i.isDeleted && i.status.toLowerCase() != 'closed').toList();
    final totalInvested = activeInv.fold(0.0, (s, i) => s + i.investedAmount);
    final totalCurrent = activeInv.fold(0.0, (s, i) => s + (i.currentValue > 0 ? i.currentValue : i.investedAmount));
    final effectiveValue = totalCurrent > 0 ? totalCurrent : (totalInvested > 0 ? totalInvested : totalInvestmentsValuation);

    if (activeInv.isEmpty && effectiveValue <= 0) {
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
              Icon(Icons.trending_up_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No investments recorded',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Add investment assets to track portfolio valuation and growth.',
                textAlign: TextAlign.center,
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

    final double returnPct = totalInvested > 0
        ? ((effectiveValue - totalInvested) / totalInvested * 100)
        : 0.0;

    final isPositive = returnPct >= 0;
    final returnBadgeText = '${isPositive ? '+' : ''}${returnPct.toStringAsFixed(1)}% ${isPositive ? '↗' : '↘'}';

    final spots = <FlSpot>[];
    double maxVal = 10.0;
    double minVal = 0.0;

    for (int i = 0; i < timePoints.length; i++) {
      final pt = timePoints[i];
      final ptEnd = isMonthly
          ? DateTime(pt.year, pt.month + 1, 0, 23, 59, 59)
          : DateTime(pt.year, pt.month, pt.day, 23, 59, 59);

      final invsAtPt = activeInv.where((inv) => !inv.startDate.isAfter(ptEnd)).toList();

      final y = invsAtPt.fold(0.0, (sum, inv) {
        final invAgeDays = max(1, now.difference(inv.startDate).inDays);
        final elapsedDays = max(0, min(invAgeDays, ptEnd.difference(inv.startDate).inDays));
        final invRatio = elapsedDays / invAgeDays.toDouble();
        final invCost = inv.investedAmount;
        final invVal = inv.currentValue > 0 ? inv.currentValue : invCost;
        return sum + (invCost + ((invVal - invCost) * invRatio));
      });

      spots.add(FlSpot(i.toDouble(), max(0.0, y)));
      if (y > maxVal) maxVal = y;
      if (y < minVal) minVal = y;
    }

    final range = maxVal - minVal;
    final yMax = max(10.0, maxVal + (range * 0.25).clamp(5.0, 50000.0));
    final yMin = min(0.0, minVal - (range * 0.1).clamp(0.0, 10000.0));
    final xInterval = max(1.0, (timePoints.length / 6).floorToDouble());

    const accentBlue = Color(0xFF3B82F6);

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
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Investment Portfolio',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Value: ${CurrencyFormatter.format(effectiveValue, symbol: currency)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPositive ? const Color(0xFF10B981) : AppColors.expense).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  returnBadgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? const Color(0xFF10B981) : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max(0.0, (timePoints.length - 1).toDouble()),
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
                      interval: xInterval,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) return const SizedBox.shrink();
                        final idx = value.round();
                        if (idx >= 0 && idx < timePoints.length) {
                          final dt = timePoints[idx];
                          final label = isMonthly ? DateFormat('MMM').format(dt) : DateFormat('d MMM').format(dt);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              label,
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
                lineTouchData: buildTracerTouchData(
                  tracerColor: accentBlue,
                  currency: currency,
                  isDark: isDark,
                  xLabels: timePoints.map((dt) => isMonthly ? DateFormat('MMM yyyy').format(dt) : DateFormat('d MMM yyyy').format(dt)).toList(),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: accentBlue,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: accentBlue,
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
                          accentBlue.withOpacity(0.35),
                          accentBlue.withOpacity(0.02),
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
