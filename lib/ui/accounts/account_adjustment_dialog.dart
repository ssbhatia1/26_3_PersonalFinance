import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';

class AccountAdjustmentDialog extends ConsumerStatefulWidget {
  final Account account;

  const AccountAdjustmentDialog({
    super.key,
    required this.account,
  });

  @override
  ConsumerState<AccountAdjustmentDialog> createState() => _AccountAdjustmentDialogState();
}

class _AccountAdjustmentDialogState extends ConsumerState<AccountAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _newBalanceController;
  final TextEditingController _reasonController = TextEditingController();
  DateTime _adjustmentDate = DateTime.now();
  TimeOfDay _adjustmentTime = TimeOfDay.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _newBalanceController = TextEditingController(
      text: widget.account.currentBalance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _newBalanceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double get _targetBalance {
    final text = _newBalanceController.text.trim();
    return double.tryParse(text) ?? widget.account.currentBalance;
  }

  double get _difference => _targetBalance - widget.account.currentBalance;

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _adjustmentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _adjustmentTime,
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _adjustmentDate = pickedDate;
      _adjustmentTime = pickedTime;
    });
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an adjustment reason or note')),
      );
      return;
    }

    if ((_difference).abs() < 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New balance is identical to the current recorded balance')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final finalTimestamp = DateTime(
        _adjustmentDate.year,
        _adjustmentDate.month,
        _adjustmentDate.day,
        _adjustmentTime.hour,
        _adjustmentTime.minute,
      );

      await ref.read(accountProvider.notifier).adjustAccountBalance(
        accountId: widget.account.id,
        newBalance: _targetBalance,
        reason: reason,
        timestamp: finalTimestamp,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account balance adjusted successfully: ${_difference >= 0 ? "+" : ""}${_difference.toStringAsFixed(2)}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to adjust balance: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diff = _difference;
    final isIncrease = diff > 0;
    final isDecrease = diff < 0;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Adjustment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(widget.account.name, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.blueGrey[900] : Colors.blue[50])?.withAlpha(120),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (isDark ? Colors.blueGrey[700] : Colors.blue[200])!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Colors.blue[600]),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Adjusting balance creates a tracked reconciliation record and preserves all existing transactions.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Current Recorded Balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Current Recorded Balance:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(widget.account.currentBalance, symbol: curr),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Actual/New Balance Input
                TextFormField(
                  controller: _newBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Actual / New Balance *',
                    prefixText: '$curr ',
                    hintText: 'Enter correct actual balance',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter actual balance';
                    }
                    if (double.tryParse(val.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Calculated Adjustment Delta Preview Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isIncrease
                        ? AppColors.income.withAlpha(20)
                        : (isDecrease ? AppColors.expense.withAlpha(20) : Colors.grey.withAlpha(20)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isIncrease
                          ? AppColors.income.withAlpha(80)
                          : (isDecrease ? AppColors.expense.withAlpha(80) : Colors.grey.withAlpha(60)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              isIncrease
                                  ? Icons.arrow_upward_rounded
                                  : (isDecrease ? Icons.arrow_downward_rounded : Icons.horizontal_rule_rounded),
                              size: 16,
                              color: isIncrease ? AppColors.income : (isDecrease ? AppColors.expense : Colors.grey),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isIncrease
                                    ? 'Balance Increase'
                                    : (isDecrease ? 'Balance Decrease' : 'No Change'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isIncrease ? AppColors.income : (isDecrease ? AppColors.expense : Colors.grey),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${diff >= 0 ? "+" : ""}${CurrencyFormatter.format(diff, symbol: curr)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isIncrease ? AppColors.income : (isDecrease ? AppColors.expense : Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reason / Note Input (Required)
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Adjustment Reason / Note *',
                    hintText: 'e.g. Bank statement reconciliation, cash count difference, interest credit',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Adjustment reason is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date & Time Picker
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      borderRadius: BorderRadius.circular(10),
                      color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(
                                DateTime(
                                  _adjustmentDate.year,
                                  _adjustmentDate.month,
                                  _adjustmentDate.day,
                                  _adjustmentTime.hour,
                                  _adjustmentTime.minute,
                                ),
                              ),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
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
          onPressed: _isSubmitting ? null : _submitAdjustment,
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Adjustment'),
        ),
      ],
    );
  }
}
