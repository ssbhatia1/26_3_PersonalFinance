import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../data/repositories/investment_repository.dart';
import '../data/repositories/loan_repository.dart';
import '../data/repositories/recurring_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/transaction_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AccountRepository(db);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TransactionRepository(db);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoryRepository(db);
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BudgetRepository(db);
});

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);
  return RecurringRepository(db, txRepo);
});

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);
  return LoanRepository(db, txRepo);
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoalRepository(db);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);
  return SettingsRepository(db, txRepo);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AuthRepository(db);
});

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AttachmentRepository(db);
});

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return InvestmentRepository(db);
});

