import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';

/// Reusable Tracer Line Chart component providing interactive touch tracer lines,
/// glowing crosshair dots, and rich floating tooltips across all modules.
class TracerLineChart extends StatefulWidget {
  final List<FlSpot> spots;
  final List<String>? xLabels;
  final String currency;
  final Color lineColor;
  final String title;
  final String? subtitle;
  final double height;
  final bool showGradient;
  final double? minY;
  final double? maxY;
  final void Function(FlSpot? spot, int? index)? onSpotTouched;

  const TracerLineChart({
    super.key,
    required this.spots,
    this.xLabels,
    required this.currency,
    this.lineColor = AppColors.primary,
    this.title = 'Performance Trajectory',
    this.subtitle,
    this.height = 240.0,
    this.showGradient = true,
    this.minY,
    this.maxY,
    this.onSpotTouched,
  });

  @override
  State<TracerLineChart> createState() => _TracerLineChartState();
}

class _TracerLineChartState extends State<TracerLineChart> {
  int? _activeTracerIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.spots.isEmpty) {
      return Container(
        height: widget.height,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timeline_rounded, size: 36, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No trajectory data available',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final double computedMinY = widget.minY ??
        widget.spots.fold(double.infinity, (prev, s) => min(prev, s.y));
    final double computedMaxY = widget.maxY ??
        widget.spots.fold(-double.infinity, (prev, s) => max(prev, s.y));

    final double minYVal = min(0.0, computedMinY < 0 ? computedMinY * 1.1 : 0.0);
    final double maxYVal = max(10.0, computedMaxY == 0 ? 100.0 : computedMaxY * 1.2);

    final activeSpot = _activeTracerIndex != null &&
            _activeTracerIndex! >= 0 &&
            _activeTracerIndex! < widget.spots.length
        ? widget.spots[_activeTracerIndex!]
        : widget.spots.last;

    final activeLabel = widget.xLabels != null &&
            _activeTracerIndex != null &&
            _activeTracerIndex! < widget.xLabels!.length
        ? widget.xLabels![_activeTracerIndex!]
        : null;

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Live Tracer Value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Live Tracer Value Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.lineColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.lineColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.lineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${activeLabel != null ? "$activeLabel: " : ""}${CurrencyFormatter.formatCompact(activeSpot.y, symbol: widget.currency)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.lineColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Core LineChart with Dynamic Tracer Crosshair
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (widget.spots.length - 1).toDouble(),
                minY: minYVal,
                maxY: maxYVal,
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
                          CurrencyFormatter.formatCompact(val, symbol: widget.currency),
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        if (val != val.roundToDouble()) return const SizedBox.shrink();
                        final idx = val.round();
                        if (idx >= 0 && idx < widget.spots.length) {
                          final label = widget.xLabels != null && idx < widget.xLabels!.length
                              ? widget.xLabels![idx]
                              : '${idx + 1}';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: _activeTracerIndex == idx ? FontWeight.bold : FontWeight.w500,
                                color: _activeTracerIndex == idx
                                    ? widget.lineColor
                                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
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
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                      final idx = response.lineBarSpots!.first.spotIndex;
                      if (_activeTracerIndex != idx) {
                        setState(() => _activeTracerIndex = idx);
                        if (widget.onSpotTouched != null) {
                          widget.onSpotTouched!(widget.spots[idx], idx);
                        }
                      }
                    }
                  },
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((spotIndex) {
                      return TouchedSpotIndicatorData(
                        // Tracer Vertical Dash Line (Crosshair)
                        FlLine(
                          color: widget.lineColor.withOpacity(0.85),
                          strokeWidth: 2,
                          dashArray: [4, 4],
                        ),
                        // Animated Glowing Spot Dot
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6.5,
                              color: widget.lineColor,
                              strokeWidth: 3,
                              strokeColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.spotIndex;
                        final label = widget.xLabels != null && idx < widget.xLabels!.length
                            ? widget.xLabels![idx]
                            : 'Point ${idx + 1}';
                        return LineTooltipItem(
                          '$label\n${CurrencyFormatter.format(spot.y, symbol: widget.currency)}',
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: widget.spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: widget.lineColor,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: widget.lineColor,
                        strokeWidth: 2,
                        strokeColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: widget.showGradient,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.lineColor.withOpacity(0.30),
                          widget.lineColor.withOpacity(0.01),
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

/// Helper extension function to construct standard Tracer LineTouchData for any LineChartData
LineTouchData buildTracerTouchData({
  required Color tracerColor,
  required String currency,
  required bool isDark,
  List<String>? xLabels,
  void Function(int index)? onTouchSpot,
}) {
  return LineTouchData(
    enabled: true,
    handleBuiltInTouches: true,
    touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
      if (onTouchSpot != null &&
          response != null &&
          response.lineBarSpots != null &&
          response.lineBarSpots!.isNotEmpty) {
        onTouchSpot(response.lineBarSpots!.first.spotIndex);
      }
    },
    getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
      return spotIndexes.map((spotIndex) {
        final color = barData.color ?? tracerColor;
        return TouchedSpotIndicatorData(
          FlLine(
            color: color.withOpacity(0.85),
            strokeWidth: 2,
            dashArray: [4, 4],
          ),
          FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 6.5,
                color: color,
                strokeWidth: 3,
                strokeColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              );
            },
          ),
        );
      }).toList();
    },
    touchTooltipData: LineTouchTooltipData(
      getTooltipItems: (touchedSpots) {
        return touchedSpots.map((spot) {
          final idx = spot.spotIndex;
          final label = xLabels != null && idx < xLabels.length ? xLabels[idx] : null;
          return LineTooltipItem(
            '${label != null ? "$label\n" : ""}${CurrencyFormatter.format(spot.y, symbol: currency)}',
            const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          );
        }).toList();
      },
    ),
  );
}
