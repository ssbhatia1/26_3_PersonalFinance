import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class RunwayEstimationChart extends StatelessWidget {
  final int runwayDays;
  final bool isInfiniteRunway;
  final double liquidAssets;
  final double avgDailyOutflow;
  final String currency;
  final bool isDark;
  final double height;

  const RunwayEstimationChart({
    super.key,
    required this.runwayDays,
    required this.isInfiniteRunway,
    required this.liquidAssets,
    required this.avgDailyOutflow,
    required this.currency,
    this.isDark = false,
    this.height = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    if (liquidAssets <= 0 && avgDailyOutflow <= 0) {
      return Container(
        height: height,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
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
              Icon(Icons.hourglass_empty_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No financial runway estimation available',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Add accounts with balances or record transactions to generate a liquidity depletion trajectory.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    Color runwayColor;
    String statusBadge;
    if (isInfiniteRunway) {
      runwayColor = AppColors.income;
      statusBadge = 'Sustainable';
    } else if (runwayDays >= 180) {
      runwayColor = AppColors.income;
      statusBadge = 'Comfortable (6+ Mo)';
    } else if (runwayDays >= 90) {
      runwayColor = const Color(0xFF0284C7);
      statusBadge = 'Healthy (3-6 Mo)';
    } else if (runwayDays >= 30) {
      runwayColor = AppColors.warning;
      statusBadge = 'Moderate (1-3 Mo)';
    } else {
      runwayColor = AppColors.error;
      statusBadge = 'Critical (< 30d)';
    }

    // Determine horizon and generate spots for the depletion graph
    final int horizonDays;
    if (isInfiniteRunway) {
      horizonDays = 180; // Project 6 months out
    } else if (runwayDays <= 30) {
      horizonDays = 30;
    } else if (runwayDays <= 90) {
      horizonDays = 90;
    } else if (runwayDays <= 180) {
      horizonDays = 180;
    } else {
      horizonDays = min(365, max(180, ((runwayDays / 30).ceil() * 30)));
    }

    final List<FlSpot> spots = [];
    const int stepCount = 6;
    final double stepSize = horizonDays / stepCount;

    for (int i = 0; i <= stepCount; i++) {
      final day = (i * stepSize).round();
      final double balance;
      if (isInfiniteRunway) {
        balance = liquidAssets;
      } else {
        balance = max(0.0, liquidAssets - (avgDailyOutflow * day));
      }
      spots.add(FlSpot(day.toDouble(), balance));
    }

    // Ensure zero-balance day is explicitly included as a spot if within horizon
    if (!isInfiniteRunway && runwayDays > 0 && runwayDays <= horizonDays) {
      final exists = spots.any((s) => s.x.toInt() == runwayDays);
      if (!exists) {
        spots.add(FlSpot(runwayDays.toDouble(), 0.0));
        spots.sort((a, b) => a.x.compareTo(b.x));
      }
    }

    final double maxY = max(100.0, liquidAssets * 1.15);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: runwayColor.withAlpha(70)),
        boxShadow: [
          BoxShadow(
            color: runwayColor.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Status Badge
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: runwayColor, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Financial Runway Estimation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: runwayColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: runwayColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Visual Health Gauge (Segmented Runway Horizon)
          _buildHealthGauge(isDark, runwayColor),
          const SizedBox(height: 8),

          // Graph Title and Legend
          Row(
            children: [
              Expanded(
                child: Text(
                  'Liquidity Depletion Trajectory',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: runwayColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isInfiniteRunway ? 'Sustainable' : 'Projected Balance',
                    style: TextStyle(fontSize: 9.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // The Core Depletion Line Chart (Graph Representation)
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: horizonDays.toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
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
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox.shrink();
                        return Text(
                          CurrencyFormatter.formatCompact(val, symbol: currency),
                          style: TextStyle(fontSize: 8.5, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (val, meta) {
                        final d = val.toInt();
                        if (d == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text('Today', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                          );
                        }
                        if (d % 30 == 0 || d == horizonDays) {
                          return Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text('+${d}d', style: const TextStyle(fontSize: 9.5)),
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
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'Day +${spot.x.toInt()}\n${CurrencyFormatter.format(spot.y, symbol: currency)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: runwayColor,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isLast = index == spots.length - 1;
                        final isDepleted = !isInfiniteRunway && spot.y == 0;
                        return FlDotCirclePainter(
                          radius: isDepleted || isLast ? 3.5 : 2,
                          color: isDepleted ? AppColors.error : runwayColor,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          runwayColor.withAlpha(70),
                          runwayColor.withAlpha(5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Graphical Metric Badges
          Row(
            children: [
              Expanded(
                child: _buildMetricBadge(
                  icon: Icons.account_balance_rounded,
                  label: 'Balance',
                  value: CurrencyFormatter.formatCompact(liquidAssets, symbol: currency),
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricBadge(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Outflow',
                  value: avgDailyOutflow > 0
                      ? '-${CurrencyFormatter.formatCompact(avgDailyOutflow, symbol: currency)}/d'
                      : '$currency 0/d',
                  color: AppColors.expense,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricBadge(
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'Horizon',
                  value: isInfiniteRunway ? 'Indefinite' : '$runwayDays Days',
                  color: runwayColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthGauge(bool isDark, Color runwayColor) {
    // Determine pointer position along 0 - 240 days scale
    final double gaugeFraction;
    if (isInfiniteRunway) {
      gaugeFraction = 1.0;
    } else {
      gaugeFraction = (runwayDays / 240.0).clamp(0.02, 0.98);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Runway Horizon Scale',
                style: TextStyle(fontSize: 9.5, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isInfiniteRunway ? '∞ Days (Sustainable)' : '$runwayDays Days of Liquidity',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Row(
              children: [
                Expanded(flex: 30, child: Container(color: AppColors.error)), // <30d
                Expanded(flex: 60, child: Container(color: AppColors.warning)), // 30-90d
                Expanded(flex: 90, child: Container(color: const Color(0xFF0284C7))), // 90-180d
                Expanded(flex: 60, child: Container(color: AppColors.income)), // 180d+
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final double leftOffset = (constraints.maxWidth * gaugeFraction) - 4;
            return Stack(
              children: [
                const SizedBox(height: 12, width: double.infinity),
                Positioned(
                  left: leftOffset.clamp(0.0, constraints.maxWidth - 10),
                  child: Icon(Icons.arrow_drop_up_rounded, size: 14, color: runwayColor),
                ),
                Positioned(
                  left: 0,
                  top: 1,
                  child: Text('0d', style: TextStyle(fontSize: 7.5, color: Colors.grey[500])),
                ),
                Positioned(
                  right: 0,
                  top: 1,
                  child: Text('180d+', style: TextStyle(fontSize: 7.5, color: Colors.grey[500])),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 8.5, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
