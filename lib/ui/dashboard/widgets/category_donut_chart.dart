import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class CategoryDonutChart extends StatefulWidget {
  final List<Map<String, dynamic>> categorySpending;
  final String currency;
  final double height;
  final String title;
  final String subtitle;
  final String emptyMessage;

  const CategoryDonutChart({
    super.key,
    required this.categorySpending,
    required this.currency,
    this.height = 320.0,
    this.title = 'Expense Share (Donut Chart)',
    this.subtitle = 'Percentage breakdown of monthly capital outflow',
    this.emptyMessage = 'No expense distribution data for current timeframe.',
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spending = widget.categorySpending;

    final totalExpense = spending.fold(0.0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0));

    if (spending.isEmpty || totalExpense <= 0) {
      return Container(
        height: widget.height,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(widget.emptyMessage),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < spending.length; i++) {
      final item = spending[i];
      final isTouched = i == _touchedIndex;
      final amount = (item['amount'] as num).toDouble();
      final percentage = totalExpense > 0 ? ((amount / totalExpense) * 100) : 0.0;
      final colorHex = item['categoryColor'] as String?;
      Color color = AppColors.primary;
      if (colorHex != null) {
        color = Color(int.tryParse(colorHex) ?? AppColors.primary.value);
      }

      sections.add(
        PieChartSectionData(
          color: color,
          value: amount,
          title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
          radius: isTouched ? 32 : 24,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      height: widget.height,
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
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total: ${CurrencyFormatter.formatCompact(totalExpense, symbol: widget.currency)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 340;

                final chartWidget = SizedBox(
                  height: 150,
                  width: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 3,
                          centerSpaceRadius: 48,
                          sections: sections,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SPENT',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            child: Text(
                              CurrencyFormatter.formatCompact(totalExpense, symbol: widget.currency),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final legendWidget = ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: spending.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final item = spending[idx];
                    final amount = (item['amount'] as num).toDouble();
                    final percent = totalExpense > 0 ? (amount / totalExpense * 100) : 0.0;
                    final colorHex = item['categoryColor'] as String?;
                    Color color = AppColors.primary;
                    if (colorHex != null) {
                      color = Color(int.tryParse(colorHex) ?? AppColors.primary.value);
                    }

                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item['categoryName'] as String,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${percent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          CurrencyFormatter.formatCompact(amount, symbol: widget.currency),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    );
                  },
                );

                if (isStacked) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        Center(child: chartWidget),
                        const SizedBox(height: 12),
                        legendWidget,
                      ],
                    ),
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(child: chartWidget),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Center(
                        child: legendWidget,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
