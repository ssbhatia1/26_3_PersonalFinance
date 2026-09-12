import 'dart:math';

enum InvestmentType {
  fd('Fixed Deposit', 'fd'),
  rd('Recurring Deposit', 'rd'),
  mutualFund('Mutual Funds', 'mutual_fund'),
  stock('Stocks', 'stock'),
  bond('Bonds', 'bond'),
  other('Other Investment', 'other');

  final String displayName;
  final String code;
  const InvestmentType(this.displayName, this.code);

  static InvestmentType fromString(String? value) {
    if (value == null || value.trim().isEmpty) return InvestmentType.other;
    final clean = value.trim().toLowerCase();
    final normalized = clean.replaceAll(' ', '_').replaceAll('-', '_');
    return InvestmentType.values.firstWhere(
      (e) =>
          e.code.toLowerCase() == normalized ||
          e.name.toLowerCase() == normalized ||
          e.displayName.toLowerCase() == clean,
      orElse: () => InvestmentType.other,
    );
  }
}

class Investment {
  final String id;
  final String name;
  final InvestmentType type;
  final String? accountId;
  final double investedAmount;
  final double currentValue;
  final double expectedReturnRate; // percentage e.g. 7.5
  final DateTime startDate;
  final DateTime? maturityDate;
  final String? frequency; // 'One-time', 'Monthly', etc.
  final double? maturityAmount;
  final String? notes;
  final String status; // 'active', 'matured', 'closed'
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  // Joined display properties
  final String? accountName;

  const Investment({
    required this.id,
    required this.name,
    required this.type,
    this.accountId,
    required this.investedAmount,
    required this.currentValue,
    this.expectedReturnRate = 0.0,
    required this.startDate,
    this.maturityDate,
    this.frequency,
    this.maturityAmount,
    this.notes,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.accountName,
  });

  /// Profit or Loss amount
  double get profitLoss => currentValue - investedAmount;

  /// Profit or Loss %
  double get profitLossPercentage {
    if (investedAmount <= 0) return 0.0;
    return (profitLoss / investedAmount) * 100;
  }

  /// Expected return amount at maturity or annual return
  double get expectedReturns {
    if (maturityAmount != null && maturityAmount! > investedAmount) {
      return maturityAmount! - investedAmount;
    }
    if (expectedReturnRate > 0) {
      if (maturityDate != null && maturityDate!.isAfter(startDate)) {
        final years = maturityDate!.difference(startDate).inDays / 365.25;
        return investedAmount * (expectedReturnRate / 100) * (years > 0 ? years : 1.0);
      }
      return investedAmount * (expectedReturnRate / 100);
    }
    return profitLoss > 0 ? profitLoss : 0.0;
  }

  bool get isProfitable => profitLoss >= 0;
  bool get isActive => status == 'active' && !isDeleted;
  bool get isMatured => status == 'matured' || (maturityDate != null && DateTime.now().isAfter(maturityDate!));
  bool get isClosed => status == 'closed';

  /// Holding duration in days
  int get holdingPeriodDays => max(0, DateTime.now().difference(startDate).inDays);

  /// Approximate holding duration in months
  int get holdingPeriodMonths => (holdingPeriodDays / 30.4375).round();

  /// Estimated CAGR (Compound Annual Growth Rate) %
  double get cagrPercentage {
    if (investedAmount <= 0 || currentValue <= 0) return 0.0;
    final days = holdingPeriodDays;
    if (days < 30) return profitLossPercentage;
    final years = days / 365.25;
    if (years <= 0) return 0.0;
    return (pow(currentValue / investedAmount, 1 / years).toDouble() - 1.0) * 100;
  }

  Investment copyWith({
    String? id,
    String? name,
    InvestmentType? type,
    String? accountId,
    double? investedAmount,
    double? currentValue,
    double? expectedReturnRate,
    DateTime? startDate,
    DateTime? maturityDate,
    String? frequency,
    double? maturityAmount,
    String? notes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? accountName,
  }) {
    return Investment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      investedAmount: investedAmount ?? this.investedAmount,
      currentValue: currentValue ?? this.currentValue,
      expectedReturnRate: expectedReturnRate ?? this.expectedReturnRate,
      startDate: startDate ?? this.startDate,
      maturityDate: maturityDate ?? this.maturityDate,
      frequency: frequency ?? this.frequency,
      maturityAmount: maturityAmount ?? this.maturityAmount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      accountName: accountName ?? this.accountName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.code,
      'account_id': accountId,
      'invested_amount': investedAmount,
      'current_value': currentValue,
      'expected_return_rate': expectedReturnRate,
      'start_date': startDate.toIso8601String(),
      'maturity_date': maturityDate?.toIso8601String(),
      'frequency': frequency,
      'maturity_amount': maturityAmount,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
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

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      type: InvestmentType.fromString(map['type'] as String?),
      accountId: map['account_id'] as String?,
      investedAmount: (map['invested_amount'] as num?)?.toDouble() ?? 0.0,
      currentValue: (map['current_value'] as num?)?.toDouble() ?? 0.0,
      expectedReturnRate: (map['expected_return_rate'] as num?)?.toDouble() ?? 0.0,
      startDate: DateTime.tryParse(map['start_date']?.toString() ?? '') ?? DateTime.now(),
      maturityDate: map['maturity_date'] != null ? DateTime.tryParse(map['maturity_date'] as String) : null,
      frequency: map['frequency'] as String?,
      maturityAmount: (map['maturity_amount'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: _parseBool(map['is_deleted']),
      accountName: map['account_name'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Investment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          investedAmount == other.investedAmount &&
          currentValue == other.currentValue &&
          status == other.status;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ investedAmount.hashCode ^ currentValue.hashCode ^ status.hashCode;

  @override
  String toString() =>
      'Investment(id: $id, $name, type: ${type.displayName}, invested: $investedAmount, current: $currentValue, status: $status)';
}
