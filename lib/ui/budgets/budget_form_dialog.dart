import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/budget.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';

class BudgetFormDialog extends ConsumerStatefulWidget {
  final Budget? budgetToEdit;

  const BudgetFormDialog({super.key, this.budgetToEdit});

  @override
  ConsumerState<BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<BudgetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _nameController;
  late TextEditingController _limitController;
  String? _selectedCategoryId;
  String _scope = 'category';
  String _periodType = 'monthly';
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isRecurring = false;

  @override
  void initState() {
    super.initState();
    final b = widget.budgetToEdit;
    final budgetState = ref.read(budgetProvider);
    final refMonth = budgetState.selectedMonth;

    _nameController = TextEditingController(text: b?.name ?? '');
    _limitController = TextEditingController(text: b != null ? b.amountLimit.toStringAsFixed(0) : '');
    _selectedCategoryId = b?.categoryId;
    _scope = b?.scope ?? 'category';
    _periodType = b?.periodType ?? 'monthly';
    _isRecurring = b?.isRecurring ?? false;

    if (b != null) {
      _startDate = b.startDate;
      _endDate = b.endDate;
    } else {
      _updateDatesForPeriod(_periodType, baseDate: refMonth);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _updateDatesForPeriod(String period, {DateTime? baseDate}) {
    final now = baseDate ?? DateTime.now();
    switch (period) {
      case 'weekly':
        final dayOfWeek = now.weekday; // 1 = Mon, 7 = Sun
        _startDate = DateTime(now.year, now.month, now.day - (dayOfWeek - 1));
        _endDate = _startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case 'monthly':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'yearly':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'custom':
      default:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30, hours: 23, minutes: 59, seconds: 59));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate) ? _endDate : _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: Text(
          'Are you sure you want to delete "${widget.budgetToEdit?.displayName}"? Past expenses will remain untouched in your transaction ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && widget.budgetToEdit != null) {
      await ref.read(budgetProvider.notifier).deleteBudget(widget.budgetToEdit!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final limit = double.tryParse(_limitController.text.trim()) ?? 0.0;
    if (limit <= 0) return;

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be earlier than start date')),
      );
      return;
    }

    final customName = _nameController.text.trim();

    if (widget.budgetToEdit != null) {
      final updated = widget.budgetToEdit!.copyWith(
        name: customName.isNotEmpty ? customName : null,
        categoryId: _scope == 'overall' ? null : _selectedCategoryId,
        scope: _scope,
        periodType: _periodType,
        amountLimit: limit,
        startDate: _startDate,
        endDate: _endDate,
        isRecurring: _isRecurring,
      );
      await ref.read(budgetProvider.notifier).updateBudget(updated);
    } else {
      final newBudget = Budget(
        id: _uuid.v4(),
        name: customName.isNotEmpty ? customName : null,
        categoryId: _scope == 'overall' ? null : _selectedCategoryId,
        scope: _scope,
        periodType: _periodType,
        amountLimit: limit,
        startDate: _startDate,
        endDate: _endDate,
        isRecurring: _isRecurring,
      );
      await ref.read(budgetProvider.notifier).createBudget(newBudget);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider('expense'));
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isEditing = widget.budgetToEdit != null;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Budget' : 'Create Budget',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (isEditing)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        tooltip: 'Delete Budget',
                        onPressed: _confirmDelete,
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // Budget Name (Optional)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Budget Name (Optional)',
                    hintText: 'e.g. Weekly Groceries, Dining Out',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                // Budget Scope
                DropdownButtonFormField<String>(
                  value: _scope,
                  decoration: const InputDecoration(
                    labelText: 'Budget Scope',
                    prefixIcon: Icon(Icons.tune_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'category', child: Text('Category Budget')),
                    DropdownMenuItem(value: 'overall', child: Text('Overall Spending Limit (All Expenses)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _scope = v);
                  },
                ),

                // Category Selector if scope == 'category'
                if (_scope == 'category') ...[
                  const SizedBox(height: 14),
                  categoriesAsync.when(
                    data: (cats) {
                      final hasMatching = cats.any((c) => c.id == _selectedCategoryId);
                      final effectiveCategoryId = hasMatching
                          ? _selectedCategoryId
                          : (cats.isNotEmpty ? cats.first.id : null);

                      if (_selectedCategoryId == null && effectiveCategoryId != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selectedCategoryId = effectiveCategoryId);
                        });
                      }

                      return DropdownButtonFormField<String>(
                        value: effectiveCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Expense Category *',
                          prefixIcon: Icon(Icons.category_rounded),
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
                        validator: (v) => v == null ? 'Select an expense category' : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
                const SizedBox(height: 14),

                // Budget Period: Weekly, Monthly, Yearly, Custom
                DropdownButtonFormField<String>(
                  value: _periodType,
                  decoration: const InputDecoration(
                    labelText: 'Budget Period',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly / Long-Term')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom Date Range')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _periodType = v;
                        _updateDatesForPeriod(v);
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Start Date & End Date Pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickStartDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            prefixIcon: Icon(Icons.event_available_rounded, size: 18),
                          ),
                          child: Text(
                            dateFormat.format(_startDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickEndDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            prefixIcon: Icon(Icons.event_busy_rounded, size: 18),
                          ),
                          child: Text(
                            dateFormat.format(_endDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Live Staying Duration Indicator (How Many Days Budget Will Stay)
                Builder(
                  builder: (context) {
                    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
                    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
                    final durationDays = end.difference(start).inDays + 1;
                    final isLongTerm = _periodType == 'yearly' || durationDays > 60;
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final daysLeft = end.difference(today).inDays;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (isLongTerm ? AppColors.transfer : AppColors.primary).withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isLongTerm ? AppColors.transfer : AppColors.primary).withAlpha(60),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_bottom_rounded,
                            size: 16,
                            color: isLongTerm ? AppColors.transfer : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Budget stays for $durationDays days'
                              '${daysLeft >= 0 ? " ($daysLeft days left from today)" : ""}'
                              '${isLongTerm ? " • Long-Term" : ""}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isLongTerm ? AppColors.transfer : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Limit Amount
                TextFormField(
                  controller: _limitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Budget Limit Amount *',
                    prefixText: '$curr ',
                    hintText: 'e.g. 15000',
                    prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter budget amount';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Recurring Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isRecurring,
                  activeColor: AppColors.primary,
                  title: const Text('Recurring Budget', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                    'Automatically renews for future periods without altering previous history.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onChanged: (val) => setState(() => _isRecurring = val),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: Icon(isEditing ? Icons.check_rounded : Icons.add_rounded, size: 18),
                      label: Text(isEditing ? 'Save Changes' : 'Create Budget'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
