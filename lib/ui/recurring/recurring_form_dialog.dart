import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/recurring_transaction.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_provider.dart';

class RecurringFormDialog extends ConsumerStatefulWidget {
  final RecurringTransaction? recurringToEdit;
  final bool initialIsOneTime;
  final String? prefillTitle;
  final double? prefillAmount;
  final String? prefillType;
  final String? prefillAccountId;
  final String? prefillCategoryId;

  const RecurringFormDialog({
    super.key,
    this.recurringToEdit,
    this.initialIsOneTime = false,
    this.prefillTitle,
    this.prefillAmount,
    this.prefillType,
    this.prefillAccountId,
    this.prefillCategoryId,
  });

  @override
  ConsumerState<RecurringFormDialog> createState() => _RecurringFormDialogState();
}

class _RecurringFormDialogState extends ConsumerState<RecurringFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _intervalCountController;

  String _type = 'expense';
  String _frequency = 'monthly';
  bool _isFlexibleAmount = false;
  int _intervalCount = 1;
  String _intervalUnit = 'months';

  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _categoryId;
  DateTime _nextExecutionDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final r = widget.recurringToEdit;
    _titleController = TextEditingController(text: r?.title ?? widget.prefillTitle ?? '');
    _amountController = TextEditingController(
      text: r != null
          ? r.amount.toString()
          : (widget.prefillAmount != null && widget.prefillAmount! > 0 ? widget.prefillAmount.toString() : ''),
    );
    _intervalCountController = TextEditingController(text: r != null ? r.intervalCount.toString() : '2');

    if (r != null) {
      _type = r.type;
      _frequency = r.frequency;
      _isFlexibleAmount = r.isFlexibleAmount;
      _intervalCount = r.intervalCount;
      _intervalUnit = r.intervalUnit;
      _sourceAccountId = r.sourceAccountId;
      _destinationAccountId = r.destinationAccountId;
      _categoryId = r.categoryId;
      _nextExecutionDate = r.nextExecutionDate;
      _endDate = r.endDate;
    } else {
      if (widget.initialIsOneTime) {
        _frequency = 'once';
      }
      if (widget.prefillType != null) _type = widget.prefillType!;
      if (widget.prefillAccountId != null) _sourceAccountId = widget.prefillAccountId;
      if (widget.prefillCategoryId != null) _categoryId = widget.prefillCategoryId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _intervalCountController.dispose();
    super.dispose();
  }

  bool get _isOneTime => _frequency == 'once';
  bool get _isCustom => _frequency == 'custom';

  Future<void> _pickExecutionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextExecutionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _nextExecutionDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _nextExecutionDate.add(const Duration(days: 90)),
      firstDate: _nextExecutionDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceAccountId == null) return;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    final allAccounts = ref.read(accountProvider).accounts;
    String? finalDestId;
    if (_type == 'transfer') {
      final destOptions = allAccounts.where((a) => a.id != _sourceAccountId).toList();
      finalDestId = (_destinationAccountId != null && destOptions.any((a) => a.id == _destinationAccountId))
          ? _destinationAccountId
          : (destOptions.isNotEmpty ? destOptions.first.id : null);

      if (finalDestId == null || finalDestId == _sourceAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid different destination account for transfer.')),
        );
        return;
      }
    }

    _intervalCount = int.tryParse(_intervalCountController.text.trim()) ?? 1;
    final now = DateTime.now();

    if (widget.recurringToEdit != null) {
      final updated = widget.recurringToEdit!.copyWith(
        title: title,
        sourceAccountId: _sourceAccountId!,
        destinationAccountId: _type == 'transfer' ? finalDestId : null,
        type: _type,
        categoryId: _type == 'transfer' ? null : _categoryId,
        amount: amount,
        frequency: _frequency,
        isFlexibleAmount: _isOneTime ? false : _isFlexibleAmount,
        intervalCount: _isCustom ? _intervalCount : 1,
        intervalUnit: _isCustom ? _intervalUnit : 'months',
        nextExecutionDate: _nextExecutionDate,
        endDate: _isOneTime ? null : _endDate,
      );
      await ref.read(recurringProvider.notifier).updateRecurring(updated);
    } else {
      final newRec = RecurringTransaction(
        id: _uuid.v4(),
        title: title,
        sourceAccountId: _sourceAccountId!,
        destinationAccountId: _type == 'transfer' ? finalDestId : null,
        type: _type,
        categoryId: _type == 'transfer' ? null : _categoryId,
        amount: amount,
        frequency: _frequency,
        isFlexibleAmount: _isOneTime ? false : _isFlexibleAmount,
        intervalCount: _isCustom ? _intervalCount : 1,
        intervalUnit: _isCustom ? _intervalUnit : 'months',
        startDate: now,
        endDate: _isOneTime ? null : _endDate,
        nextExecutionDate: _nextExecutionDate,
      );
      await ref.read(recurringProvider.notifier).createRecurring(newRec);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final categoriesAsync = ref.watch(categoriesProvider(_type));
    final isEditing = widget.recurringToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_sourceAccountId == null && accounts.isNotEmpty) {
      _sourceAccountId = accounts.first.id;
    }
    if (_type == 'transfer') {
      final remaining = accounts.where((a) => a.id != _sourceAccountId).toList();
      if (_destinationAccountId == null && remaining.isNotEmpty) {
        _destinationAccountId = remaining.first.id;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                          color: (_isOneTime ? AppColors.asset : AppColors.primary).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isOneTime ? Icons.event_available_rounded : Icons.repeat_rounded,
                          color: _isOneTime ? AppColors.asset : AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? 'Edit Payment Schedule'
                                  : 'Schedule Payment',
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _isOneTime
                                  ? 'Schedule a single payment due on a future date'
                                  : 'Automate repeating bills, rent, salary, or subscriptions',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  const SizedBox(height: 16),

                  // Mode Segmented Switch (Recurring Rule vs One-Time Scheduled)
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.repeat_rounded, size: 18),
                          label: Text('Recurring Rule'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.event_available_rounded, size: 18),
                          label: Text('One-Time Payment'),
                        ),
                      ],
                      selected: {_isOneTime},
                      onSelectionChanged: (Set<bool> selection) {
                        setState(() {
                          if (selection.first) {
                            _frequency = 'once';
                          } else {
                            if (_frequency == 'once') _frequency = 'monthly';
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title field
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title / Purpose *',
                      hintText: 'e.g. Rent, Electricity Bill, Salary, Netflix',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                  ),
                  const SizedBox(height: 14),

                  // Transaction Type & Recurrence Frequency
                  Row(
                    children: [
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isOneTime
                            ? InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Schedule Frequency',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event_available_rounded, size: 20, color: AppColors.asset),
                                ),
                                child: const Text('One-Time (Single)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              )
                            : DropdownButtonFormField<String>(
                                value: _frequency == 'once' ? 'monthly' : _frequency,
                                decoration: const InputDecoration(labelText: 'Schedule Frequency', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                  DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                                  DropdownMenuItem(value: 'custom', child: Text('Custom Interval...')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _frequency = v);
                                },
                              ),
                      ),
                    ],
                  ),

                  // Custom interval configurator
                  if (_isCustom) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Configure Custom Recurrence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('Repeats every ', style: TextStyle(fontSize: 14)),
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  controller: _intervalCountController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) {
                                    final n = int.tryParse(v) ?? 1;
                                    setState(() => _intervalCount = n > 0 ? n : 1);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _intervalUnit,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'days', child: Text('Days')),
                                    DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
                                    DropdownMenuItem(value: 'months', child: Text('Months')),
                                    DropdownMenuItem(value: 'years', child: Text('Years')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _intervalUnit = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Flexible amount toggle (only for recurring)
                  if (!_isOneTime) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Flexible Amount (Variable/Bills)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                        'Enable for utility bills or variable expenses. Amount can be adjusted per cycle.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: _isFlexibleAmount,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _isFlexibleAmount = val),
                    ),
                  ],

                  const SizedBox(height: 10),
                  // Amount Field
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _isFlexibleAmount ? 'Estimated Baseline Amount *' : 'Amount *',
                      hintText: '0.00',
                      helperText: _isFlexibleAmount ? 'Estimated base amount. You can confirm actual bill on each due date.' : null,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter amount';
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Dates row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickExecutionDate,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: _isOneTime ? 'Scheduled Due Date *' : 'First Payment Date *',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
                            ),
                            child: Text(DateFormatter.formatFullDate(_nextExecutionDate), style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                      if (!_isOneTime) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _pickEndDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'End Date (Optional)',
                                border: const OutlineInputBorder(),
                                suffixIcon: _endDate != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () => setState(() => _endDate = null),
                                      )
                                    : const Icon(Icons.event_repeat_rounded, size: 20),
                              ),
                              child: Text(
                                _endDate != null ? DateFormatter.formatFullDate(_endDate!) : 'No end date',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _endDate != null ? null : Colors.grey,
                                ),
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

                  // Destination account for transfers
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

                  // Category (for income or expense)
                  if (_type != 'transfer') ...[
                    const SizedBox(height: 14),
                    categoriesAsync.when(
                      data: (cats) {
                        final hasMatching = cats.any((c) => c.id == _categoryId);
                        final effectiveCategoryId = hasMatching
                            ? _categoryId
                            : (cats.isNotEmpty ? cats.first.id : null);

                        return DropdownButtonFormField<String>(
                          value: effectiveCategoryId,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                          items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (v) => setState(() => _categoryId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text(
                          isEditing
                              ? 'Save Changes'
                              : (_isOneTime ? 'Schedule Payment' : 'Create Schedule'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
