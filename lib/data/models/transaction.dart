class TransactionModel {
  final String id;
  final String sourceAccountId;
  final String? destinationAccountId;
  final String type; // 'income', 'expense', 'transfer', 'refund', 'reversal', 'adjustment'
  final String? categoryId;
  final double amount;
  final DateTime date;
  final String? description;
  final String? payeePayer;
  final String? paymentMethod;
  final String? referenceNumber;
  final String status; // 'completed', 'pending', 'cancelled', 'reversed'
  final String? isRecurringInstanceOf;
  final String? notes;
  final bool isReconciled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  // Joined/Display helpers (populated from SQL query joins)
  final String? sourceAccountName;
  final String? destinationAccountName;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final int attachmentCount;

  const TransactionModel({
    required this.id,
    required this.sourceAccountId,
    this.destinationAccountId,
    required this.type,
    this.categoryId,
    required this.amount,
    required this.date,
    this.description,
    this.payeePayer,
    this.paymentMethod,
    this.referenceNumber,
    this.status = 'completed',
    this.isRecurringInstanceOf,
    this.notes,
    this.isReconciled = false,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.sourceAccountName,
    this.destinationAccountName,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.attachmentCount = 0,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isTransfer => type == 'transfer';
  bool get isRefund => type == 'refund';
  bool get isReversal => type == 'reversal';
  bool get isAdjustment => type == 'adjustment';

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';
  bool get isReversed => status == 'reversed';

  TransactionModel copyWith({
    String? id,
    String? sourceAccountId,
    String? destinationAccountId,
    String? type,
    String? categoryId,
    double? amount,
    DateTime? date,
    String? description,
    String? payeePayer,
    String? paymentMethod,
    String? referenceNumber,
    String? status,
    String? isRecurringInstanceOf,
    String? notes,
    bool? isReconciled,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? sourceAccountName,
    String? destinationAccountName,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    int? attachmentCount,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      payeePayer: payeePayer ?? this.payeePayer,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      status: status ?? this.status,
      isRecurringInstanceOf: isRecurringInstanceOf ?? this.isRecurringInstanceOf,
      notes: notes ?? this.notes,
      isReconciled: isReconciled ?? this.isReconciled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      sourceAccountName: sourceAccountName ?? this.sourceAccountName,
      destinationAccountName: destinationAccountName ?? this.destinationAccountName,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      attachmentCount: attachmentCount ?? this.attachmentCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_account_id': sourceAccountId,
      'destination_account_id': destinationAccountId,
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'payee_payer': payeePayer,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'status': status,
      'is_recurring_instance_of': isRecurringInstanceOf,
      'notes': notes,
      'is_reconciled': isReconciled ? 1 : 0,
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

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: (map['id'] ?? '') as String,
      sourceAccountId: (map['source_account_id'] ?? '') as String,
      destinationAccountId: map['destination_account_id'] as String?,
      type: (map['type'] ?? 'expense') as String,
      categoryId: map['category_id'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      description: map['description'] as String?,
      payeePayer: map['payee_payer'] as String?,
      paymentMethod: map['payment_method'] as String?,
      referenceNumber: map['reference_number'] as String?,
      status: (map['status'] as String?) ?? 'completed',
      isRecurringInstanceOf: map['is_recurring_instance_of'] as String?,
      notes: map['notes'] as String?,
      isReconciled: _parseBool(map['is_reconciled']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: _parseBool(map['is_deleted']),
      sourceAccountName: map['source_account_name'] as String?,
      destinationAccountName: map['destination_account_name'] as String?,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as String?,
      attachmentCount: (map['attachment_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sourceAccountId == other.sourceAccountId &&
          type == other.type &&
          amount == other.amount &&
          date == other.date;

  @override
  int get hashCode => id.hashCode ^ sourceAccountId.hashCode ^ type.hashCode ^ amount.hashCode ^ date.hashCode;

  @override
  String toString() =>
      'TransactionModel(id: $id, $type: $amount, date: ${date.toIso8601String().substring(0, 10)}, status: $status)';
}
