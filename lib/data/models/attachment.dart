class AttachmentModel {
  final String id;
  final String? transactionId;
  final String? accountId;
  final String fileName;
  final String filePath;
  final String fileType;
  final int fileSize;
  final DateTime uploadedAt;

  const AttachmentModel({
    required this.id,
    this.transactionId,
    this.accountId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
  });

  /// True if the attachment is an image format
  bool get isImage {
    final lowerName = fileName.toLowerCase();
    final lowerType = fileType.toLowerCase();
    return lowerType.startsWith('image/') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.bmp');
  }

  /// True if the attachment is a PDF document
  bool get isPdf {
    final lowerName = fileName.toLowerCase();
    final lowerType = fileType.toLowerCase();
    return lowerType == 'application/pdf' || lowerName.endsWith('.pdf');
  }

  /// True if the attachment is plain text, CSV, JSON, or code
  bool get isText {
    final lowerName = fileName.toLowerCase();
    final lowerType = fileType.toLowerCase();
    return lowerType.startsWith('text/') ||
        lowerType.contains('csv') ||
        lowerType.contains('json') ||
        lowerName.endsWith('.txt') ||
        lowerName.endsWith('.csv') ||
        lowerName.endsWith('.json') ||
        lowerName.endsWith('.log') ||
        lowerName.endsWith('.md');
  }

  /// Uppercase extension for badges (e.g. 'PDF', 'PNG', 'DOC')
  String get fileExtension {
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < fileName.length - 1) {
      return fileName.substring(dotIdx + 1).toUpperCase();
    }
    if (fileType.contains('/')) {
      return fileType.split('/').last.toUpperCase();
    }
    return 'FILE';
  }

  /// Human-readable file size (e.g., 250 B, 1.4 KB, 3.2 MB)
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'account_id': accountId,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }

  factory AttachmentModel.fromMap(Map<String, dynamic> map) {
    return AttachmentModel(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String?,
      accountId: map['account_id'] as String?,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      fileType: map['file_type'] as String,
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      uploadedAt: DateTime.parse(map['uploaded_at'] as String),
    );
  }

  AttachmentModel copyWith({
    String? id,
    String? transactionId,
    String? accountId,
    String? fileName,
    String? filePath,
    String? fileType,
    int? fileSize,
    DateTime? uploadedAt,
  }) {
    return AttachmentModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}
