class Account {
  final String id;
  final String? userId;
  final String? accountToken;
  final String name;
  final String type;
  final String? institution;
  final String? maskedReference;
  final double openingBalance;
  final double currentBalance;
  final String currency;
  final String status;
  final double creditLimit;
  final double interestRate;
  final DateTime? openedAt;
  final String? notes;
  final bool isDeleted;

  const Account({
    required this.id,
    this.userId,
    this.accountToken,
    required this.name,
    required this.type,
    this.institution,
    this.maskedReference,
    required this.openingBalance,
    required this.currentBalance,
    this.currency = 'INR',
    this.status = 'active',
    this.creditLimit = 0.0,
    this.interestRate = 0.0,
    this.openedAt,
    this.notes,
    this.isDeleted = false,
  });

  /// Canonical cryptographic token for this account
  String get token => (accountToken != null && accountToken!.isNotEmpty)
      ? accountToken!
      : 'tok_acc_${id.replaceAll('-', '').padRight(16, '0').substring(0, 16)}';

  bool get isCreditCard => type.toLowerCase().contains('credit card');
  bool get isLoan => type.toLowerCase().contains('loan') || type.toLowerCase().contains('borrowed');
  bool get isLiability => isCreditCard || isLoan;
  bool get isAsset => !isLiability;

  /// For credit cards: available credit limit = credit limit + current balance (where balance is typically negative when outstanding)
  double get availableCredit {
    if (!isCreditCard) return currentBalance;
    return creditLimit + currentBalance;
  }

  Account copyWith({
    String? id,
    String? userId,
    String? accountToken,
    String? name,
    String? type,
    String? institution,
    String? maskedReference,
    double? openingBalance,
    double? currentBalance,
    String? currency,
    String? status,
    double? creditLimit,
    double? interestRate,
    DateTime? openedAt,
    String? notes,
    bool? isDeleted,
  }) {
    return Account(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountToken: accountToken ?? this.accountToken,
      name: name ?? this.name,
      type: type ?? this.type,
      institution: institution ?? this.institution,
      maskedReference: maskedReference ?? this.maskedReference,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      creditLimit: creditLimit ?? this.creditLimit,
      interestRate: interestRate ?? this.interestRate,
      openedAt: openedAt ?? this.openedAt,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'account_token': accountToken ?? token,
      'name': name,
      'type': type,
      'institution': institution,
      'masked_reference': maskedReference,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'currency': currency,
      'status': status,
      'credit_limit': creditLimit,
      'interest_rate': interestRate,
      'opened_at': openedAt?.toIso8601String(),
      'notes': notes,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      accountToken: map['account_token'] as String?,
      name: map['name'] as String,
      type: map['type'] as String,
      institution: map['institution'] as String?,
      maskedReference: map['masked_reference'] as String?,
      openingBalance: (map['opening_balance'] as num).toDouble(),
      currentBalance: (map['current_balance'] as num).toDouble(),
      currency: (map['currency'] as String?) ?? 'INR',
      status: (map['status'] as String?) ?? 'active',
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      openedAt: map['opened_at'] != null ? DateTime.tryParse(map['opened_at'] as String) : null,
      notes: map['notes'] as String?,
      isDeleted: (map['is_deleted'] as int?) == 1,
    );
  }
}

