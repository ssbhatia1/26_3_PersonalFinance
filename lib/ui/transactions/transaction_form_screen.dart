import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/attachment.dart';
import '../../data/models/transaction.dart';
import '../../providers/account_provider.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/database_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/recurring_transaction.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import 'attachment_preview_dialog.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final TransactionModel? transactionToEdit;
  final String? preselectedAccountId;
  final int? initialTabIndex;

  const TransactionFormScreen({
    super.key,
    this.transactionToEdit,
    this.preselectedAccountId,
    this.initialTabIndex,
  });

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TabController _tabController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _payeeController;
  late TextEditingController _notesController;

  late final String _transactionId;
  List<AttachmentModel> _attachments = [];
  final List<PlatformFile> _stagedFiles = [];
  final List<String> _removedAttachmentIds = [];
  bool _isLoadingAttachments = false;

  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  bool _isScheduledPayment = false;
  String _scheduleFrequency = 'once';
  bool _isFlexibleAmount = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transactionToEdit;
    _transactionId = tx?.id ?? _uuid.v4();

    _amountController = TextEditingController(text: tx != null ? tx.amount.toString() : '');
    _descriptionController = TextEditingController(text: tx?.description ?? '');
    _payeeController = TextEditingController(text: tx?.payeePayer ?? '');
    _notesController = TextEditingController(text: tx?.notes ?? '');

    final int initialIdx;
    if (tx != null) {
      initialIdx = tx.type == 'income' ? 1 : (tx.type == 'transfer' ? 2 : 0);
    } else {
      initialIdx = widget.initialTabIndex ?? 0;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIdx);

    if (tx != null) {
      _sourceAccountId = tx.sourceAccountId;
      _destinationAccountId = tx.destinationAccountId;
      _selectedCategoryId = tx.categoryId;
      _selectedDate = tx.date;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingAttachments();
      });
    } else if (widget.preselectedAccountId != null) {
      _sourceAccountId = widget.preselectedAccountId;
    }

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedCategoryId = null;
        });
      }
    });
  }

  Future<void> _loadExistingAttachments() async {
    if (widget.transactionToEdit == null) return;
    setState(() => _isLoadingAttachments = true);
    try {
      final repo = ref.read(attachmentRepositoryProvider);
      final atts = await repo.getAttachmentsByTransaction(_transactionId);
      if (mounted) {
        setState(() {
          _attachments = List.from(atts);
          _isLoadingAttachments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAttachments = false);
      }
    }
  }

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result.isNotEmpty) {
        setState(() {
          for (final file in result) {
            if (file.path != null && file.path!.isNotEmpty) {
              final fileName = file.name;
              final detectedType = _detectMimeType(fileName);
              final diskFile = File(file.path!);
              final size = diskFile.existsSync() ? diskFile.lengthSync() : 0;
              final newAttachment = AttachmentModel(
                id: _uuid.v4(),
                transactionId: _transactionId,
                fileName: fileName,
                filePath: file.path!,
                fileType: detectedType,
                fileSize: size,
                uploadedAt: DateTime.now(),
              );
              _attachments.add(newAttachment);
              _stagedFiles.add(file);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openPreview(int index) {
    if (_attachments.isEmpty) return;
    AttachmentPreviewDialog.show(
      context: context,
      attachments: _attachments,
      initialIndex: index,
      allowDelete: true,
      onDelete: (att) async {
        _removeAttachment(att);
      },
    );
  }

  void _removeAttachment(AttachmentModel att) {
    setState(() {
      _attachments.removeWhere((a) => a.id == att.id);
      _stagedFiles.removeWhere((f) => f.path == att.filePath);
      if (widget.transactionToEdit != null && !_stagedFiles.any((f) => f.path == att.filePath)) {
        _removedAttachmentIds.add(att.id);
      }
    });
  }

  String _detectMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.csv':
        return 'text/csv';
      case '.json':
        return 'application/json';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _payeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _currentType {
    switch (_tabController.index) {
      case 1:
        return 'income';
      case 2:
        return 'transfer';
      case 0:
      default:
        return 'expense';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? _selectedDate.hour,
          time?.minute ?? _selectedDate.minute,
        );
        if (_selectedDate.isAfter(DateTime.now().add(const Duration(minutes: 10))) && widget.transactionToEdit == null) {
          _isScheduledPayment = true;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero.')),
      );
      return;
    }

    if (_sourceAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a source account.')),
      );
      return;
    }

    final type = _currentType;
    final allAccounts = ref.read(accountProvider).accounts;
    final finalSourceId = allAccounts.any((a) => a.id == _sourceAccountId)
        ? _sourceAccountId!
        : (allAccounts.isNotEmpty ? allAccounts.first.id : (_sourceAccountId ?? ''));

    String? finalDestId;
    if (type == 'transfer') {
      final destCandidates = allAccounts.where((a) => a.id != finalSourceId).toList();
      finalDestId = (_destinationAccountId != null && destCandidates.any((a) => a.id == _destinationAccountId))
          ? _destinationAccountId
          : (destCandidates.isNotEmpty ? destCandidates.first.id : null);

      if (finalDestId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a destination account for transfer.')),
        );
        return;
      }
      if (finalSourceId == finalDestId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source and destination accounts must be different.')),
        );
        return;
      }
    }

    final now = DateTime.now();
    final isEditing = widget.transactionToEdit != null;

    final categories = ref.read(categoriesProvider(type)).value ?? [];
    final finalCategoryId = type == 'transfer'
        ? null
        : (categories.any((c) => c.id == _selectedCategoryId)
            ? _selectedCategoryId
            : (categories.isNotEmpty ? categories.first.id : null));

    if (_isScheduledPayment && !isEditing) {
      final title = _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : (_payeeController.text.trim().isNotEmpty
              ? _payeeController.text.trim()
              : (type == 'transfer' ? 'Scheduled Transfer' : 'Scheduled Payment'));

      final schedule = RecurringTransaction(
        id: _uuid.v4(),
        title: title,
        sourceAccountId: finalSourceId,
        destinationAccountId: finalDestId,
        type: type,
        categoryId: finalCategoryId,
        amount: amount,
        frequency: _scheduleFrequency,
        startDate: now,
        nextExecutionDate: _selectedDate,
        isFlexibleAmount: _isFlexibleAmount,
      );

      await ref.read(recurringProvider.notifier).createRecurring(schedule);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_scheduleFrequency == 'once'
                ? 'One-time payment scheduled for ${DateFormatter.formatFullDate(_selectedDate)}'
                : 'Recurring schedule created starting ${DateFormatter.formatFullDate(_selectedDate)}'),
            backgroundColor: AppColors.asset,
          ),
        );
      }
      return;
    }

    if (isEditing) {
      final updated = widget.transactionToEdit!.copyWith(
        sourceAccountId: finalSourceId,
        destinationAccountId: finalDestId,
        type: type,
        categoryId: finalCategoryId,
        amount: amount,
        date: _selectedDate,
        description: _descriptionController.text.trim(),
        payeePayer: _payeeController.text.trim(),
        notes: _notesController.text.trim(),
        updatedAt: now,
      );
      await ref.read(transactionProvider.notifier).updateTransaction(updated);
    } else {
      final newTx = TransactionModel(
        id: _transactionId,
        sourceAccountId: finalSourceId,
        destinationAccountId: finalDestId,
        type: type,
        categoryId: finalCategoryId,
        amount: amount,
        date: _selectedDate,
        description: _descriptionController.text.trim(),
        payeePayer: _payeeController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(transactionProvider.notifier).createTransaction(newTx);
    }

    // Process attachments
    final attRepo = ref.read(attachmentRepositoryProvider);

    // 1. Delete removed attachments
    for (final removeId in _removedAttachmentIds) {
      await attRepo.deleteAttachment(removeId);
    }

    // 2. Save newly staged attachments
    for (final staged in _stagedFiles) {
      if (staged.path != null && _attachments.any((a) => a.filePath == staged.path)) {
        final diskFile = File(staged.path!);
        final size = diskFile.existsSync() ? diskFile.lengthSync() : 0;
        await attRepo.copyAndSaveAttachment(
          transactionId: _transactionId,
          sourcePath: staged.path!,
          fileName: staged.name,
          fileSize: size,
          fileType: _detectMimeType(staged.name),
        );
      }
    }

    // Invalidate provider so attachment count refreshes
    ref.invalidate(transactionAttachmentsProvider(_transactionId));
    await ref.read(transactionProvider.notifier).loadTransactions();

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isEditing = widget.transactionToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoriesAsync = ref.watch(categoriesProvider(_currentType));

    // Default source account if not selected
    if (_sourceAccountId == null && accounts.isNotEmpty) {
      _sourceAccountId = accounts.first.id;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isEditing ? 'Edit Transaction' : 'Record Transaction',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Transaction Type Tabs
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    onTap: (_) => setState(() => _selectedCategoryId = null),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: _currentType == 'income'
                          ? AppColors.income
                          : (_currentType == 'transfer' ? AppColors.transfer : AppColors.expense),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Expense'),
                      Tab(text: 'Income'),
                      Tab(text: 'Transfer'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amount Input
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '$curr ',
                    prefixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    hintText: '0.00',
                    labelText: 'Amount *',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter amount';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Account Selection
                DropdownButtonFormField<String>(
                  value: accounts.any((a) => a.id == _sourceAccountId)
                      ? _sourceAccountId
                      : (accounts.isNotEmpty ? accounts.first.id : null),
                  decoration: InputDecoration(
                    labelText: _currentType == 'transfer' ? 'From Account *' : 'Account *',
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accounts.map((a) {
                    return DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        '${a.name} (${CurrencyFormatter.format(a.currentBalance, symbol: curr)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _sourceAccountId = v),
                ),

                // Destination Account (for transfers)
                if (_currentType == 'transfer') ...[
                  const SizedBox(height: 14),
                  () {
                    final destAccounts = accounts.where((a) => a.id != _sourceAccountId).toList();
                    final hasMatchingDest = destAccounts.any((a) => a.id == _destinationAccountId);
                    final effectiveDestId = hasMatchingDest
                        ? _destinationAccountId
                        : (destAccounts.isNotEmpty ? destAccounts.first.id : null);

                    return DropdownButtonFormField<String>(
                      value: effectiveDestId,
                      decoration: const InputDecoration(
                        labelText: 'To Destination Account *',
                        prefixIcon: Icon(Icons.arrow_forward_rounded),
                      ),
                      items: destAccounts.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            '${a.name} (${CurrencyFormatter.format(a.currentBalance, symbol: curr)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _destinationAccountId = v),
                    );
                  }(),
                ],

                // Category Selection (for income/expense)
                if (_currentType != 'transfer') ...[
                  const SizedBox(height: 14),
                  categoriesAsync.when(
                    data: (cats) {
                      final hasMatching = cats.any((c) => c.id == _selectedCategoryId);
                      final effectiveCategoryId = hasMatching
                          ? _selectedCategoryId
                          : (cats.isNotEmpty ? cats.first.id : null);

                      return DropdownButtonFormField<String>(
                        value: effectiveCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: cats.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(c.iconData, size: 18, color: c.colorValue),
                                const SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedCategoryId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],

                const SizedBox(height: 14),
                // Description & Payee
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g. Dinner, Grocery run',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _payeeController,
                        decoration: InputDecoration(
                          labelText: _currentType == 'income' ? 'Payer' : 'Payee / Merchant',
                          hintText: 'e.g. Amazon, Uber',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add extra details, warranty info, memo...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Date Picker Tile
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.darkBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} at ${_selectedDate.hour}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                if (widget.transactionToEdit == null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: _isScheduledPayment
                        ? AppColors.primary.withAlpha(20)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _isScheduledPayment ? AppColors.primary : AppColors.darkBorder,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 20, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Schedule Payment for Specific Date',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Switch(
                                value: _isScheduledPayment,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setState(() => _isScheduledPayment = val),
                              ),
                            ],
                          ),
                          if (_isScheduledPayment) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _scheduleFrequency,
                                    decoration: const InputDecoration(
                                      labelText: 'Recurrence',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'once', child: Text('One-Time Payment')),
                                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setState(() => _scheduleFrequency = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_scheduleFrequency != 'once') ...[
                              const SizedBox(height: 8),
                              Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Flexible Amount (Variable/Bills)', style: TextStyle(fontSize: 13)),
                                  subtitle: const Text('Confirm or adjust actual amount per cycle', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  value: _isFlexibleAmount,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) => setState(() => _isFlexibleAmount = val ?? false),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Attachments & Receipts Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Attachments & Receipts',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_attachments.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _pickAttachments,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add File'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Attachments List / Empty State
                if (_isLoadingAttachments)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_attachments.isEmpty)
                  InkWell(
                    onTap: _pickAttachments,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.darkBorder.withAlpha(120),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          const Text(
                            'Attach receipts, bills, invoices, or screenshots',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports JPG, PNG, PDF, TXT, CSV, Docs (stored locally)',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attachments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final att = _attachments[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.darkBorder.withAlpha(100)),
                        ),
                        child: Row(
                          children: [
                            // Thumbnail / Type Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (att.isImage
                                        ? AppColors.primary
                                        : (att.isPdf ? AppColors.expense : AppColors.transfer))
                                    .withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: att.isImage && File(att.filePath).existsSync()
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(att.filePath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.image_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      att.isPdf
                                          ? Icons.picture_as_pdf_rounded
                                          : (att.isText
                                              ? Icons.description_rounded
                                              : Icons.insert_drive_file_rounded),
                                      color: att.isPdf ? AppColors.expense : AppColors.transfer,
                                      size: 20,
                                    ),
                            ),
                            const SizedBox(width: 12),

                            // File Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    att.fileName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${att.fileExtension} • ${att.formattedSize}',
                                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            ),

                            // Preview Button
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.primary),
                              tooltip: 'Preview',
                              onPressed: () => _openPreview(idx),
                            ),

                            // Delete Button
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                              tooltip: 'Remove',
                              onPressed: () => _removeAttachment(att),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),

                // Submit Action
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentType == 'income'
                        ? AppColors.income
                        : (_currentType == 'transfer' ? AppColors.transfer : AppColors.expense),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isEditing ? 'Update Entry' : 'Save ${_currentType.toUpperCase()}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
