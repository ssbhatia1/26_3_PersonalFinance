import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/attachment.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

/// Provider for loading attachments belonging to a transaction
final transactionAttachmentsProvider =
    FutureProvider.family<List<AttachmentModel>, String>((ref, transactionId) async {
  if (transactionId.isEmpty) return [];
  final repo = ref.watch(attachmentRepositoryProvider);
  return await repo.getAttachmentsByTransaction(transactionId);
});

/// Controller for mutating attachments (adding, deleting, refreshing)
class AttachmentController {
  final Ref _ref;

  AttachmentController(this._ref);

  Future<void> deleteAttachment(String attachmentId, String transactionId) async {
    final repo = _ref.read(attachmentRepositoryProvider);
    await repo.deleteAttachment(attachmentId);
    _ref.invalidate(transactionAttachmentsProvider(transactionId));
    // Also reload transaction list to update attachment count
    await _ref.read(transactionProvider.notifier).loadTransactions();
  }

  Future<AttachmentModel> addAttachment({
    required String transactionId,
    required String sourcePath,
    required String fileName,
    int? fileSize,
    String? fileType,
  }) async {
    final repo = _ref.read(attachmentRepositoryProvider);
    final att = await repo.copyAndSaveAttachment(
      transactionId: transactionId,
      sourcePath: sourcePath,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
    );
    _ref.invalidate(transactionAttachmentsProvider(transactionId));
    await _ref.read(transactionProvider.notifier).loadTransactions();
    return att;
  }
}

final attachmentControllerProvider = Provider<AttachmentController>((ref) {
  return AttachmentController(ref);
});
