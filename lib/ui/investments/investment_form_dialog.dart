import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/investment.dart';
import '../../providers/account_provider.dart';
import '../../providers/investment_provider.dart';
import '../../providers/settings_provider.dart';

class InvestmentFormDialog extends ConsumerStatefulWidget {
  final Investment? investmentToEdit;

  const InvestmentFormDialog({super.key, this.investmentToEdit});

  @override
  ConsumerState<InvestmentFormDialog> createState() => _InvestmentFormDialogState();
}

class _InvestmentFormDialogState extends ConsumerState<InvestmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late InvestmentType _selectedType;
  late final TextEditingController _nameController;
  late final TextEditingController _investedAmountController;
  late final TextEditingController _currentValueController;
  late final TextEditingController _returnRateController;
  late final TextEditingController _maturityAmountController;
  late final TextEditingController _notesController;

  String? _selectedAccountId;
  late DateTime _startDate;
  DateTime? _maturityDate;
  String _frequency = 'One-time';
  bool _deductFromAccount = false;
  bool _isSubmitting = false;

  final List<String> _frequencies = ['One-time', 'Monthly', 'Quarterly', 'Half-Yearly', 'Annually'];

  @override
  void initState() {
    super.initState();
    final edit = widget.investmentToEdit;
    _selectedType = edit?.type ?? InvestmentType.fd;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _investedAmountController = TextEditingController(text: edit != null ? edit.investedAmount.toString() : '');
    _currentValueController = TextEditingController(text: edit != null ? edit.currentValue.toString() : '');
    _returnRateController = TextEditingController(text: edit != null && edit.expectedReturnRate > 0 ? edit.expectedReturnRate.toString() : '');
    _maturityAmountController = TextEditingController(text: edit?.maturityAmount != null ? edit!.maturityAmount.toString() : '');
    _notesController = TextEditingController(text: edit?.notes ?? '');
    _selectedAccountId = edit?.accountId;
    _startDate = edit?.startDate ?? DateTime.now();
    _maturityDate = edit?.maturityDate;
    _frequency = edit?.frequency ?? 'One-time';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _investedAmountController.dispose();
    _currentValueController.dispose();
    _returnRateController.dispose();
    _maturityAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickMaturityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _maturityDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _maturityDate = picked);
  }

  Future<void> _saveInvestment() async {
    if (!_formKey.currentState!.validate()) return;

    final invested = double.tryParse(_investedAmountController.text.trim()) ?? 0.0;
    var current = double.tryParse(_currentValueController.text.trim());
    if (current == null || current <= 0) {
      current = invested;
    }
    final returnRate = double.tryParse(_returnRateController.text.trim()) ?? 0.0;
    final maturityAmt = double.tryParse(_maturityAmountController.text.trim());

    setState(() => _isSubmitting = true);

    try {
      final isEdit = widget.investmentToEdit != null;
      final inv = Investment(
        id: widget.investmentToEdit?.id ?? '',
        name: _nameController.text.trim(),
        type: _selectedType,
        accountId: _selectedAccountId,
        investedAmount: invested,
        currentValue: current,
        expectedReturnRate: returnRate,
        startDate: _startDate,
        maturityDate: _maturityDate,
        frequency: _frequency,
        maturityAmount: maturityAmt,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        status: widget.investmentToEdit?.status ?? 'active',
        createdAt: widget.investmentToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEdit) {
        await ref.read(investmentProvider.notifier).updateInvestment(inv);
      } else {
        await ref.read(investmentProvider.notifier).createInvestment(
          inv,
          deductFromAccount: _deductFromAccount,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Investment updated successfully' : 'Investment added successfully'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving investment: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final accountState = ref.watch(accountProvider);
    final accounts = accountState.accounts;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.investmentToEdit != null;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.investment.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.trending_up_rounded, color: AppColors.investment, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEdit ? 'Edit Investment' : 'Add New Investment',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Investment Type Dropdown
                DropdownButtonFormField<InvestmentType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Investment Type *'),
                  items: InvestmentType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 14),

                // Investment Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Investment Name *',
                    hintText: 'e.g. HDFC 3-Yr FD, Nifty Index Fund, Sovereign Gold Bond',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 14),

                // Associated Account
                DropdownButtonFormField<String?>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Linked / Funding Account (Optional)',
                    hintText: 'Select account',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (Direct Investment)'),
                    ),
                    ...accounts.map((a) => DropdownMenuItem<String?>(
                          value: a.id,
                          child: Text('${a.name} (${a.type})'),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                ),
                if (!isEdit && _selectedAccountId != null) ...[
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Deduct invested amount from this account', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Records a balance reconciliation without treating it as an expense', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _deductFromAccount,
                    onChanged: (val) => setState(() => _deductFromAccount = val ?? false),
                  ),
                ],
                const SizedBox(height: 14),

                // Invested Amount & Current Value in Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _investedAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                        decoration: InputDecoration(
                          labelText: 'Invested Amount *',
                          prefixText: '$curr ',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter amount';
                          if ((double.tryParse(val) ?? 0) <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _currentValueController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                        decoration: InputDecoration(
                          labelText: 'Current / Est. Value',
                          prefixText: '$curr ',
                          hintText: 'Defaults to invested',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Return Rate & Frequency
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _returnRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                        decoration: const InputDecoration(
                          labelText: 'Return Rate (% p.a.)',
                          suffixText: '%',
                          hintText: 'e.g. 7.5',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _frequency,
                        decoration: const InputDecoration(labelText: 'Frequency'),
                        items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _frequency = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Maturity Amount (Optional)
                TextFormField(
                  controller: _maturityAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  decoration: InputDecoration(
                    labelText: 'Maturity Amount (Optional)',
                    prefixText: '$curr ',
                    hintText: 'Expected final value on maturity',
                  ),
                ),
                const SizedBox(height: 14),

                // Date Selectors: Start Date & Maturity Date
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickStartDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Date *', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(DateFormat('dd MMM yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickMaturityDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Maturity Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  if (_maturityDate != null)
                                    GestureDetector(
                                      onTap: () => setState(() => _maturityDate = null),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _maturityDate != null ? DateFormat('dd MMM yyyy').format(_maturityDate!) : 'Not Set (Open-ended)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _maturityDate != null ? null : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Folio / Demat Details (Optional)',
                    hintText: 'Account number, folio ref, broker or scheme code',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _saveInvestment,
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save Changes' : 'Add Investment'),
        ),
      ],
    );
  }
}
