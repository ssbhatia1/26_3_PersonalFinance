import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/payment_record.dart';
import '../../data/models/recurring_transaction.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/settings_provider.dart';
import 'edit_payment_record_dialog.dart';
import 'flexible_payment_dialog.dart';
import 'recurring_form_dialog.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedHistoryStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddSchedule(BuildContext context, {bool isOneTime = false}) {
    showDialog(
      context: context,
      builder: (_) => RecurringFormDialog(initialIsOneTime: isOneTime),
    );
  }

  void _openEdit(BuildContext context, RecurringTransaction r) {
    showDialog(
      context: context,
      builder: (ctx) => RecurringFormDialog(recurringToEdit: r),
    );
  }

  void _openEditPaymentRecord(PaymentRecordModel record) {
    EditPaymentRecordDialog.show(context, record);
  }

  void _showUndoPaymentSnackBar(PaymentRecordModel payment, double amount) {
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    final curr = settings.currency;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Paid ${payment.title} (${CurrencyFormatter.format(amount, symbol: curr)})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.asset,
          onPressed: () async {
            try {
              await ref.read(recurringProvider.notifier).undoPayment(payment.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payment undone for ${payment.title}. Balances restored.'),
                    backgroundColor: Colors.blueGrey,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error undoing payment: $e'), backgroundColor: AppColors.error),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _handlePaymentAction(PaymentRecordModel payment, {bool forceDialog = false}) async {
    if (payment.isFlexible || forceDialog) {
      await FlexiblePaymentDialog.show(context, payment);
    } else {
      try {
        await ref.read(recurringProvider.notifier).executePayment(payment.id);
        _showUndoPaymentSnackBar(payment, payment.amount);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _handleSkip(PaymentRecordModel payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip Payment Cycle?'),
        content: Text('Are you sure you want to skip the upcoming payment of ${payment.title}? This cycle will be marked as skipped.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Skip Cycle')),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(recurringProvider.notifier).skipPayment(payment.id, reason: 'Skipped by user');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment skipped for ${payment.title}')),
        );
      }
    }
  }

  Future<void> _handleFail(PaymentRecordModel payment) async {
    final reasonController = TextEditingController(text: 'Insufficient funds');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Payment as Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark ${payment.title} as failed. Enter reason:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Failure Reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Failure'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(recurringProvider.notifier).failPayment(payment.id, failureReason: reasonController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked payment as failed for ${payment.title}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recurringAsync = ref.watch(recurringProvider);
    final upcomingAsync = ref.watch(upcomingPaymentsProvider);
    final historyAsync = ref.watch(paymentRecordsProvider(_selectedHistoryStatus));
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled & Recurring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline_rounded),
            tooltip: 'Run Due Transactions Now',
            onPressed: () async {
              final count = await ref.read(recurringProvider.notifier).processDue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(count > 0 ? 'Processed $count due payments.' : 'No payments currently due.'),
                    backgroundColor: count > 0 ? AppColors.asset : null,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Schedule or Payment',
            onPressed: () => _openAddSchedule(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.repeat_rounded), text: 'Schedules'),
            Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Due & Upcoming'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Payment Activity'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Top KPI Overview Banner
          _buildTopSummaryBanner(recurringAsync, upcomingAsync, curr, isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSchedulesTab(recurringAsync, curr, isDark),
                _buildUpcomingTab(upcomingAsync, curr, isDark),
                _buildHistoryTab(historyAsync, curr, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummaryBanner(
    AsyncValue<List<RecurringTransaction>> recurringAsync,
    AsyncValue<List<PaymentRecordModel>> upcomingAsync,
    String curr,
    bool isDark,
  ) {
    final schedules = recurringAsync.value ?? [];
    final activeCount = schedules.where((s) => s.isActive).length;

    final upcomingList = upcomingAsync.value ?? [];
    final now = DateTime.now();
    final pendingCount = upcomingList.where((p) => p.isPending || p.dueDate.isBefore(now)).length;
    final upcoming7DaysCount = upcomingList.where((p) => p.dueDate.isBefore(now.add(const Duration(days: 7)))).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _kpiItem(
              icon: Icons.repeat_rounded,
              color: AppColors.primary,
              label: 'Active Schedules',
              value: '$activeCount',
            ),
          ),
          Container(width: 1, height: 32, color: Colors.grey.withOpacity(0.3)),
          Expanded(
            child: _kpiItem(
              icon: Icons.warning_amber_rounded,
              color: pendingCount > 0 ? AppColors.expense : Colors.grey,
              label: 'Due Now / Pending',
              value: '$pendingCount',
            ),
          ),
          Container(width: 1, height: 32, color: Colors.grey.withOpacity(0.3)),
          Expanded(
            child: _kpiItem(
              icon: Icons.event_available_rounded,
              color: AppColors.income,
              label: 'Due in 7 Days',
              value: '$upcoming7DaysCount',
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiItem({required IconData icon, required Color color, required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  // TAB 1: Schedules
  Widget _buildSchedulesTab(AsyncValue<List<RecurringTransaction>> recurringAsync, String curr, bool isDark) {
    return recurringAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No payment schedules found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Set up one-time or repeating schedules for bills, rent, or salaries.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openAddSchedule(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Schedule'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, idx) {
            final r = items[idx];
            final isIncome = r.type == 'income';
            final isTransfer = r.type == 'transfer';
            final color = isTransfer
                ? AppColors.transfer
                : (isIncome ? AppColors.income : AppColors.expense);

            final isDueSoon = r.nextExecutionDate.isBefore(DateTime.now().add(const Duration(days: 2)));

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDueSoon && r.isActive ? color.withOpacity(0.5) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: color.withAlpha(25),
                          child: Icon(
                            isTransfer
                                ? Icons.swap_horiz_rounded
                                : (isIncome ? Icons.arrow_downward_rounded : Icons.schedule_rounded),
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!r.isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.grey.withAlpha(40), borderRadius: BorderRadius.circular(6)),
                                      child: const Text('PAUSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.isTransfer
                                    ? '${r.frequencyDisplayLabel} • From: ${r.sourceAccountName ?? "Account"} → To: ${r.destinationAccountName ?? "Account"}'
                                    : (r.isIncome
                                        ? '${r.frequencyDisplayLabel} • Deposit into: ${r.sourceAccountName ?? "Account"}'
                                        : '${r.frequencyDisplayLabel} • Paid from: ${r.sourceAccountName ?? "Account"}'),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(r.amount, symbol: curr),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: color,
                              ),
                            ),
                            if (r.isFlexibleAmount)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Flexible',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              r.isOneTime ? Icons.event_available_rounded : Icons.calendar_today_rounded,
                              size: 14,
                              color: isDueSoon ? AppColors.expense : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              r.isOneTime
                                  ? 'Date: ${DateFormatter.formatFullDate(r.nextExecutionDate)}'
                                  : 'Next: ${DateFormatter.formatFullDate(r.nextExecutionDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isDueSoon ? FontWeight.bold : FontWeight.normal,
                                color: isDueSoon ? AppColors.expense : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Switch(
                              value: r.isActive,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                ref.read(recurringProvider.notifier).toggleActive(r.id, val);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit Schedule',
                              onPressed: () => _openEdit(context, r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              tooltip: 'Delete Schedule',
                              onPressed: () {
                                ref.read(recurringProvider.notifier).deleteRecurring(r.id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading schedules: $err')),
    );
  }

  // TAB 2: Due & Upcoming Payments
  Widget _buildUpcomingTab(AsyncValue<List<PaymentRecordModel>> upcomingAsync, String curr, bool isDark) {
    return upcomingAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 56, color: AppColors.income),
                SizedBox(height: 12),
                Text('All caught up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('No payments due in the next 30 days.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final now = DateTime.now();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, idx) {
            final p = items[idx];
            final isDueOrPast = p.isPending || p.dueDate.isBefore(now);
            final daysUntil = p.dueDate.difference(now).inDays;

            String statusLabel;
            Color statusColor;
            if (p.isPending) {
              statusLabel = 'Pending Review';
              statusColor = AppColors.primary;
            } else if (isDueOrPast) {
              statusLabel = 'Due Now';
              statusColor = AppColors.expense;
            } else if (daysUntil == 0) {
              statusLabel = 'Due Today';
              statusColor = AppColors.expense;
            } else if (daysUntil == 1) {
              statusLabel = 'Tomorrow';
              statusColor = Colors.orange;
            } else {
              statusLabel = 'In $daysUntil days';
              statusColor = Colors.blue;
            }

            final cardWidget = Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDueOrPast ? AppColors.expense.withOpacity(0.5) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(
                                p.isTransfer
                                    ? '${DateFormatter.formatFullDate(p.dueDate)} • From: ${p.sourceAccountName ?? "Account"} → To: ${p.destinationAccountName ?? "Account"}'
                                    : (p.isIncome
                                        ? '${DateFormatter.formatFullDate(p.dueDate)} • Deposit into: ${p.sourceAccountName ?? "Account"}'
                                        : '${DateFormatter.formatFullDate(p.dueDate)} • Paid from: ${p.sourceAccountName ?? "Account"}'),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(p.amount, symbol: curr),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            if (p.isFlexible)
                              const Text('Flexible Est.', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Record',
                          onPressed: () => _openEditPaymentRecord(p),
                        ),
                        if (!p.isFlexible)
                          IconButton(
                            icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                            tooltip: 'Flexible / Custom Amount',
                            onPressed: () => _handlePaymentAction(p, forceDialog: true),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _handleSkip(p),
                          child: const Text('Skip', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          onPressed: () => _handleFail(p),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Mark Failed'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _handlePaymentAction(p),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.isFlexible ? AppColors.primary : AppColors.asset,
                            foregroundColor: Colors.black,
                          ),
                          icon: Icon(p.isFlexible ? Icons.edit_note_rounded : Icons.check_circle_outline, size: 16),
                          label: Text(p.isFlexible ? 'Confirm & Pay' : 'Pay Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            return Dismissible(
              key: ValueKey('due_${p.id}'),
              direction: DismissDirection.startToEnd,
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.asset,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.black, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Slide to Pay',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await _handlePaymentAction(p);
                }
                return false;
              },
              child: cardWidget,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading upcoming payments: $err')),
    );
  }

  // TAB 3: Payment Activity Log
  Widget _buildHistoryTab(AsyncValue<List<PaymentRecordModel>> historyAsync, String curr, bool isDark) {
    return Column(
      children: [
        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _filterChip('all', 'All Activity'),
              const SizedBox(width: 8),
              _filterChip('completed', 'Completed'),
              const SizedBox(width: 8),
              _filterChip('pending', 'Pending'),
              const SizedBox(width: 8),
              _filterChip('scheduled', 'Scheduled'),
              const SizedBox(width: 8),
              _filterChip('skipped', 'Skipped'),
              const SizedBox(width: 8),
              _filterChip('failed', 'Failed'),
            ],
          ),
        ),
        Expanded(
          child: historyAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No payment records found for this filter.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final record = records[idx];
                  Color statusColor;
                  IconData statusIcon;

                  switch (record.status.toLowerCase()) {
                    case 'completed':
                      statusColor = AppColors.income;
                      statusIcon = Icons.check_circle_rounded;
                      break;
                    case 'pending':
                      statusColor = AppColors.primary;
                      statusIcon = Icons.hourglass_top_rounded;
                      break;
                    case 'skipped':
                      statusColor = Colors.blueGrey;
                      statusIcon = Icons.skip_next_rounded;
                      break;
                    case 'failed':
                      statusColor = AppColors.error;
                      statusIcon = Icons.cancel_rounded;
                      break;
                    case 'scheduled':
                    default:
                      statusColor = Colors.blue;
                      statusIcon = Icons.schedule_rounded;
                      break;
                  }

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openEditPaymentRecord(record),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(statusIcon, color: statusColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    record.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(record.amount, symbol: curr),
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: statusColor),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit Transaction Record',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _openEditPaymentRecord(record),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Due: ${DateFormatter.formatFullDate(record.dueDate)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    record.status.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record.isTransfer
                                  ? 'From: ${record.sourceAccountName ?? "Account"} → To: ${record.destinationAccountName ?? "Account"}'
                                  : (record.isIncome
                                      ? 'Received in: ${record.sourceAccountName ?? "Account"}'
                                      : 'Paid from: ${record.sourceAccountName ?? "Account"}'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey),
                            ),
                            if (record.executionDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Executed: ${DateFormatter.formatDisplay(record.executionDate!)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                            if (record.failureReason != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reason: ${record.failureReason}',
                                style: const TextStyle(fontSize: 11, color: AppColors.error),
                              ),
                            ],
                            if (record.notes != null && record.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Notes: ${record.notes}',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading activity: $err')),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedHistoryStatus == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedHistoryStatus = key);
      },
    );
  }
}
