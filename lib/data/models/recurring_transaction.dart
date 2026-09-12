import 'dart:math';

class RecurringTransaction {
  final String id;
  final String title;
  final String sourceAccountId;
  final String? destinationAccountId;
  final String type; // 'income', 'expense', 'transfer'
  final String? categoryId;
  final double amount;
  final String frequency; // 'once', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly', 'custom'
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextExecutionDate;
  final bool isActive;
  final DateTime? lastExecutedAt;
  final bool isFlexibleAmount;
  final int intervalCount;
  final String intervalUnit; // 'days', 'weeks', 'months', 'years'

  // Joined display properties
  final String? sourceAccountName;
  final String? destinationAccountName;
  final String? categoryName;

  const RecurringTransaction({
    required this.id,
    required this.title,
    required this.sourceAccountId,
    this.destinationAccountId,
    required this.type,
    this.categoryId,
    required this.amount,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.nextExecutionDate,
    this.isActive = true,
    this.lastExecutedAt,
    this.isFlexibleAmount = false,
    this.intervalCount = 1,
    this.intervalUnit = 'months',
    this.sourceAccountName,
    this.destinationAccountName,
    this.categoryName,
  });

  bool get isIncome => type.toLowerCase() == 'income';
  bool get isExpense => type.toLowerCase() == 'expense';
  bool get isTransfer => type.toLowerCase() == 'transfer';

  bool get isOneTime => frequency.toLowerCase() == 'once';
  bool get isCustom => frequency.toLowerCase() == 'custom';

  /// Schedule lifecycle helpers
  bool get isScheduled => isActive && (endDate == null || nextExecutionDate.isBefore(endDate!));
  bool get isExpired => endDate != null && nextExecutionDate.isAfter(endDate!);
  bool get hasEnded => endDate != null && DateTime.now().isAfter(endDate!);
  int get daysUntilNext => nextExecutionDate.difference(DateTime.now()).inDays;
  bool isDueSoon([int withinDays = 3]) => daysUntilNext <= withinDays && daysUntilNext >= 0;
  bool get isOverdue => isActive && nextExecutionDate.isBefore(DateTime.now());

  String get frequencyDisplayLabel {
    switch (frequency.toLowerCase()) {
      case 'once':
        return 'One-Time';
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'quarterly':
        return 'Quarterly';
      case 'yearly':
        return 'Yearly';
      case 'custom':
        final unit = intervalCount == 1
            ? (intervalUnit.endsWith('s') ? intervalUnit.substring(0, intervalUnit.length - 1) : intervalUnit)
            : (intervalUnit.endsWith('s') ? intervalUnit : '${intervalUnit}s');
        return 'Every $intervalCount $unit';
      case 'monthly':
      default:
        return 'Monthly';
    }
  }

  /// Safely advances date by N months while clamping to the last valid day of the target month.
  /// Prevents Dart's default rollover (e.g. Jan 31 + 1 month becoming March 3).
  static DateTime _addMonthsSafe(DateTime date, int monthsToAdd) {
    final newYear = date.year + (date.month + monthsToAdd - 1) ~/ 12;
    final newMonth = (date.month + monthsToAdd - 1) % 12 + 1;
    final daysInTargetMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = min(date.day, daysInTargetMonth);
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
  }

  DateTime calculateNextDate(DateTime fromDate) {
    switch (frequency.toLowerCase()) {
      case 'once':
        return fromDate;
      case 'daily':
        return fromDate.add(const Duration(days: 1));
      case 'weekly':
        return fromDate.add(const Duration(days: 7));
      case 'quarterly':
        return _addMonthsSafe(fromDate, 3);
      case 'yearly':
        return _addMonthsSafe(fromDate, 12);
      case 'custom':
        final count = intervalCount > 0 ? intervalCount : 1;
        switch (intervalUnit.toLowerCase()) {
          case 'days':
          case 'day':
            return fromDate.add(Duration(days: count));
          case 'weeks':
          case 'week':
            return fromDate.add(Duration(days: 7 * count));
          case 'years':
          case 'year':
            return _addMonthsSafe(fromDate, 12 * count);
          case 'months':
          case 'month':
          default:
            return _addMonthsSafe(fromDate, count);
        }
      case 'monthly':
      default:
        return _addMonthsSafe(fromDate, 1);
    }
  }

  RecurringTransaction copyWith({
    String? id,
    String? title,
    String? sourceAccountId,
    String? destinationAccountId,
    String? type,
    String? categoryId,
    double? amount,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextExecutionDate,
    bool? isActive,
    DateTime? lastExecutedAt,
    bool? isFlexibleAmount,
    int? intervalCount,
    String? intervalUnit,
    String? sourceAccountName,
    String? destinationAccountName,
    String? categoryName,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextExecutionDate: nextExecutionDate ?? this.nextExecutionDate,
      isActive: isActive ?? this.isActive,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      isFlexibleAmount: isFlexibleAmount ?? this.isFlexibleAmount,
      intervalCount: intervalCount ?? this.intervalCount,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      sourceAccountName: sourceAccountName ?? this.sourceAccountName,
      destinationAccountName: destinationAccountName ?? this.destinationAccountName,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'source_account_id': sourceAccountId,
      'destination_account_id': destinationAccountId,
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'frequency': frequency,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'next_execution_date': nextExecutionDate.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'last_executed_at': lastExecutedAt?.toIso8601String(),
      'is_flexible_amount': isFlexibleAmount ? 1 : 0,
      'interval_count': intervalCount,
      'interval_unit': intervalUnit,
    };
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.toLowerCase().trim();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return defaultValue;
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      sourceAccountId: (map['source_account_id'] ?? '') as String,
      destinationAccountId: map['destination_account_id'] as String?,
      type: (map['type'] ?? 'expense') as String,
      categoryId: map['category_id'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      frequency: (map['frequency'] as String?) ?? 'monthly',
      startDate: DateTime.tryParse(map['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date'].toString()) : null,
      nextExecutionDate: DateTime.tryParse(map['next_execution_date']?.toString() ?? '') ?? DateTime.now(),
      isActive: _parseBool(map['is_active'], defaultValue: true),
      lastExecutedAt: map['last_executed_at'] != null ? DateTime.tryParse(map['last_executed_at'].toString()) : null,
      isFlexibleAmount: _parseBool(map['is_flexible_amount'], defaultValue: false),
      intervalCount: (map['interval_count'] as num?)?.toInt() ?? 1,
      intervalUnit: (map['interval_unit'] as String?) ?? 'months',
      sourceAccountName: map['source_account_name'] as String?,
      destinationAccountName: map['destination_account_name'] as String?,
      categoryName: map['category_name'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          sourceAccountId == other.sourceAccountId &&
          amount == other.amount &&
          frequency == other.frequency &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^ title.hashCode ^ sourceAccountId.hashCode ^ amount.hashCode ^ frequency.hashCode ^ isActive.hashCode;

  @override
  String toString() =>
      'RecurringTransaction(id: $id, "$title", $type: $amount, frequency: $frequency, next: $nextExecutionDate, active: $isActive)';
}
