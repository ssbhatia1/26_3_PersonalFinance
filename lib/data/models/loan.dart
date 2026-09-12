import 'dart:math';

class Loan {
  final String id;
  final String accountId;
  final String borrowerLenderName;
  final String loanType; // 'borrowed' (Liability) or 'lent' (Asset / Receivable)
  final double principal;
  final double interestRate; // Annual % rate, e.g. 8.5
  final bool isFlexibleInterest;
  final int termMonths;
  final double outstandingBalance;
  final DateTime startDate;
  final double emiAmount;
  final String status; // 'active', 'closed'

  // Joined display properties
  final String? accountName;

  const Loan({
    required this.id,
    required this.accountId,
    required this.borrowerLenderName,
    required this.loanType,
    required this.principal,
    this.interestRate = 0.0,
    this.isFlexibleInterest = false,
    this.termMonths = 12,
    required this.outstandingBalance,
    required this.startDate,
    this.emiAmount = 0.0,
    this.status = 'active',
    this.accountName,
  });

  bool get isBorrowed => loanType == 'borrowed';
  bool get isLent => loanType == 'lent';
  bool get isActive => status == 'active';
  bool get isClosed => status == 'closed';

  double get paidAmount => (principal - outstandingBalance).clamp(0.0, principal);
  double get progressPercentage => principal > 0 ? (paidAmount / principal).clamp(0.0, 1.0) : 0.0;

  /// Expected loan maturity date based on start date and term months
  DateTime get maturityDate {
    final months = termMonths > 0 ? termMonths : 12;
    final newYear = startDate.year + (startDate.month + months - 1) ~/ 12;
    final newMonth = (startDate.month + months - 1) % 12 + 1;
    final daysInTargetMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = min(startDate.day, daysInTargetMonth);
    return DateTime(newYear, newMonth, newDay, startDate.hour, startDate.minute, startDate.second);
  }

  /// Whether the loan is active and passed its expected maturity date
  bool get isOverdue => isActive && DateTime.now().isAfter(maturityDate) && outstandingBalance > 0.01;

  /// Approximate remaining months to maturity
  int get remainingMonths {
    final now = DateTime.now();
    if (now.isAfter(maturityDate)) return 0;
    return max(0, (maturityDate.year - now.year) * 12 + (maturityDate.month - now.month));
  }

  /// Standard monthly reducing EMI estimation
  double get calculatedEmi {
    if (emiAmount > 0) return emiAmount;
    if (principal <= 0) return 0.0;
    final n = termMonths > 0 ? termMonths : 12;
    if (interestRate <= 0) return principal / n;

    final r = (interestRate / 12) / 100;
    final powFactor = pow(1 + r, n).toDouble();
    if (powFactor == 1.0) return principal / n;
    return (principal * r * powFactor) / (powFactor - 1);
  }

  /// Estimated total interest over entire loan tenure
  double get estimatedTotalInterest {
    final emi = calculatedEmi;
    final n = termMonths > 0 ? termMonths : 12;
    final totalPayment = emi * n;
    return max(0.0, totalPayment - principal);
  }

  Loan copyWith({
    String? id,
    String? accountId,
    String? borrowerLenderName,
    String? loanType,
    double? principal,
    double? interestRate,
    bool? isFlexibleInterest,
    int? termMonths,
    double? outstandingBalance,
    DateTime? startDate,
    double? emiAmount,
    String? status,
    String? accountName,
  }) {
    return Loan(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      borrowerLenderName: borrowerLenderName ?? this.borrowerLenderName,
      loanType: loanType ?? this.loanType,
      principal: principal ?? this.principal,
      interestRate: interestRate ?? this.interestRate,
      isFlexibleInterest: isFlexibleInterest ?? this.isFlexibleInterest,
      termMonths: termMonths ?? this.termMonths,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      startDate: startDate ?? this.startDate,
      emiAmount: emiAmount ?? this.emiAmount,
      status: status ?? this.status,
      accountName: accountName ?? this.accountName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'borrower_lender_name': borrowerLenderName,
      'loan_type': loanType,
      'principal': principal,
      'interest_rate': interestRate,
      'is_flexible_interest': isFlexibleInterest ? 1 : 0,
      'term_months': termMonths,
      'outstanding_balance': outstandingBalance,
      'start_date': startDate.toIso8601String(),
      'emi_amount': emiAmount,
      'status': status,
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

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: (map['id'] ?? '') as String,
      accountId: (map['account_id'] ?? '') as String,
      borrowerLenderName: (map['borrower_lender_name'] ?? 'Unknown') as String,
      loanType: (map['loan_type'] ?? 'borrowed') as String,
      principal: (map['principal'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      isFlexibleInterest: _parseBool(map['is_flexible_interest']),
      termMonths: (map['term_months'] as num?)?.toInt() ?? 12,
      outstandingBalance: (map['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      startDate: DateTime.tryParse(map['start_date']?.toString() ?? '') ?? DateTime.now(),
      emiAmount: (map['emi_amount'] as num?)?.toDouble() ?? 0.0,
      status: (map['status'] as String?) ?? 'active',
      accountName: map['account_name'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Loan &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          accountId == other.accountId &&
          outstandingBalance == other.outstandingBalance &&
          status == other.status;

  @override
  int get hashCode => id.hashCode ^ accountId.hashCode ^ outstandingBalance.hashCode ^ status.hashCode;

  @override
  String toString() =>
      'Loan(id: $id, $loanType, $borrowerLenderName, principal: $principal, balance: $outstandingBalance, status: $status)';
}
