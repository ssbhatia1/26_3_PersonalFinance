class LoanRepayment {
  final String id;
  final String loanId;
  final double paymentAmount;
  final double principalAmount;
  final double interestAmount;
  final DateTime paymentDate;
  final String accountId;
  final String? accountName;
  final String? transactionId;
  final String? notes;
  final DateTime createdAt;

  const LoanRepayment({
    required this.id,
    required this.loanId,
    required this.paymentAmount,
    required this.principalAmount,
    this.interestAmount = 0.0,
    required this.paymentDate,
    required this.accountId,
    this.accountName,
    this.transactionId,
    this.notes,
    required this.createdAt,
  });

  LoanRepayment copyWith({
    String? id,
    String? loanId,
    double? paymentAmount,
    double? principalAmount,
    double? interestAmount,
    DateTime? paymentDate,
    String? accountId,
    String? accountName,
    String? transactionId,
    String? notes,
    DateTime? createdAt,
  }) {
    return LoanRepayment(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      principalAmount: principalAmount ?? this.principalAmount,
      interestAmount: interestAmount ?? this.interestAmount,
      paymentDate: paymentDate ?? this.paymentDate,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loan_id': loanId,
      'payment_amount': paymentAmount,
      'principal_amount': principalAmount,
      'interest_amount': interestAmount,
      'payment_date': paymentDate.toIso8601String(),
      'account_id': accountId,
      'transaction_id': transactionId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LoanRepayment.fromMap(Map<String, dynamic> map) {
    return LoanRepayment(
      id: (map['id'] ?? '') as String,
      loanId: (map['loan_id'] ?? '') as String,
      paymentAmount: (map['payment_amount'] as num?)?.toDouble() ?? 0.0,
      principalAmount: (map['principal_amount'] as num?)?.toDouble() ?? 0.0,
      interestAmount: (map['interest_amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: DateTime.tryParse(map['payment_date']?.toString() ?? '') ?? DateTime.now(),
      accountId: (map['account_id'] ?? '') as String,
      accountName: map['account_name'] as String?,
      transactionId: map['transaction_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanRepayment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          loanId == other.loanId &&
          paymentAmount == other.paymentAmount;

  @override
  int get hashCode => id.hashCode ^ loanId.hashCode ^ paymentAmount.hashCode;

  @override
  String toString() =>
      'LoanRepayment(id: $id, loanId: $loanId, payment: $paymentAmount, principal: $principalAmount, interest: $interestAmount)';
}
