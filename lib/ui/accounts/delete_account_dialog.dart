import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';

class DeleteAccountDialog extends ConsumerStatefulWidget {
  final Account account;

  const DeleteAccountDialog({super.key, required this.account});

  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final TextEditingController _nameConfirmController = TextEditingController();
  bool _understandCheckbox = false;
  bool _isLoading = false;
  int _transactionCount = 0;
  bool _isStatsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _nameConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final repo = ref.read(accountRepositoryProvider);
    final stats = await repo.getAccountTransactionStats(widget.account.id);
    if (mounted) {
      setState(() {
        _transactionCount = (stats['transactionCount'] as int?) ?? 0;
        _isStatsLoaded = true;
      });
    }
  }

  bool get _canDelete {
    final typedName = _nameConfirmController.text.trim().toLowerCase();
    final actualName = widget.account.name.trim().toLowerCase();
    return _understandCheckbox && typedName == actualName && !_isLoading;
  }

  Future<void> _executeDelete() async {
    if (!_canDelete) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(accountProvider.notifier).deleteAccount(widget.account.id);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "${widget.account.name}" and all associated records were deleted.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.dangerous_outlined, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Irreversible Action',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Deleting "${widget.account.name}" will permanently remove this account and all associated transactions, records, and spending history. This cannot be undone.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Account summary stats
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Balance:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text(
                          CurrencyFormatter.format(widget.account.currentBalance, symbol: curr),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: widget.account.currentBalance < 0 ? AppColors.expense : AppColors.income,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Associated Transactions:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text(
                          _isStatsLoaded ? '$_transactionCount transactions' : 'Loading...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Account Type:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text(widget.account.type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Safety Verification 1: Checkbox
              CheckboxListTile(
                value: _understandCheckbox,
                onChanged: _isLoading
                    ? null
                    : (val) {
                        setState(() => _understandCheckbox = val ?? false);
                      },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.error,
                title: const Text(
                  'I understand that all transactions and data associated with this account will be permanently removed.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 12),

              // Safety Verification 2: Type account name
              Text(
                'Type "${widget.account.name}" to confirm deletion:',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameConfirmController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: widget.account.name,
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.error.withAlpha(60),
            disabledForegroundColor: Colors.white54,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _canDelete ? _executeDelete : null,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete Account Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
