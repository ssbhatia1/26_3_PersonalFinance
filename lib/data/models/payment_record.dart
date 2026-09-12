class PaymentRecordModel {
  final String id;
  final String? scheduleId;
  final String? transactionId;
  final String title;
  final String sourceAccountId;
  final String? destinationAccountId;
  final String type; // 'income', 'expense', 'transfer'
  final String? categoryId;
  final double amount;
  final bool isFlexible;
  final DateTime dueDate;
  final String status; // 'scheduled', 'pending', 'completed', 'skipped', 'failed'
  final DateTime? executionDate;
  final String? notes;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined display properties
  final String? sourceAccountName;
  final String? destinationAccountName;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  const PaymentRecordModel({
    required this.id,
    this.scheduleId,
    this.transactionId,
    required this.title,
    required this.sourceAccountId,
    this.destinationAccountId,
    required this.type,
    this.categoryId,
    required this.amount,
    this.isFlexible = false,
    required this.dueDate,
    this.status = 'scheduled',
    this.executionDate,
    this.notes,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
    this.sourceAccountName,
    this.destinationAccountName,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  bool get isScheduled => status.toLowerCase() == 'scheduled';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isSkipped => status.toLowerCase() == 'skipped';
  bool get isFailed => status.toLowerCase() == 'failed';

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isTransfer => type == 'transfer';

  PaymentRecordModel copyWith({
    String? id,
    String? scheduleId,
    String? transactionId,
    String? title,
    String? sourceAccountId,
    String? destinationAccountId,
    String? type,
    String? categoryId,
    double? amount,
    bool? isFlexible,
    DateTime? dueDate,
    String? status,
    DateTime? executionDate,
    String? notes,
    String? failureReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sourceAccountName,
    String? destinationAccountName,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
  }) {
    return PaymentRecordModel(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      transactionId: transactionId ?? this.transactionId,
      title: title ?? this.title,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      isFlexible: isFlexible ?? this.isFlexible,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      executionDate: executionDate ?? this.executionDate,
      notes: notes ?? this.notes,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceAccountName: sourceAccountName ?? this.sourceAccountName,
      destinationAccountName: destinationAccountName ?? this.destinationAccountName,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schedule_id': scheduleId,
      'transaction_id': transactionId,
      'title': title,
      'source_account_id': sourceAccountId,
      'destination_account_id': destinationAccountId,
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'is_flexible': isFlexible ? 1 : 0,
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'execution_date': executionDate?.toIso8601String(),
      'notes': notes,
      'failure_reason': failureReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PaymentRecordModel.fromMap(Map<String, dynamic> map) {
    return PaymentRecordModel(
      id: map['id'] as String,
      scheduleId: map['schedule_id'] as String?,
      transactionId: map['transaction_id'] as String?,
      title: map['title'] as String,
      sourceAccountId: map['source_account_id'] as String,
      destinationAccountId: map['destination_account_id'] as String?,
      type: map['type'] as String,
      categoryId: map['category_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      isFlexible: (map['is_flexible'] as int?) == 1,
      dueDate: DateTime.parse(map['due_date'] as String),
      status: (map['status'] as String?) ?? 'scheduled',
      executionDate: map['execution_date'] != null
          ? DateTime.tryParse(map['execution_date'] as String)
          : null,
      notes: map['notes'] as String?,
      failureReason: map['failure_reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      sourceAccountName: map['source_account_name'] as String?,
      destinationAccountName: map['destination_account_name'] as String?,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as String?,
    );
  }
}
