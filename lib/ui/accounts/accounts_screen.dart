import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/investment_provider.dart';
import '../../providers/settings_provider.dart';
import '../investments/investments_screen.dart';
import 'account_adjustment_dialog.dart';
import 'account_detail_screen.dart';
import 'account_form_dialog.dart';
import 'delete_account_dialog.dart';
import '../transactions/transaction_form_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _openTransfer(BuildContext context, {String? sourceAccountId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionFormScreen(
        preselectedAccountId: sourceAccountId,
        initialTabIndex: 2, // Transfer tab
      ),
    );
  }

  void _openAddAccount(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => const AccountFormDialog(),
    );
    if (added == true && context.mounted) {
      ref.read(accountProvider.notifier).loadAccounts();
    }
  }

  void _openEditAccount(BuildContext context, WidgetRef ref, Account acc) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AccountFormDialog(accountToEdit: acc),
    );
    if (updated == true && context.mounted) {
      ref.read(accountProvider.notifier).loadAccounts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account details for ${acc.name} updated successfully')),
      );
    }
  }

  void _openAccountAdjustment(BuildContext context, WidgetRef ref, Account acc) async {
    final adjusted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AccountAdjustmentDialog(account: acc),
    );
    if (adjusted == true && context.mounted) {
      ref.read(accountProvider.notifier).loadAccounts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Balance for ${acc.name} updated successfully')),
      );
    }
  }

  void _openAccountDetail(BuildContext context, String accountId, {int initialTab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountDetailScreen(accountId: accountId, initialTabIndex: initialTab),
      ),
    );
  }

  void _openDeleteAccount(BuildContext context, Account acc) {
    showDialog(
      context: context,
      builder: (ctx) => DeleteAccountDialog(account: acc),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;

    final accounts = accountState.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts & Portfolios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Transfer Funds Between Accounts',
            onPressed: () => _openTransfer(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Account',
            onPressed: () => _openAddAccount(context, ref),
          ),
        ],
      ),
      body: accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 64, borderRadius: 16, showShadow: true),
                  const SizedBox(height: 16),
                  const Text('No accounts configured yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openAddAccount(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Account'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
              children: [
                // Investments Portfolio Banner
                Consumer(
                  builder: (context, ref, _) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final invSummary = ref.watch(investmentSummaryProvider);
                    final totalCurrent = invSummary['totalCurrentValue'] as double? ?? 0.0;
                    final activeCount = invSummary['activeCount'] as int? ?? 0;
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InvestmentsScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.investment.withAlpha(isDark ? 50 : 25),
                              AppColors.primary.withAlpha(isDark ? 30 : 15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.investment.withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.investment.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.trending_up_rounded, color: AppColors.investment, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Investments Portfolio',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$activeCount Active Assets (FD, RD, Mutual Funds, Stocks, Bonds)',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(totalCurrent, symbol: curr),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.investment),
                                ),
                                const SizedBox(height: 2),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.investment)),
                                    Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.investment),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                _buildAccountSection(
                  context,
                  ref,
                  title: 'Bank & Salary Accounts',
                  icon: Icons.account_balance_rounded,
                  color: AppColors.primary,
                  accounts: accounts.where((a) => !a.isCreditCard && !a.isLoan && (a.type.toLowerCase().contains('bank') || a.type.toLowerCase().contains('salary') || a.type.toLowerCase().contains('savings') || a.type.toLowerCase().contains('current'))).toList(),
                  curr: curr,
                ),
                _buildAccountSection(
                  context,
                  ref,
                  title: 'Cash & Digital Wallets',
                  icon: Icons.payments_rounded,
                  color: AppColors.asset,
                  accounts: accounts.where((a) => a.type.toLowerCase().contains('cash') || a.type.toLowerCase().contains('wallet') || a.type.toLowerCase().contains('upi')).toList(),
                  curr: curr,
                ),
                _buildAccountSection(
                  context,
                  ref,
                  title: 'Credit Cards',
                  icon: Icons.credit_card_rounded,
                  color: AppColors.liability,
                  accounts: accounts.where((a) => a.isCreditCard).toList(),
                  curr: curr,
                ),
                _buildAccountSection(
                  context,
                  ref,
                  title: 'Fixed Deposits & Investments',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.investment,
                  accounts: accounts.where((a) => a.type.toLowerCase().contains('deposit') || a.type.toLowerCase().contains('investment')).toList(),
                  curr: curr,
                ),
                _buildAccountSection(
                  context,
                  ref,
                  title: 'Loans & Receivables',
                  icon: Icons.handshake_rounded,
                  color: AppColors.warning,
                  accounts: accounts.where((a) => a.isLoan).toList(),
                  curr: curr,
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Account> accounts,
    required String curr,
  }) {
    if (accounts.isEmpty) return const SizedBox.shrink();

    final totalBal = accounts.fold(0.0, (sum, a) => sum + a.currentBalance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                CurrencyFormatter.format(totalBal, symbol: curr),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
              ),
            ],
          ),
        ),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, idx) {
              final acc = accounts[idx];
              final isNegative = acc.currentBalance < 0;

              return ListTile(
                onTap: () => _openAccountDetail(context, acc.id),
                title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Row(
                  children: [
                    Flexible(
                      child: Text(
                        acc.institution != null ? '${acc.institution} • ${acc.type}' : acc.type,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.token_rounded, size: 10, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(
                            acc.token.length > 12 ? '${acc.token.substring(0, 10)}…' : acc.token,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(acc.currentBalance, symbol: curr),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isNegative ? AppColors.expense : AppColors.income,
                          ),
                        ),
                        if (acc.isCreditCard)
                          Text(
                            'Available: ${CurrencyFormatter.formatCompact(acc.availableCredit, symbol: curr)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      tooltip: 'Account Options',
                      onSelected: (action) {
                        if (action == 'edit') {
                          _openEditAccount(context, ref, acc);
                        } else if (action == 'adjust') {
                          _openAccountAdjustment(context, ref, acc);
                        } else if (action == 'transfer') {
                          _openTransfer(context, sourceAccountId: acc.id);
                        } else if (action == 'details') {
                          _openAccountDetail(context, acc.id, initialTab: 3);
                        } else if (action == 'transactions') {
                          _openAccountDetail(context, acc.id, initialTab: 0);
                        } else if (action == 'spending') {
                          _openAccountDetail(context, acc.id, initialTab: 1);
                        } else if (action == 'adjustments') {
                          _openAccountDetail(context, acc.id, initialTab: 2);
                        } else if (action == 'copy_token') {
                          Clipboard.setData(ClipboardData(text: acc.token));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Account token copied: ${acc.token}')),
                          );
                        } else if (action == 'delete') {
                          _openDeleteAccount(context, acc);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'copy_token',
                          child: Row(
                            children: [
                              Icon(Icons.token_rounded, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Copy Security Token', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Edit Account Data', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'adjust',
                          child: Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 18, color: AppColors.income),
                              SizedBox(width: 8),
                              Text('Adjust / Change Balance', style: TextStyle(color: AppColors.income, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'transfer',
                          child: Row(
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.transfer),
                              SizedBox(width: 8),
                              Text('Transfer Funds', style: TextStyle(color: AppColors.transfer, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'transactions',
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('View Transactions'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'spending',
                          child: Row(
                            children: [
                              Icon(Icons.pie_chart_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Account Spending'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'adjustments',
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Adjustments History'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Account Configuration'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                              SizedBox(width: 8),
                              Text('Delete Account', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
