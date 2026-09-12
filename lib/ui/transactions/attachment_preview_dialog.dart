import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/utils/file_launcher.dart';
import '../../data/models/attachment.dart';
import '../../providers/database_provider.dart';

class AttachmentPreviewDialog extends ConsumerStatefulWidget {
  final List<AttachmentModel> attachments;
  final int initialIndex;
  final bool allowDelete;
  final Future<void> Function(AttachmentModel attachment)? onDelete;

  const AttachmentPreviewDialog({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
    this.allowDelete = false,
    this.onDelete,
  });

  /// Static helper to easily show the dialog
  static Future<void> show({
    required BuildContext context,
    required List<AttachmentModel> attachments,
    int initialIndex = 0,
    bool allowDelete = false,
    Future<void> Function(AttachmentModel attachment)? onDelete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AttachmentPreviewDialog(
        attachments: attachments,
        initialIndex: initialIndex,
        allowDelete: allowDelete,
        onDelete: onDelete,
      ),
    );
  }

  @override
  ConsumerState<AttachmentPreviewDialog> createState() => _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends ConsumerState<AttachmentPreviewDialog> {
  late int _currentIndex;
  late TransformationController _zoomController;
  String? _cachedTextContent;
  String? _cachedSha256;
  bool _isLoadingContent = false;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.attachments.isNotEmpty ? widget.attachments.length - 1 : 0);
    _zoomController = TransformationController();
    _zoomController.addListener(_onZoomChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCurrentAttachmentDetails();
    });
  }

  void _onZoomChanged() {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.02 && mounted) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  @override
  void dispose() {
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    super.dispose();
  }

  AttachmentModel get _currentAttachment => widget.attachments[_currentIndex];

  Future<void> _loadCurrentAttachmentDetails() async {
    final att = _currentAttachment;
    if (mounted) {
      setState(() {
        _isLoadingContent = true;
        _cachedTextContent = null;
        _cachedSha256 = null;
      });
    }

    final repo = ref.read(attachmentRepositoryProvider);

    // Compute checksum
    final sha = await repo.getSha256Checksum(att);

    // If text file, read text snippet
    String? textContent;
    if (att.isText) {
      try {
        final file = File(att.filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          textContent = utf8.decode(bytes, allowMalformed: true);
        }
      } catch (e) {
        textContent = 'Unable to read text file content: $e';
      }
    }

    if (mounted) {
      setState(() {
        _cachedSha256 = sha;
        _cachedTextContent = textContent;
        _isLoadingContent = false;
      });
    }
  }

  void _zoomIn() {
    final matrix = _zoomController.value.clone();
    matrix.scale(1.25);
    _zoomController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _zoomController.value.clone();
    matrix.scale(0.8);
    _zoomController.value = matrix;
  }

  void _resetZoom() {
    _zoomController.value = Matrix4.identity();
  }

  Future<void> _openInSystemApp() async {
    final att = _currentAttachment;
    final success = await FileLauncher.openFile(att.filePath);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file "${att.fileName}" in external viewer.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _downloadOrExport() async {
    final att = _currentAttachment;
    final sourceFile = File(att.filePath);

    if (!await sourceFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment file not found on device.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final ext = p.extension(att.fileName).replaceAll('.', '');
      final bytes = await sourceFile.readAsBytes();

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Attachment As',
        fileName: att.fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ext.isNotEmpty ? [ext] : null,
      );

      if (uri != null) {
        final path = uri.scheme == 'file' ? uri.toFilePath() : uri.path;
        final file = File(path);
        if (!await file.exists()) {
          await file.writeAsBytes(bytes);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${att.fileName}" successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attachment?'),
        content: Text('Are you sure you want to delete "${_currentAttachment.fileName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDelete != null) {
      await widget.onDelete!(_currentAttachment);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final att = _currentAttachment;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = widget.attachments.length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 720),
        child: Column(
          children: [
            // Top Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardElevated : Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildTypeIcon(att),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          att.fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                att.fileExtension,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              att.formattedSize,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            if (totalCount > 1) ...[
                              const SizedBox(width: 8),
                              Text(
                                '•  ${_currentIndex + 1} of $totalCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Carousel navigation buttons if multiple
                  if (totalCount > 1) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                      tooltip: 'Previous Attachment',
                      onPressed: _currentIndex > 0
                          ? () {
                              setState(() => _currentIndex--);
                              _loadCurrentAttachmentDetails();
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      tooltip: 'Next Attachment',
                      onPressed: _currentIndex < totalCount - 1
                          ? () {
                              setState(() => _currentIndex++);
                              _loadCurrentAttachmentDetails();
                            }
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],

                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close Preview',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Main Preview Area
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: isDark ? AppColors.darkBg : Colors.grey[50],
                      child: _buildPreviewBody(att, isDark),
                    ),
                  ),

                  // Floating Zoom Controls for Images
                  if (att.isImage)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withAlpha(200),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.zoom_out_rounded, size: 20),
                              tooltip: 'Zoom Out',
                              onPressed: _zoomOut,
                            ),
                            Text(
                              '${(_currentScale * 100).toInt()}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.zoom_in_rounded, size: 20),
                              tooltip: 'Zoom In',
                              onPressed: _zoomIn,
                            ),
                            IconButton(
                              icon: const Icon(Icons.restart_alt_rounded, size: 20),
                              tooltip: 'Reset Zoom',
                              onPressed: _resetZoom,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Action Footer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardElevated : Colors.grey[100],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Open in System Viewer
                  ElevatedButton.icon(
                    onPressed: _openInSystemApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open in System App'),
                  ),
                  const SizedBox(width: 10),

                  // Download / Save As...
                  OutlinedButton.icon(
                    onPressed: _downloadOrExport,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Save Copy As...'),
                  ),

                  const Spacer(),

                  // Delete option if allowed
                  if (widget.allowDelete && widget.onDelete != null)
                    TextButton.icon(
                      onPressed: _confirmDelete,
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon(AttachmentModel att) {
    if (att.isImage) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.image_rounded, color: AppColors.primary, size: 22),
      );
    } else if (att.isPdf) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.expense.withAlpha(30), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.expense, size: 22),
      );
    } else if (att.isText) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.transfer.withAlpha(30), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.description_rounded, color: AppColors.transfer, size: 22),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.asset.withAlpha(30), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.insert_drive_file_rounded, color: AppColors.asset, size: 22),
      );
    }
  }

  Widget _buildPreviewBody(AttachmentModel att, bool isDark) {
    final file = File(att.filePath);

    if (att.isImage) {
      return InteractiveViewer(
        transformationController: _zoomController,
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_rounded, size: 60, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Unable to render image: $err'),
                    const SizedBox(height: 8),
                    Text('File path: ${att.filePath}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } else if (att.isText) {
      if (_isLoadingContent) {
        return const Center(child: CircularProgressIndicator());
      }
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardElevated : Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Plaintext / Document Preview (${_cachedTextContent?.split('\n').length ?? 0} lines)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _cachedTextContent ?? '(File is empty)',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // PDF and Other Documents Rich Preview Card
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 50 : 15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (att.isPdf ? AppColors.expense : AppColors.transfer).withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    att.isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                    size: 56,
                    color: att.isPdf ? AppColors.expense : AppColors.transfer,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  att.fileName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  att.fileType,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // Metadata Details
                _buildMetadataRow('Format', att.fileExtension, isDark),
                const SizedBox(height: 8),
                _buildMetadataRow('File Size', att.formattedSize, isDark),
                const SizedBox(height: 8),
                _buildMetadataRow(
                  'Uploaded',
                  '${att.uploadedAt.day}/${att.uploadedAt.month}/${att.uploadedAt.year} ${att.uploadedAt.hour}:${att.uploadedAt.minute.toString().padLeft(2, '0')}',
                  isDark,
                ),
                if (_cachedSha256 != null) ...[
                  const SizedBox(height: 8),
                  _buildMetadataRow(
                    'SHA-256 Checksum',
                    '${_cachedSha256!.substring(0, 16)}...',
                    isDark,
                    onTapCopy: () {
                      Clipboard.setData(ClipboardData(text: _cachedSha256!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SHA-256 checksum copied to clipboard!')),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          att.isPdf
                              ? 'PDF document verified. Tap "Open in System App" below to view all pages in your default PDF reader.'
                              : 'File ready. Tap "Open in System App" below to view in your device\'s default software.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMetadataRow(String label, String value, bool isDark, {VoidCallback? onTapCopy}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (onTapCopy != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onTapCopy,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
