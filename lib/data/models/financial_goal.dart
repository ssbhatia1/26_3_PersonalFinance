class FinancialGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String? linkedAccountId;
  final String icon;
  final bool isCompleted;

  // Joined
  final String? linkedAccountName;

  const FinancialGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    this.linkedAccountId,
    this.icon = 'savings',
    this.isCompleted = false,
    this.linkedAccountName,
  });

  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, targetAmount);
  double get progressPercentage => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  int get daysRemaining {
    final now = DateTime.now();
    return targetDate.difference(now).inDays;
  }

  FinancialGoal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? linkedAccountId,
    String? icon,
    bool? isCompleted,
    String? linkedAccountName,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      icon: icon ?? this.icon,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedAccountName: linkedAccountName ?? this.linkedAccountName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate.toIso8601String(),
      'linked_account_id': linkedAccountId,
      'icon': icon,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory FinancialGoal.fromMap(Map<String, dynamic> map) {
    return FinancialGoal(
      id: map['id'] as String,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num?)?.toDouble() ?? 0.0,
      targetDate: DateTime.parse(map['target_date'] as String),
      linkedAccountId: map['linked_account_id'] as String?,
      icon: (map['icon'] as String?) ?? 'savings',
      isCompleted: (map['is_completed'] as int?) == 1,
      linkedAccountName: map['linked_account_name'] as String?,
    );
  }
}
