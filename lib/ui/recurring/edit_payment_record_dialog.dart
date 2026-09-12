import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/payment_record.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/settings_provider.dart';

class EditPaymentRecordDialog extends ConsumerStatefulWidget {
  final PaymentRecordModel record;

  const EditPaymentRecordDialog({super.key, required this.record});

  static Future<bool?> show(BuildContext context, PaymentRecordModel record) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => EditPaymentRecordDialog(record: record),
    );
  }

  @override
  ConsumerState<EditPaymentRecordDialog> createState() => _EditPaymentRecordDialogState();
}

class _EditPaymentRecordDialogState extends ConsumerState<EditPaymentRecordDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late TextEditingController _failureReasonController;

  late String _status;
  late String _type;
  late bool _isFlexible;
  late DateTime _dueDate;
  DateTime? _executionDate;
  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _categoryId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _titleController = TextEditingController(text: r.title);
    _amountController = TextEditingController(text: r.amount.toStringAsFixed(2));
    _notesController = TextEditingController(text: r.notes ?? '');
    _failureReasonController = TextEditingController(text: r.failureReason ?? '');

    _status = r.status.toLowerCase();
    _type = r.type;
    _isFlexible = r.isFlexible;
    _dueDate = r.dueDate;
    _executionDate = r.executionDate ?? (r.isCompleted ? DateTime.now() : null);
    _sourceAccountId = r.sourceAccountId;
    _destinationAccountId = r.destinationAccountId;
    _categoryId = r.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _failureReasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickExecutionDate() async {
    final initial = _executionDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _executionDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceAccountId == null) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    if (_type == 'transfer' && (_destinationAccountId == null || _destinationAccountId == _sourceAccountId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a different destination account for transfers.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = widget.record.copyWith(
        title: _titleController.text.trim(),
        amount: amount,
        status: _status,
        type: _type,
        isFlexible: _isFlexible,
        dueDate: _dueDate,
        executionDate: _status == 'completed' ? (_executionDate ?? DateTime.now()) : null,
        sourceAccountId: _sourceAccountId,
        destinationAccountId: _type == 'transfer' ? _destinationAccountId : null,
        categoryId: _type != 'transfer' ? _categoryId : null,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        failureReason: _status == 'failed' && _failureReasonController.text.trim().isNotEmpty
            ? _failureReasonController.text.trim()
            : null,
      );

      await ref.read(recurringProvider.notifier).updatePaymentRecord(updated);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated payment record "${updated.title}"'),
            backgroundColor: AppColors.asset,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating record: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final categoriesAsync = ref.watch(categoriesProvider(_type));
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;

    if (_sourceAccountId == null && accounts.isNotEmpty) {
      _sourceAccountId = accounts.first.id;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Payment Record',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Modify details, status, or amount for this transaction',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 14),

                  // Amount and Type
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount ($curr) *',
                            prefixText: '$curr ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter amount';
                            final n = double.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _type,
                          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'expense', child: Text('Expense')),
                            DropdownMenuItem(value: 'income', child: Text('Income')),
                            DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _type = v;
                                _categoryId = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Status Selector
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Payment Status *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'completed', child: Text('Completed (Paid)')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending Review')),
                      DropdownMenuItem(value: 'scheduled', child: Text('Scheduled (Upcoming)')),
                      DropdownMenuItem(value: 'skipped', child: Text('Skipped')),
                      DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _status = v;
                          if (_status == 'completed' && _executionDate == null) {
                            _executionDate = DateTime.now();
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Dates: Due Date & Execution Date
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDueDate,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Due Date *',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                            ),
                            child: Text(DateFormatter.formatFullDate(_dueDate), style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                      if (_status == 'completed') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _pickExecutionDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Executed Date',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.event_available_rounded, size: 18),
                              ),
                              child: Text(
                                _executionDate != null
                                    ? DateFormatter.formatFullDate(_executionDate!)
                                    : 'Pick Date',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Source Account
                  DropdownButtonFormField<String>(
                    value: accounts.any((a) => a.id == _sourceAccountId)
                        ? _sourceAccountId
                        : (accounts.isNotEmpty ? accounts.first.id : null),
                    decoration: InputDecoration(
                      labelText: _type == 'transfer' ? 'Source Account *' : 'Account *',
                      border: const OutlineInputBorder(),
                    ),
                    items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _sourceAccountId = v),
                  ),

                  // Destination Account (Transfers)
                  if (_type == 'transfer') ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: accounts.any((a) => a.id == _destinationAccountId)
                          ? _destinationAccountId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Destination Account *',
                        border: OutlineInputBorder(),
                      ),
                      items: accounts
                          .where((a) => a.id != _sourceAccountId)
                          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _destinationAccountId = v),
                    ),
                  ],

                  // Category (Expense/Income)
                  if (_type != 'transfer') ...[
                    const SizedBox(height: 14),
                    categoriesAsync.when(
                      data: (cats) {
                        final hasMatching = cats.any((c) => c.id == _categoryId);
                        final effectiveId = hasMatching
                            ? _categoryId
                            : (cats.isNotEmpty ? cats.first.id : null);

                        return DropdownButtonFormField<String>(
                          value: effectiveId,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                          items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (v) => setState(() => _categoryId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],

                  // Flexible amount toggle
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Flexible / Variable Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Marks this payment as having variable or adjustable amounts.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _isFlexible,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isFlexible = v),
                  ),

                  // Failure Reason if failed
                  if (_status == 'failed') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _failureReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Failure Reason',
                        hintText: 'e.g. Insufficient funds',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],

                  // Notes
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
