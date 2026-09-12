import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/security/crypto_utils.dart';
import '../../data/models/account.dart';
import '../../providers/account_provider.dart';

class AccountFormDialog extends ConsumerStatefulWidget {
  final Account? accountToEdit;

  const AccountFormDialog({super.key, this.accountToEdit});

  @override
  ConsumerState<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _nameController;
  late TextEditingController _institutionController;
  late TextEditingController _referenceController;
  late TextEditingController _currentBalanceController;
  late TextEditingController _openingBalanceController;
  late TextEditingController _limitController;
  late TextEditingController _interestController;
  late TextEditingController _notesController;

  String _selectedType = 'Bank Account';
  String _selectedStatus = 'active';
  String _selectedCurrency = 'INR';
  DateTime _openedDate = DateTime.now();
  bool _isSaving = false;

  final List<String> _accountTypes = [
    'Bank Account',
    'Savings Account',
    'Current Account',
    'Salary Account',
    'Cash',
    'Credit Card',
    'Debit Card',
    'UPI / Digital Wallet',
    'Fixed Deposit',
    'Recurring Deposit',
    'Investment Account',
    'Loan Account',
    'Money Lent',
    'Money Borrowed',
    'Other',
  ];

  final List<String> _currencies = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'AED',
    'CAD',
    'AUD',
    'JPY',
    'SGD',
    'CHF',
  ];

  @override
  void initState() {
    super.initState();
    final acc = widget.accountToEdit;
    _nameController = TextEditingController(text: acc?.name ?? '');
    _institutionController = TextEditingController(text: acc?.institution ?? '');
    _referenceController = TextEditingController(text: acc?.maskedReference ?? '');
    _currentBalanceController = TextEditingController(
      text: acc != null ? acc.currentBalance.toStringAsFixed(2) : '0.0',
    );
    _openingBalanceController = TextEditingController(
      text: acc != null ? acc.openingBalance.toStringAsFixed(2) : '0.0',
    );
    _limitController = TextEditingController(
      text: acc != null ? acc.creditLimit.toStringAsFixed(2) : '0.0',
    );
    _interestController = TextEditingController(
      text: acc != null ? acc.interestRate.toStringAsFixed(2) : '0.0',
    );
    _notesController = TextEditingController(text: acc?.notes ?? '');

    if (acc != null && _accountTypes.contains(acc.type)) {
      _selectedType = acc.type;
    }
    if (acc != null && ['active', 'inactive', 'closed', 'frozen'].contains(acc.status.toLowerCase())) {
      _selectedStatus = acc.status.toLowerCase();
    }
    if (acc != null && acc.currency.isNotEmpty) {
      _selectedCurrency = acc.currency;
    }
    if (acc?.openedAt != null) {
      _openedDate = acc!.openedAt!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _referenceController.dispose();
    _currentBalanceController.dispose();
    _openingBalanceController.dispose();
    _limitController.dispose();
    _interestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickOpenedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _openedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final institution = _institutionController.text.trim();
      final reference = _referenceController.text.trim();
      final currentBal = double.tryParse(_currentBalanceController.text.trim()) ?? 0.0;
      final openingBal = double.tryParse(_openingBalanceController.text.trim()) ?? 0.0;
      final limit = double.tryParse(_limitController.text.trim()) ?? 0.0;
      final interest = double.tryParse(_interestController.text.trim()) ?? 0.0;
      final notes = _notesController.text.trim();

      final tokenRes = reference.isNotEmpty ? CryptoUtils.tokenizeSensitiveReference(reference) : null;
      final effectiveMaskedRef = tokenRes?['maskedDisplay'] ?? (reference.isNotEmpty ? reference : null);

      if (widget.accountToEdit != null) {
        final oldAcc = widget.accountToEdit!;
        final balanceChanged = (currentBal - oldAcc.currentBalance).abs() > 0.001;
        final assignedToken = oldAcc.accountToken ?? tokenRes?['surrogateToken'] ?? oldAcc.token;

        final updated = oldAcc.copyWith(
          name: name,
          type: _selectedType,
          accountToken: assignedToken,
          institution: institution.isNotEmpty ? institution : null,
          maskedReference: effectiveMaskedRef,
          openingBalance: openingBal,
          currentBalance: oldAcc.currentBalance,
          currency: _selectedCurrency,
          status: _selectedStatus,
          creditLimit: limit,
          interestRate: interest,
          openedAt: _openedDate,
          notes: notes.isNotEmpty ? notes : null,
        );

        await ref.read(accountProvider.notifier).updateAccount(updated);

        if (balanceChanged) {
          await ref.read(accountProvider.notifier).adjustAccountBalance(
            accountId: oldAcc.id,
            newBalance: currentBal,
            reason: 'Balance corrected via Edit Account',
          );
        }
      } else {
        final assignedToken = tokenRes?['surrogateToken'] ?? CryptoUtils.generateAccountToken();

        final newAcc = Account(
          id: _uuid.v4(),
          accountToken: assignedToken,
          name: name,
          type: _selectedType,
          institution: institution.isNotEmpty ? institution : null,
          maskedReference: effectiveMaskedRef,
          openingBalance: openingBal,
          currentBalance: openingBal,
          currency: _selectedCurrency,
          status: _selectedStatus,
          creditLimit: limit,
          interestRate: interest,
          openedAt: _openedDate,
          notes: notes.isNotEmpty ? notes : null,
        );
        await ref.read(accountProvider.notifier).addAccount(newAcc);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save account: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = _selectedType == 'Credit Card';
    final isEditing = widget.accountToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.manage_accounts_rounded : Icons.account_balance_wallet_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Account Data' : 'Add New Account',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isEditing
                                ? 'Update account details, ledger balance, and settings'
                                : 'Configure a new account or financial wallet',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Form body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account Name
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Account Name *',
                            hintText: 'e.g., Primary Salary, Personal Cash, Axis Credit',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter account name' : null,
                        ),
                        const SizedBox(height: 14),

                        // Account Type & Status row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _accountTypes.contains(_selectedType) ? _selectedType : _accountTypes.first,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Account Type',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: _accountTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedType = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  prefixIcon: Icon(Icons.toggle_on_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'active', child: Text('Active')),
                                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                                  DropdownMenuItem(value: 'frozen', child: Text('Frozen')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedStatus = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Institution & Masked Reference
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _institutionController,
                                decoration: const InputDecoration(
                                  labelText: 'Institution / Bank',
                                  hintText: 'e.g. HDFC, SBI, Chase',
                                  prefixIcon: Icon(Icons.account_balance_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _referenceController,
                                decoration: const InputDecoration(
                                  labelText: 'Acct / Card # (Ref)',
                                  hintText: 'e.g. •••• 4242',
                                  prefixIcon: Icon(Icons.pin_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Balances Section
                        if (isEditing) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Account Balance Management',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _currentBalanceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  decoration: InputDecoration(
                                    labelText: isCredit ? 'Current Outstanding (Negative if debt)' : 'Current Ledger Balance',
                                    hintText: '0.0',
                                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                                    helperText: 'Modifying this updates and reconciles the account balance',
                                    helperStyle: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _openingBalanceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Initial Opening Balance',
                                    hintText: '0.0',
                                    prefixIcon: Icon(Icons.history_toggle_off_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _openingBalanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: InputDecoration(
                              labelText: isCredit ? 'Initial Outstanding (Negative if debt)' : 'Opening Balance',
                              hintText: '0.0',
                              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Credit Limit (if Credit Card)
                        if (isCredit) ...[
                          TextFormField(
                            controller: _limitController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Credit Limit',
                              hintText: 'e.g. 100000',
                              prefixIcon: Icon(Icons.credit_score_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Currency & Interest Rate
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _currencies.contains(_selectedCurrency) ? _selectedCurrency : _currencies.first,
                                decoration: const InputDecoration(
                                  labelText: 'Currency',
                                  prefixIcon: Icon(Icons.currency_exchange_rounded),
                                ),
                                items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedCurrency = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _interestController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Interest Rate (%)',
                                  hintText: 'e.g. 3.5',
                                  prefixIcon: Icon(Icons.percent_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Opening Date Tile
                        InkWell(
                          onTap: _pickOpenedDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Opening Date',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                              suffixIcon: Icon(Icons.edit_calendar_rounded, size: 20),
                            ),
                            child: Text(
                              DateFormat('dd MMMM yyyy').format(_openedDate),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes & Remarks',
                            hintText: 'Billing date, branch details, or notes',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Dialog Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Create Account'),
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
