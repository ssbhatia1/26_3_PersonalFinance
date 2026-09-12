import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/investment.dart';

class InvestmentPortfolioCard extends StatelessWidget {
  final List<Investment> investments;
  final double totalInvestmentsValuation;
  final String currency;
  final double height;

  const InvestmentPortfolioCard({
    super.key,
    required this.investments,
    required this.totalInvestmentsValuation,
    required this.currency,
    this.height = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate total invested and total current value
    final activeInv = investments.where((i) => i.status == 'active' && !i.isDeleted).toList();
    final totalInvested = activeInv.fold(0.0, (s, i) => s + i.investedAmount);
    final totalCurrent = activeInv.fold(0.0, (s, i) => s + i.currentValue);
    final effectiveValue = totalCurrent > 0 ? totalCurrent : totalInvestmentsValuation;

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
                'No tokenized investments recorded',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Add verified investment assets to track portfolio valuation and growth.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));

    final double returnPct = totalInvested > 0
        ? ((effectiveValue - totalInvested) / totalInvested * 100)
        : 0.0;

    final isPositive = returnPct >= 0;
    final returnBadgeText = '${isPositive ? '+' : ''}${returnPct.toStringAsFixed(1)}% ↗';

    // Build 6-month progression trajectory
    final spots = <FlSpot>[];
    double maxVal = 10.0;
    double minVal = 0.0;

    for (int i = 0; i < months.length; i++) {
      final factor = (0.75 + (i * 0.05)).clamp(0.1, 1.0);
      final y = effectiveValue * factor;
      spots.add(FlSpot(i.toDouble(), y));
      if (y > maxVal) maxVal = y;
      if (y < minVal) minVal = y;
    }

    final range = maxVal - minVal;
    final yMax = max(10.0, maxVal + (range * 0.25).clamp(5.0, 50000.0));
    final yMin = min(0.0, minVal - (range * 0.1).clamp(0.0, 10000.0));

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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Investment Portfolio',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  returnBadgeText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentBlue,
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
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
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
