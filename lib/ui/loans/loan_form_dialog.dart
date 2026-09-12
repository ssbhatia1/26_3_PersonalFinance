import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/loan.dart';
import '../../data/models/recurring_transaction.dart';
import '../../providers/account_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/recurring_provider.dart';

class LoanFormDialog extends ConsumerStatefulWidget {
  final Loan? loanToEdit;

  const LoanFormDialog({super.key, this.loanToEdit});

  @override
  ConsumerState<LoanFormDialog> createState() => _LoanFormDialogState();
}

class _LoanFormDialogState extends ConsumerState<LoanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _nameController;
  late TextEditingController _principalController;
  late TextEditingController _interestController;
  late TextEditingController _termController;
  late TextEditingController _emiController;

  String _loanType = 'borrowed';
  String? _accountId;
  bool _isFlexibleInterest = false;
  bool _createRecurringSchedule = false;
  bool _disburseToAccount = true;

  @override
  void initState() {
    super.initState();
    final l = widget.loanToEdit;
    _nameController = TextEditingController(text: l?.borrowerLenderName ?? '');
    _principalController = TextEditingController(text: l != null ? l.principal.toString() : '');
    _interestController = TextEditingController(text: l != null ? l.interestRate.toString() : '0.0');
    _termController = TextEditingController(text: l != null ? l.termMonths.toString() : '12');
    _emiController = TextEditingController(text: l != null ? l.emiAmount.toString() : '0.0');
    _emiController.addListener(() => setState(() {}));

    if (l != null) {
      _loanType = l.loanType;
      _accountId = l.accountId;
      _isFlexibleInterest = l.isFlexibleInterest;
      _disburseToAccount = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _termController.dispose();
    _emiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;

    final name = _nameController.text.trim();
    final principal = double.tryParse(_principalController.text.trim()) ?? 0.0;
    final interest = double.tryParse(_interestController.text.trim()) ?? 0.0;
    final term = int.tryParse(_termController.text.trim()) ?? 12;
    final emi = double.tryParse(_emiController.text.trim()) ?? 0.0;

    if (principal <= 0) return;

    if (widget.loanToEdit != null) {
      final updated = widget.loanToEdit!.copyWith(
        accountId: _accountId!,
        borrowerLenderName: name,
        loanType: _loanType,
        principal: principal,
        interestRate: interest,
        isFlexibleInterest: _isFlexibleInterest,
        termMonths: term,
        emiAmount: emi,
      );
      await ref.read(loanProvider.notifier).createLoan(updated);
    } else {
      final newLoan = Loan(
        id: _uuid.v4(),
        accountId: _accountId!,
        borrowerLenderName: name,
        loanType: _loanType,
        principal: principal,
        interestRate: interest,
        isFlexibleInterest: _isFlexibleInterest,
        termMonths: term,
        outstandingBalance: principal,
        startDate: DateTime.now(),
        emiAmount: emi,
      );
      await ref.read(loanProvider.notifier).createLoan(newLoan, disburseToAccount: _disburseToAccount);
    }

    if (_createRecurringSchedule && emi > 0) {
      final now = DateTime.now();
      final recurring = RecurringTransaction(
        id: _uuid.v4(),
        title: 'EMI: $name',
        sourceAccountId: _accountId!,
        type: _loanType == 'borrowed' ? 'expense' : 'income',
        categoryId: _loanType == 'borrowed' ? 'cat_exp_emi' : 'cat_inc_other',
        amount: emi,
        frequency: 'monthly',
        startDate: now,
        nextExecutionDate: now.add(const Duration(days: 30)),
        isActive: true,
      );
      await ref.read(recurringProvider.notifier).createRecurring(recurring);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final isEditing = widget.loanToEdit != null;

    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }

    return Dialog(
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
                  Text(
                    isEditing ? 'Edit Loan Record' : 'Record Loan or Debt',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _loanType,
                    decoration: const InputDecoration(labelText: 'Classification'),
                    items: const [
                      DropdownMenuItem(value: 'borrowed', child: Text('Borrowed Money (Liability / Debt)')),
                      DropdownMenuItem(value: 'lent', child: Text('Lent to Others (Receivable / Asset)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _loanType = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _loanType == 'borrowed' ? 'Lender / Bank Name *' : 'Borrower / Friend Name *',
                      hintText: _loanType == 'borrowed' ? 'e.g. HDFC Home Loan' : 'e.g. Alex',
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: accounts.any((a) => a.id == _accountId)
                        ? _accountId
                        : (accounts.isNotEmpty ? accounts.first.id : null),
                    decoration: const InputDecoration(labelText: 'Linked Bank Account *'),
                    items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Flexible / Floating Interest Rate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                      'Enable for variable loans (repo-rate linked or fluctuating rates)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    value: _isFlexibleInterest,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isFlexibleInterest = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _principalController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Principal Amount *', hintText: '0.00'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _interestController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: _isFlexibleInterest ? 'Floating Rate (%)' : 'Interest Rate (%)',
                            hintText: '8.5',
                            helperText: _isFlexibleInterest ? 'Variable benchmark rate' : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _termController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Tenure (Months)', hintText: '12'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emiController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Monthly EMI Amount', hintText: '0.00'),
                        ),
                      ),
                    ],
                  ),
                  if ((double.tryParse(_emiController.text.trim()) ?? 0.0) > 0) ...[
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-Schedule Recurring Monthly EMI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Queues this EMI in Scheduled & Recurring payments module', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      value: _createRecurringSchedule,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _createRecurringSchedule = val),
                    ),
                  ],
                  if (!isEditing) ...[
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _loanType == 'borrowed'
                            ? 'Disburse Principal to Account (+)'
                            : 'Disburse Principal from Account (-)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _loanType == 'borrowed'
                            ? 'Records an income transaction and increases your account balance'
                            : 'Records an expense transaction and decreases your account balance',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: _disburseToAccount,
                      activeColor: AppColors.income,
                      onChanged: (val) => setState(() => _disburseToAccount = val),
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
                        child: Text(isEditing ? 'Save' : 'Record Loan'),
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
