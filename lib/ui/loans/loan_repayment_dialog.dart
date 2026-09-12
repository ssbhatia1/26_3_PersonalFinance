import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/loan.dart';
import '../../providers/account_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/settings_provider.dart';

class LoanRepaymentDialog extends ConsumerStatefulWidget {
  final Loan loan;

  const LoanRepaymentDialog({super.key, required this.loan});

  @override
  ConsumerState<LoanRepaymentDialog> createState() => _LoanRepaymentDialogState();
}

class _LoanRepaymentDialogState extends ConsumerState<LoanRepaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _interestController;
  late TextEditingController _noteController;
  String? _paymentAccountId;
  bool _specifyInterest = false;

  @override
  void initState() {
    super.initState();
    final defaultAmount = widget.loan.emiAmount > 0
        ? widget.loan.emiAmount
        : widget.loan.outstandingBalance;
    _amountController = TextEditingController(text: defaultAmount.toString());
    _amountController.addListener(() => setState(() {}));

    _specifyInterest = widget.loan.isFlexibleInterest || widget.loan.interestRate > 0;
    final monthlyEstimatedInterest = widget.loan.interestRate > 0
        ? (widget.loan.outstandingBalance * (widget.loan.interestRate / 100.0) / 12.0)
        : 0.0;
    final initialInterest = _specifyInterest && monthlyEstimatedInterest > 0
        ? monthlyEstimatedInterest.toStringAsFixed(2)
        : '0.00';
    _interestController = TextEditingController(text: initialInterest);
    _interestController.addListener(() => setState(() {}));

    _noteController = TextEditingController();
    _paymentAccountId = widget.loan.accountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paymentAccountId == null) return;

    final totalPayment = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (totalPayment <= 0) return;

    final interest = _specifyInterest ? (double.tryParse(_interestController.text.trim()) ?? 0.0) : 0.0;
    if (interest > totalPayment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interest amount cannot exceed total payment amount.')),
      );
      return;
    }

    await ref.read(loanProvider.notifier).recordRepayment(
      loan: widget.loan,
      paymentAmount: totalPayment,
      paymentAccountId: _paymentAccountId!,
      interestAmount: interest,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final loan = widget.loan;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalPayment = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final interestAmount = _specifyInterest ? (double.tryParse(_interestController.text.trim()) ?? 0.0) : 0.0;
    final principalReduction = (totalPayment - interestAmount).clamp(0.0, double.infinity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                          color: (loan.isBorrowed ? AppColors.liability : AppColors.primary).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          loan.isBorrowed ? Icons.call_received_rounded : Icons.call_made_rounded,
                          color: loan.isBorrowed ? AppColors.liability : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loan.isBorrowed ? 'Make Loan Repayment' : 'Record Received Money',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${loan.borrowerLenderName} • Outstanding: ${CurrencyFormatter.format(loan.outstandingBalance, symbol: curr)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Flexible rate banner if applicable
                  if (loan.isFlexibleInterest) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Flexible Interest Loan: You can freely adjust the interest portion for this repayment.',
                              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Total Payment Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Payment Amount *',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Flexible Interest Toggle & Input
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Specify Interest Portion (Flexible Interest)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: const Text('Separate interest expense from principal reduction', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _specifyInterest,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _specifyInterest = val ?? false),
                  ),

                  if (_specifyInterest) ...[
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _interestController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: loan.isFlexibleInterest ? 'Flexible Interest Component *' : 'Interest Component *',
                        hintText: '0.00',
                        helperText: loan.isBorrowed
                            ? 'Logged as interest expense. Remainder reduces loan liability.'
                            : 'Logged as interest income. Remainder reduces loan receivable.',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (!_specifyInterest) return null;
                        if (v == null || v.isEmpty) return 'Enter interest amount (0 or more)';
                        final n = double.tryParse(v);
                        if (n == null || n < 0) return 'Must be 0 or positive';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Live calculation breakdown preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Principal Reduction:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                CurrencyFormatter.format(principalReduction, symbol: curr),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.income),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(loan.isBorrowed ? 'Interest Expense:' : 'Interest Income:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                CurrencyFormatter.format(interestAmount, symbol: curr),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: loan.isBorrowed ? AppColors.expense : AppColors.income,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Outflow:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                CurrencyFormatter.format(totalPayment, symbol: curr),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: accounts.any((a) => a.id == _paymentAccountId)
                        ? _paymentAccountId
                        : (accounts.isNotEmpty ? accounts.first.id : null),
                    decoration: InputDecoration(
                      labelText: loan.isBorrowed ? 'Pay From Account *' : 'Deposit To Account *',
                      border: const OutlineInputBorder(),
                    ),
                    items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _paymentAccountId = v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'e.g. Month 3 EMI or Partial prepayment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: loan.isBorrowed ? AppColors.liability : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text('Confirm Payment'),
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
