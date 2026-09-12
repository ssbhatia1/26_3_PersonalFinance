enum BudgetAlertLevel {
  normal,
  nearLimit75,
  critical90,
  overBudget100,
}

class Budget {
  final String id;
  final String? name;
  final String? categoryId;
  final String scope; // 'category', 'account', 'overall'
  final String periodType; // 'weekly', 'monthly', 'yearly', 'custom'
  final double amountLimit;
  final DateTime startDate;
  final DateTime endDate;
  final bool isRecurring;
  final bool isDeleted;

  // Joined/calculated values
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final double spentAmount;

  const Budget({
    required this.id,
    this.name,
    this.categoryId,
    this.scope = 'category',
    this.periodType = 'monthly',
    required this.amountLimit,
    required this.startDate,
    required this.endDate,
    this.isRecurring = false,
    this.isDeleted = false,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.spentAmount = 0.0,
  });

  double get remainingAmount => amountLimit - spentAmount;
  double get percentageUsed => amountLimit > 0 ? (spentAmount / amountLimit).clamp(0.0, 5.0) : 0.0;
  bool get isOverspent => spentAmount > amountLimit;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    if (categoryName != null && categoryName!.trim().isNotEmpty) return categoryName!;
    return scope == 'overall' ? 'Overall Budget' : 'Budget';
  }

  /// Total duration in days of this budget period.
  int get totalDurationDays {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = end.difference(start).inDays + 1;
    return diff > 0 ? diff : 1;
  }

  /// Number of days remaining until the budget period ends relative to today.
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.difference(today).inDays;
  }

  /// Whether this is a long-term budget (yearly or duration exceeds 60 days).
  bool get isLongTerm => periodType.toLowerCase() == 'yearly' || totalDurationDays > 60;

  /// User-friendly label for how many days this budget will stay active.
  String get remainingDaysLabel {
    final days = daysRemaining;
    if (days > 1) return '$days days left';
    if (days == 1) return '1 day left';
    if (days == 0) return 'Ends today';
    final past = -days;
    return 'Ended $past ${past == 1 ? "day" : "days"} ago';
  }

  /// Safe daily spending allowance remaining for the rest of this budget period.
  double get dailyAllowance {
    final days = daysRemaining;
    if (days > 0 && remainingAmount > 0) {
      return remainingAmount / days;
    }
    return 0.0;
  }

  BudgetAlertLevel get alertLevel {
    if (amountLimit <= 0) return BudgetAlertLevel.normal;
    final pct = spentAmount / amountLimit;
    if (pct >= 1.0) return BudgetAlertLevel.overBudget100;
    if (pct >= 0.90) return BudgetAlertLevel.critical90;
    if (pct >= 0.75) return BudgetAlertLevel.nearLimit75;
    return BudgetAlertLevel.normal;
  }

  String get statusLabel {
    switch (alertLevel) {
      case BudgetAlertLevel.overBudget100:
        return 'Over Budget';
      case BudgetAlertLevel.critical90:
        return 'Critical (90%)';
      case BudgetAlertLevel.nearLimit75:
        return 'Near Limit';
      case BudgetAlertLevel.normal:
        return 'On Track';
    }
  }

  String get alertMessage {
    switch (alertLevel) {
      case BudgetAlertLevel.overBudget100:
        final over = spentAmount - amountLimit;
        return 'Over budget by ${(over).toStringAsFixed(0)}!';
      case BudgetAlertLevel.critical90:
        return 'Critical: ${(percentageUsed * 100).toStringAsFixed(0)}% of limit reached';
      case BudgetAlertLevel.nearLimit75:
        return 'Warning: ${(percentageUsed * 100).toStringAsFixed(0)}% of limit reached';
      case BudgetAlertLevel.normal:
        return 'Healthy spending: ${(percentageUsed * 100).toStringAsFixed(0)}% used';
    }
  }

  Budget copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? scope,
    String? periodType,
    double? amountLimit,
    DateTime? startDate,
    DateTime? endDate,
    bool? isRecurring,
    bool? isDeleted,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    double? spentAmount,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      scope: scope ?? this.scope,
      periodType: periodType ?? this.periodType,
      amountLimit: amountLimit ?? this.amountLimit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isRecurring: isRecurring ?? this.isRecurring,
      isDeleted: isDeleted ?? this.isDeleted,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      spentAmount: spentAmount ?? this.spentAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'scope': scope,
      'period_type': periodType,
      'amount_limit': amountLimit,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map, {double spent = 0.0}) {
    return Budget(
      id: map['id'] as String,
      name: map['name'] as String?,
      categoryId: map['category_id'] as String?,
      scope: (map['scope'] as String?) ?? 'category',
      periodType: (map['period_type'] as String?) ?? 'monthly',
      amountLimit: (map['amount_limit'] as num).toDouble(),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isRecurring: (map['is_recurring'] as int?) == 1,
      isDeleted: (map['is_deleted'] as int?) == 1,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as String?,
      spentAmount: spent,
    );
  }
}
