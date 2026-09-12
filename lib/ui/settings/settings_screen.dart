import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/settings_provider.dart';
import '../accounts/accounts_screen.dart';
import '../onboarding/tutorial_screen.dart';
import 'categories_screen.dart';
import 'export_data_dialog.dart';
import 'profile_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Generating complete offline backup file...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final savedPath = await ref.read(settingsProvider.notifier).exportFullBackupToFile();
      if (savedPath != null) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Backup file created successfully:\n$savedPath'),
            backgroundColor: AppColors.income,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Backup creation failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result.isEmpty) return;

      final picked = result.first;
      final bytes = await picked.readAsBytes();
      final content = utf8.decode(bytes);

      if (!context.mounted) return;

      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore from Backup File?'),
          content: Text(
            'File: ${picked.name}\n\nThis will restore all financial data (accounts, transactions, categories, budgets, and investments) from the selected backup file.\n\nExisting matching records will be safely updated. Do you wish to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore Now'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;

      final counts = await ref.read(settingsProvider.notifier).importBackupJson(content);
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            'Backup restored successfully! ${counts['accounts']} accounts, ${counts['transactions']} transactions, and ${counts['budgets']} budgets updated.',
          ),
          backgroundColor: AppColors.income,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showExportDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const ExportDataDialog(),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    final accounts = ref.read(accountProvider).accounts;
    String? defaultAccId = accounts.isNotEmpty ? accounts.first.id : null;
    String? selectedFilePath;
    String? selectedFileName;
    String? selectedFileContent;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Import Financial Data'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a .csv transaction file or .json backup file from your device, or paste CSV text below:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),

                  // Pick File Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        selectedFileName ??
                            (selectedFilePath != null
                                ? selectedFilePath!.split(RegExp(r'[\\/]')).last
                                : 'Pick File from Device (.csv / .json)'),
                      ),
                      onPressed: () async {
                        try {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['csv', 'json', 'txt'],
                          );
                          if (result.isNotEmpty) {
                            final picked = result.first;
                            final bytes = await picked.readAsBytes();
                            final content = utf8.decode(bytes);
                            setState(() {
                              selectedFileName = picked.name;
                              selectedFilePath = picked.path;
                              selectedFileContent = content;
                            });
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('File picker error: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),

                  if (selectedFileName != null || selectedFilePath != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      selectedFilePath ?? selectedFileName!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Target Account for CSV
                  DropdownButtonFormField<String>(
                    value: accounts.any((a) => a.id == defaultAccId)
                        ? defaultAccId
                        : (accounts.isNotEmpty ? accounts.first.id : null),
                    decoration: const InputDecoration(
                      labelText: 'Target Account (for CSV records)',
                      isDense: true,
                    ),
                    items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.type})'))).toList(),
                    onChanged: (v) => setState(() => defaultAccId = v),
                  ),
                  const SizedBox(height: 14),

                  // Or Paste Text Area
                  const Text('Or paste raw CSV text:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Paste comma-separated rows here...',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final scaffold = ScaffoldMessenger.of(context);

                // 1. If file content was loaded from picker
                if (selectedFileContent != null) {
                  final isJson = (selectedFileName ?? selectedFilePath ?? '').toLowerCase().endsWith('.json') ||
                      selectedFileContent!.trimLeft().startsWith('{');
                  try {
                    if (isJson) {
                      final counts = await ref.read(settingsProvider.notifier).importBackupJson(selectedFileContent!);
                      nav.pop();
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text('Backup restored: ${counts['accounts']} accounts, ${counts['transactions']} transactions, ${counts['budgets']} budgets.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      if (defaultAccId == null) {
                        scaffold.showSnackBar(const SnackBar(content: Text('Please select a target account for CSV import.')));
                        return;
                      }
                      final count = await ref.read(settingsProvider.notifier).importCsv(selectedFileContent!, defaultAccId!);
                      nav.pop();
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text('Successfully imported $count transactions from file.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    scaffold.showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: AppColors.error));
                  }
                  return;
                }

                // 2. If text was pasted
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  if (defaultAccId == null) {
                    scaffold.showSnackBar(const SnackBar(content: Text('Please select a target account for CSV import.')));
                    return;
                  }
                  final count = await ref.read(settingsProvider.notifier).importCsv(text, defaultAccId!);
                  nav.pop();
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text('Imported $count transactions from pasted text.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Import Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationIcon: const AppLogo(
        size: 52,
        borderRadius: 14,
        showShadow: true,
      ),
      applicationName: 'Personal Finance',
      applicationVersion: 'v1.0.0 (Production Release)',
      applicationLegalese: '© 2026 Personal Finance. All rights reserved.\nLocal-First SQLite Encrypted Architecture.',
      children: const [
        SizedBox(height: 14),
        Text(
          'Personal Finance is a private, high-performance offline ledger. '
          'All your financial accounts, transactions, budgets, goals, and analytics '
          'remain securely stored on this device with zero cloud tracking.',
        ),
      ],
    );
  }

  void _confirmClearAllData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Clear All Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your transactions, accounts, budgets, goals, loans, and attachments. You will start with a completely fresh, empty ledger. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(settingsProvider.notifier).clearAllData();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All financial data cleared successfully.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final reminderState = ref.watch(reminderProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = user?.fullName.isNotEmpty == true ? user!.fullName : (user?.username ?? 'Investor');
    final email = user?.email ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Profile & Account Card
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email.isNotEmpty ? email : '@${user?.username ?? 'user'}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.manage_accounts_rounded, size: 14, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Tap to manage profile & security',
                                style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Currency Preference
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Currency Symbol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Select your primary currency representation', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _currencyChoice(ref, '₹', '₹ INR (Rupee)', settings.currency),
                      _currencyChoice(ref, '\$', '\$ USD (Dollar)', settings.currency),
                      _currencyChoice(ref, '€', '€ EUR (Euro)', settings.currency),
                      _currencyChoice(ref, '£', '£ GBP (Pound)', settings.currency),
                      _currencyChoice(ref, '¥', '¥ JPY (Yen)', settings.currency),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Appearance & Theme Mode
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _themeChoice(
                          ref,
                          icon: Icons.light_mode_rounded,
                          label: 'Light',
                          mode: ThemeMode.light,
                          current: settings.themeMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _themeChoice(
                          ref,
                          icon: Icons.dark_mode_rounded,
                          label: 'Dark',
                          mode: ThemeMode.dark,
                          current: settings.themeMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _themeChoice(
                          ref,
                          icon: Icons.brightness_auto_rounded,
                          label: 'System',
                          mode: ThemeMode.system,
                          current: settings.themeMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Manage Accounts & Balances Tile
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.income.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.income, size: 20),
              ),
              title: const Text('Manage Accounts & Balances', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Configure settings, edit balances, or manage all 15 account types'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Manage Categories Tile
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
              ),
              title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Add, edit, or delete Income, Expense & Transfer categories'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CategoriesManagementScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Daily Reminder & Habit Notifications
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.income.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.alarm_on_rounded, color: AppColors.income, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Reminder',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Nudge to log daily transactions',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: reminderState.isEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          ref.read(reminderProvider.notifier).toggleReminder(val);
                        },
                      ),
                    ],
                  ),
                  if (reminderState.isEnabled) ...[
                    const Divider(height: 20),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: reminderState.reminderTime,
                        );
                        if (picked != null) {
                          ref.read(reminderProvider.notifier).setReminderTime(picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text(
                                  'Reminder Time',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    reminderState.timeFormatted,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 12, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Interactive App Tutorial & Guide
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_rounded, color: AppColors.info),
              title: const Text('App Tutorial & Financial Guide', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Review the 5-step walkthrough explaining accounts, budgets, loans, and privacy'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TutorialScreen(isFromSettings: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Backup & Restore Financial Records
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: const Text('Create Backup File', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Export complete offline ledger (.json) to device storage'),
                  trailing: const Icon(Icons.download_rounded),
                  onTap: () => _createBackup(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.income.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.income, size: 20),
                  ),
                  title: const Text('Restore from Backup File', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Select a .json backup file to restore accounts & transactions'),
                  trailing: const Icon(Icons.upload_file_rounded),
                  onTap: () => _restoreBackup(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Color(0xFF8B5CF6), size: 20),
                  ),
                  title: const Text('Export CSV Statement', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Export transaction records as a spreadsheet table (.csv)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showExportDataDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.input_rounded, color: Colors.grey, size: 20),
                  ),
                  title: const Text('Import CSV / Raw Text', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Import transactions from bank CSV statements or paste text'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showImportDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clear All Financial Data
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
              title: const Text('Clear All Data', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              subtitle: const Text('Permanently wipes all transactions, accounts, budgets, and records'),
              onTap: () => _confirmClearAllData(context, ref),
            ),
          ),
          const SizedBox(height: 14),

          // About Personal Finance
          Card(
            child: ListTile(
              leading: const AppLogo(size: 32, borderRadius: 8),
              title: const Text('About Personal Finance', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('App version, offline architecture & open-source licenses'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => _showAboutAppDialog(context),
            ),
          ),
          const SizedBox(height: 24),

          // Privacy & Architecture Info
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showAboutAppDialog(context),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(
                child: Column(
                  children: [
                    AppLogo(size: 64, borderRadius: 16, showShadow: true),
                    SizedBox(height: 12),
                    Text(
                      'Personal Finance',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage Better. Save Smarter.',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Local-First SQLite Architecture\n100% of your financial records are stored securely on this device.\nNo external servers or cloud dependencies.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'v1.0.0 Production Release • Tap for Details',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _currencyChoice(WidgetRef ref, String symbol, String label, String current) {
    final isSelected = current == symbol;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(settingsProvider.notifier).setCurrency(symbol),
    );
  }

  Widget _themeChoice(
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required ThemeMode mode,
    required ThemeMode current,
  }) {
    final isSelected = current == mode;
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.darkBorder, width: isSelected ? 2 : 1),
      ),
      onPressed: () => ref.read(settingsProvider.notifier).setThemeMode(mode),
    );
  }
}
