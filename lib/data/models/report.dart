import 'dart:math';

/// Summary of cash flow over a given time period
class CashFlowReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpense;

  const CashFlowReport({
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpense,
  });

  double get netSavings => totalIncome - totalExpense;
  double get savingsRate => totalIncome > 0 ? (netSavings / totalIncome * 100).clamp(-100.0, 100.0) : 0.0;
  bool get isPositive => netSavings >= 0;
  bool get isDeficit => netSavings < 0;

  CashFlowReport copyWith({
    DateTime? startDate,
    DateTime? endDate,
    double? totalIncome,
    double? totalExpense,
  }) {
    return CashFlowReport(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netSavings': netSavings,
      'savingsRate': savingsRate,
    };
  }

  factory CashFlowReport.fromMap(Map<String, dynamic> map) {
    return CashFlowReport(
      startDate: DateTime.tryParse(map['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(map['endDate']?.toString() ?? '') ?? DateTime.now(),
      totalIncome: (map['totalIncome'] as num?)?.toDouble() ?? (map['income'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (map['totalExpense'] as num?)?.toDouble() ?? (map['expense'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashFlowReport &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          totalIncome == other.totalIncome &&
          totalExpense == other.totalExpense;

  @override
  int get hashCode => startDate.hashCode ^ endDate.hashCode ^ totalIncome.hashCode ^ totalExpense.hashCode;

  @override
  String toString() =>
      'CashFlowReport(income: $totalIncome, expense: $totalExpense, savings: $netSavings, rate: ${savingsRate.toStringAsFixed(1)}%)';
}

/// Category spending breakdown entry
class CategorySpendingReportItem {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final double amount;
  final double percentage; // 0 to 100
  final int transactionCount;

  const CategorySpendingReportItem({
    required this.categoryId,
    required this.categoryName,
    this.categoryIcon = 'category',
    this.categoryColor = '#00BCD4',
    required this.amount,
    this.percentage = 0.0,
    this.transactionCount = 0,
  });

  CategorySpendingReportItem copyWith({
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    double? amount,
    double? percentage,
    int? transactionCount,
  }) {
    return CategorySpendingReportItem(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryIcon': categoryIcon,
      'categoryColor': categoryColor,
      'amount': amount,
      'percentage': percentage,
      'transactionCount': transactionCount,
    };
  }

  factory CategorySpendingReportItem.fromMap(Map<String, dynamic> map) {
    return CategorySpendingReportItem(
      categoryId: (map['categoryId'] ?? map['category_id'] ?? '') as String,
      categoryName: (map['categoryName'] ?? map['category_name'] ?? 'Uncategorized') as String,
      categoryIcon: (map['categoryIcon'] ?? map['category_icon'] ?? 'category') as String,
      categoryColor: (map['categoryColor'] ?? map['category_color'] ?? '#00BCD4') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategorySpendingReportItem &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          amount == other.amount;

  @override
  int get hashCode => categoryId.hashCode ^ amount.hashCode;

  @override
  String toString() => 'CategorySpendingReportItem($categoryName: $amount, ${percentage.toStringAsFixed(1)}%)';
}

/// Financial runway metrics estimating days and months of liquidity
class RunwayMetrics {
  final double liquidAssets;
  final int periodDays;
  final double totalInflow;
  final double totalOutflow;
  final double avgDailyOutflow;
  final double avgWeeklyOutflow;
  final double avgMonthlyOutflow;
  final double avgDailyInflow;
  final double avgWeeklyInflow;
  final double avgMonthlyInflow;
  final int runwayDays;
  final bool isInfiniteRunway;

  const RunwayMetrics({
    required this.liquidAssets,
    required this.periodDays,
    required this.totalInflow,
    required this.totalOutflow,
    required this.avgDailyOutflow,
    required this.avgWeeklyOutflow,
    required this.avgMonthlyOutflow,
    required this.avgDailyInflow,
    required this.avgWeeklyInflow,
    required this.avgMonthlyInflow,
    required this.runwayDays,
    required this.isInfiniteRunway,
  });

  /// Factory constructor to compute runway from balances and cash flow
  factory RunwayMetrics.compute({
    required double liquidAssets,
    required double totalInflow,
    required double totalOutflow,
    required int daysInPeriod,
  }) {
    final period = max(1, daysInPeriod);
    final dailyOutflow = totalOutflow / period;
    final weeklyOutflow = dailyOutflow * 7;
    final monthlyOutflow = dailyOutflow * 30.4375;

    final dailyInflow = totalInflow / period;
    final weeklyInflow = dailyInflow * 7;
    final monthlyInflow = dailyInflow * 30.4375;

    final int days;
    final bool infinite;
    if (liquidAssets <= 0) {
      days = 0;
      infinite = false;
    } else if (dailyOutflow <= 0) {
      days = 999999;
      infinite = true;
    } else {
      infinite = false;
      days = max(0, (liquidAssets / dailyOutflow).round());
    }

    return RunwayMetrics(
      liquidAssets: liquidAssets,
      periodDays: period,
      totalInflow: totalInflow,
      totalOutflow: totalOutflow,
      avgDailyOutflow: dailyOutflow,
      avgWeeklyOutflow: weeklyOutflow,
      avgMonthlyOutflow: monthlyOutflow,
      avgDailyInflow: dailyInflow,
      avgWeeklyInflow: weeklyInflow,
      avgMonthlyInflow: monthlyInflow,
      runwayDays: days,
      isInfiniteRunway: infinite,
    );
  }

  double get runwayMonths => isInfiniteRunway ? 9999.0 : (runwayDays / 30.4375);

  /// Status classification: 'critical', 'warning', 'healthy', 'strong', 'infinite'
  String get healthStatus {
    if (isInfiniteRunway) return 'infinite';
    if (runwayDays < 30) return 'critical';
    if (runwayDays < 90) return 'warning';
    if (runwayDays < 180) return 'healthy';
    return 'strong';
  }

  Map<String, dynamic> toMap() {
    return {
      'liquidAssets': liquidAssets,
      'periodDays': periodDays,
      'totalInflow': totalInflow,
      'totalOutflow': totalOutflow,
      'avgDailyOutflow': avgDailyOutflow,
      'avgWeeklyOutflow': avgWeeklyOutflow,
      'avgMonthlyOutflow': avgMonthlyOutflow,
      'avgDailyInflow': avgDailyInflow,
      'avgWeeklyInflow': avgWeeklyInflow,
      'avgMonthlyInflow': avgMonthlyInflow,
      'runwayDays': runwayDays,
      'isInfiniteRunway': isInfiniteRunway,
      'healthStatus': healthStatus,
    };
  }

  factory RunwayMetrics.fromMap(Map<String, dynamic> map) {
    return RunwayMetrics(
      liquidAssets: (map['liquidAssets'] as num?)?.toDouble() ?? 0.0,
      periodDays: (map['periodDays'] as num?)?.toInt() ?? 30,
      totalInflow: (map['totalInflow'] as num?)?.toDouble() ?? 0.0,
      totalOutflow: (map['totalOutflow'] as num?)?.toDouble() ?? 0.0,
      avgDailyOutflow: (map['avgDailyOutflow'] as num?)?.toDouble() ?? 0.0,
      avgWeeklyOutflow: (map['avgWeeklyOutflow'] as num?)?.toDouble() ?? 0.0,
      avgMonthlyOutflow: (map['avgMonthlyOutflow'] as num?)?.toDouble() ?? 0.0,
      avgDailyInflow: (map['avgDailyInflow'] as num?)?.toDouble() ?? 0.0,
      avgWeeklyInflow: (map['avgWeeklyInflow'] as num?)?.toDouble() ?? 0.0,
      avgMonthlyInflow: (map['avgMonthlyInflow'] as num?)?.toDouble() ?? 0.0,
      runwayDays: (map['runwayDays'] as num?)?.toInt() ?? 0,
      isInfiniteRunway: map['isInfiniteRunway'] == true || (map['is_infinite_runway'] as int?) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunwayMetrics &&
          runtimeType == other.runtimeType &&
          runwayDays == other.runwayDays &&
          isInfiniteRunway == other.isInfiniteRunway &&
          liquidAssets == other.liquidAssets;

  @override
  int get hashCode => runwayDays.hashCode ^ isInfiniteRunway.hashCode ^ liquidAssets.hashCode;

  @override
  String toString() =>
      'RunwayMetrics(days: ${isInfiniteRunway ? "∞" : runwayDays}, health: $healthStatus, liquid: $liquidAssets)';
}

/// Comprehensive master financial report holding all analytics for a period
class FinancialReport {
  final String id;
  final String title;
  final String period; // 'this_month', 'last_month', etc.
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  final CashFlowReport cashFlow;
  final RunwayMetrics runway;
  final List<CategorySpendingReportItem> categorySpendings;
  final double totalNetWorth;
  final double totalAssets;
  final double totalLiabilities;
  final int transactionCount;

  const FinancialReport({
    required this.id,
    required this.title,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    required this.cashFlow,
    required this.runway,
    this.categorySpendings = const [],
    this.totalNetWorth = 0.0,
    this.totalAssets = 0.0,
    this.totalLiabilities = 0.0,
    this.transactionCount = 0,
  });

  FinancialReport copyWith({
    String? id,
    String? title,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? generatedAt,
    CashFlowReport? cashFlow,
    RunwayMetrics? runway,
    List<CategorySpendingReportItem>? categorySpendings,
    double? totalNetWorth,
    double? totalAssets,
    double? totalLiabilities,
    int? transactionCount,
  }) {
    return FinancialReport(
      id: id ?? this.id,
      title: title ?? this.title,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      generatedAt: generatedAt ?? this.generatedAt,
      cashFlow: cashFlow ?? this.cashFlow,
      runway: runway ?? this.runway,
      categorySpendings: categorySpendings ?? this.categorySpendings,
      totalNetWorth: totalNetWorth ?? this.totalNetWorth,
      totalAssets: totalAssets ?? this.totalAssets,
      totalLiabilities: totalLiabilities ?? this.totalLiabilities,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'period': period,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'generatedAt': generatedAt.toIso8601String(),
      'cashFlow': cashFlow.toMap(),
      'runway': runway.toMap(),
      'categorySpendings': categorySpendings.map((c) => c.toMap()).toList(),
      'totalNetWorth': totalNetWorth,
      'totalAssets': totalAssets,
      'totalLiabilities': totalLiabilities,
      'transactionCount': transactionCount,
    };
  }

  factory FinancialReport.fromMap(Map<String, dynamic> map) {
    return FinancialReport(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? 'Financial Report') as String,
      period: (map['period'] ?? 'custom') as String,
      startDate: DateTime.tryParse(map['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(map['endDate']?.toString() ?? '') ?? DateTime.now(),
      generatedAt: DateTime.tryParse(map['generatedAt']?.toString() ?? '') ?? DateTime.now(),
      cashFlow: map['cashFlow'] != null
          ? CashFlowReport.fromMap(map['cashFlow'] as Map<String, dynamic>)
          : CashFlowReport(
              startDate: DateTime.now(),
              endDate: DateTime.now(),
              totalIncome: 0.0,
              totalExpense: 0.0,
            ),
      runway: map['runway'] != null
          ? RunwayMetrics.fromMap(map['runway'] as Map<String, dynamic>)
          : RunwayMetrics.compute(liquidAssets: 0.0, totalInflow: 0.0, totalOutflow: 0.0, daysInPeriod: 30),
      categorySpendings: (map['categorySpendings'] as List<dynamic>?)
              ?.map((e) => CategorySpendingReportItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalNetWorth: (map['totalNetWorth'] as num?)?.toDouble() ?? 0.0,
      totalAssets: (map['totalAssets'] as num?)?.toDouble() ?? 0.0,
      totalLiabilities: (map['totalLiabilities'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Exports key report statistics to CSV format
  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Financial Report: $title');
    buffer.writeln('Period: $period (${startDate.toIso8601String().substring(0, 10)} to ${endDate.toIso8601String().substring(0, 10)})');
    buffer.writeln('Generated At: ${generatedAt.toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Income,${cashFlow.totalIncome}');
    buffer.writeln('Total Expense,${cashFlow.totalExpense}');
    buffer.writeln('Net Savings,${cashFlow.netSavings}');
    buffer.writeln('Savings Rate %,${cashFlow.savingsRate.toStringAsFixed(2)}%');
    buffer.writeln('Liquid Assets,${runway.liquidAssets}');
    buffer.writeln('Runway Days,${runway.isInfiniteRunway ? "Infinite" : runway.runwayDays}');
    buffer.writeln('Runway Months,${runway.isInfiniteRunway ? "Infinite" : runway.runwayMonths.toStringAsFixed(1)}');
    buffer.writeln('Runway Health,${runway.healthStatus}');
    buffer.writeln('Net Worth,$totalNetWorth');
    buffer.writeln('');
    buffer.writeln('Category Spending Breakdown');
    buffer.writeln('Category,Amount,Percentage');
    for (final item in categorySpendings) {
      buffer.writeln('${item.categoryName},${item.amount},${item.percentage.toStringAsFixed(2)}%');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialReport &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => id.hashCode ^ startDate.hashCode ^ endDate.hashCode;

  @override
  String toString() =>
      'FinancialReport(title: $title, period: $period, income: ${cashFlow.totalIncome}, expense: ${cashFlow.totalExpense})';
}
