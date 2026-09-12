import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/database/app_database.dart';
import '../data/repositories/settings_repository.dart';
import 'account_provider.dart';
import 'budget_provider.dart';
import 'database_provider.dart';
import 'goal_provider.dart';
import 'loan_provider.dart';
import 'recurring_provider.dart';
import 'transaction_provider.dart';

class SettingsState {
  final String currency;
  final ThemeMode themeMode;
  final bool isExporting;
  final String? lastExportPath;
  final String? exportMessage;

  const SettingsState({
    this.currency = '₹',
    this.themeMode = ThemeMode.light,
    this.isExporting = false,
    this.lastExportPath,
    this.exportMessage,
  });

  SettingsState copyWith({
    String? currency,
    ThemeMode? themeMode,
    bool? isExporting,
    String? lastExportPath,
    String? exportMessage,
    bool clearLastExportPath = false,
  }) {
    return SettingsState(
      currency: currency ?? this.currency,
      themeMode: themeMode ?? this.themeMode,
      isExporting: isExporting ?? this.isExporting,
      lastExportPath: clearLastExportPath ? null : (lastExportPath ?? this.lastExportPath),
      exportMessage: exportMessage ?? this.exportMessage,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  SettingsState build() {
    Future.microtask(loadSettings);
    return const SettingsState();
  }

  Future<void> loadSettings() async {
    if (!ref.mounted) return;
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final curr = await repo.getSetting('currency', defaultValue: '₹');
      if (!ref.mounted) return;
      final tmStr = await repo.getSetting('theme_mode', defaultValue: 'light');
      if (!ref.mounted) return;

      ThemeMode tm;
      if (tmStr == 'light') {
        tm = ThemeMode.light;
      } else if (tmStr == 'dark') {
        tm = ThemeMode.dark;
      } else {
        tm = ThemeMode.system;
      }

      state = state.copyWith(
        currency: curr,
        themeMode: tm,
      );
    } catch (_) {
      // Ignored if provider is disposed during test lifecycle
    }
  }

  Future<void> setCurrency(String symbol) async {
    await _repo.setSetting('currency', symbol);
    state = state.copyWith(currency: symbol);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final val = mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system');
    await _repo.setSetting('theme_mode', val);
    state = state.copyWith(themeMode: mode);
  }

  /// Exports transactions to CSV string
  Future<String> exportCsv({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _repo.exportTransactionsCsv(
      accountId: accountId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Exports transactions directly to a local .csv file on disk
  Future<String?> exportTransactionsCsvToFile({
    String? accountId,
    String? accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(isExporting: true, exportMessage: null);
    try {
      final csvContent = await _repo.exportTransactionsCsv(
        accountId: accountId,
        startDate: startDate,
        endDate: endDate,
      );

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final prefix = accountName != null
          ? '${accountName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_transactions'
          : 'transactions';
      final fileName = '${prefix}_$dateStr.csv';

      final savedPath = await _repo.saveToFile(
        content: csvContent,
        defaultFileName: fileName,
        fileExtension: 'csv',
        dialogTitle: 'Save Transactions CSV',
      );

      state = state.copyWith(
        isExporting: false,
        lastExportPath: savedPath,
        exportMessage: savedPath != null ? 'Transactions exported successfully to $savedPath' : null,
      );
      return savedPath;
    } catch (e) {
      state = state.copyWith(isExporting: false, exportMessage: 'Export failed: $e');
      return null;
    }
  }

  /// Exports full financial ledger backup into a local .json file
  Future<String?> exportFullBackupToFile() async {
    state = state.copyWith(isExporting: true, exportMessage: null);
    try {
      final jsonContent = await _repo.exportFullBackupJson();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'personal_finance_backup_$dateStr.json';

      final savedPath = await _repo.saveToFile(
        content: jsonContent,
        defaultFileName: fileName,
        fileExtension: 'json',
        dialogTitle: 'Save Full Financial Backup (JSON)',
      );

      state = state.copyWith(
        isExporting: false,
        lastExportPath: savedPath,
        exportMessage: savedPath != null ? 'Backup saved successfully to $savedPath' : null,
      );
      return savedPath;
    } catch (e) {
      state = state.copyWith(isExporting: false, exportMessage: 'Backup failed: $e');
      return null;
    }
  }

  /// Gets full backup JSON string for preview
  Future<String> getFullBackupJsonString() async {
    return await _repo.exportFullBackupJson();
  }

  /// Imports transactions from CSV string
  Future<int> importCsv(String content, String defaultAccountId) async {
    final count = await _repo.importTransactionsCsv(content, defaultAccountId);
    if (count > 0) {
      await ref.read(accountProvider.notifier).loadAccounts();
      await ref.read(transactionProvider.notifier).loadTransactions();
    }
    return count;
  }

  /// Imports transactions from a local CSV file path
  Future<int> importCsvFromFile(String filePath, String defaultAccountId) async {
    final content = await _repo.readContentFromFile(filePath);
    return await importCsv(content, defaultAccountId);
  }

  /// Imports full backup from JSON string or file
  Future<Map<String, int>> importBackupJson(String jsonContent) async {
    final results = await _repo.importBackupJson(jsonContent);
    await ref.read(accountProvider.notifier).loadAccounts();
    await ref.read(transactionProvider.notifier).loadTransactions();
    return results;
  }

  Future<Map<String, int>> importBackupFromFile(String filePath) async {
    final content = await _repo.readContentFromFile(filePath);
    return await importBackupJson(content);
  }

  Future<void> resetToDemoData() async {
    await _db.resetToDemoData();
    await ref.read(accountProvider.notifier).loadAccounts();
    await ref.read(transactionProvider.notifier).loadTransactions();
  }

  /// Completely wipes all financial records (transactions, budgets, accounts, goals, loans)
  Future<void> clearAllData() async {
    await _db.clearAllData();
    await ref.read(accountProvider.notifier).loadAccounts();
    await ref.read(transactionProvider.notifier).loadTransactions();
    await ref.read(budgetProvider.notifier).loadBudgets();
    await ref.read(loanProvider.notifier).loadLoans();
    await ref.read(goalProvider.notifier).loadGoals();
    await ref.read(recurringProvider.notifier).loadRecurring();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
