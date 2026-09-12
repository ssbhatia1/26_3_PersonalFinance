class AuditLog {
  final String id;
  final String entityType;
  final String entityId;
  final String action; // 'CREATE', 'UPDATE', 'DELETE', 'RECONCILE', 'RESTORE'
  final String? previousValueJson;
  final String? newValueJson;
  final DateTime timestamp;

  const AuditLog({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.previousValueJson,
    this.newValueJson,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'previous_value_json': previousValueJson,
      'new_value_json': newValueJson,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      action: map['action'] as String,
      previousValueJson: map['previous_value_json'] as String?,
      newValueJson: map['new_value_json'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
