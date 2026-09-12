class AccountAdjustment {
  final String id;
  final String accountId;
  final double previousBalance;
  final double newBalance;
  final double adjustmentAmount;
  final String adjustmentType; // 'increase' or 'decrease'
  final String reason;
  final DateTime createdAt;
  final String? transactionId;

  const AccountAdjustment({
    required this.id,
    required this.accountId,
    required this.previousBalance,
    required this.newBalance,
    required this.adjustmentAmount,
    required this.adjustmentType,
    required this.reason,
    required this.createdAt,
    this.transactionId,
  });

  bool get isIncrease => adjustmentType == 'increase';

  AccountAdjustment copyWith({
    String? id,
    String? accountId,
    double? previousBalance,
    double? newBalance,
    double? adjustmentAmount,
    String? adjustmentType,
    String? reason,
    DateTime? createdAt,
    String? transactionId,
  }) {
    return AccountAdjustment(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      previousBalance: previousBalance ?? this.previousBalance,
      newBalance: newBalance ?? this.newBalance,
      adjustmentAmount: adjustmentAmount ?? this.adjustmentAmount,
      adjustmentType: adjustmentType ?? this.adjustmentType,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      transactionId: transactionId ?? this.transactionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'previous_balance': previousBalance,
      'new_balance': newBalance,
      'adjustment_amount': adjustmentAmount,
      'adjustment_type': adjustmentType,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'transaction_id': transactionId,
    };
  }

  factory AccountAdjustment.fromMap(Map<String, dynamic> map) {
    return AccountAdjustment(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      previousBalance: (map['previous_balance'] as num?)?.toDouble() ?? 0.0,
      newBalance: (map['new_balance'] as num?)?.toDouble() ?? 0.0,
      adjustmentAmount: (map['adjustment_amount'] as num?)?.toDouble() ?? 0.0,
      adjustmentType: map['adjustment_type'] as String? ?? 'increase',
      reason: map['reason'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      transactionId: map['transaction_id'] as String?,
    );
  }
}
