import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';
import 'package:personal_finance/providers/database_provider.dart';
import 'package:personal_finance/providers/recurring_provider.dart';
import 'package:personal_finance/ui/dashboard/dashboard_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('DashboardScreen renders clean minimal executive summary', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final db = AppDatabase.inMemory();
    final accRepo = AccountRepository(db);
    final txRepo = TransactionRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accRepo),
          transactionRepositoryProvider.overrideWithValue(txRepo),
          upcomingPaymentsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify AppBar and Minimal Title
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    // 2. Verify Minimal Executive Summary Card Elements
    expect(find.text('Financial Overview'), findsOneWidget);
    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Available Balance'), findsOneWidget);
    expect(find.text('Total Inflow'), findsOneWidget);
    expect(find.text('Total Outflow'), findsOneWidget);

    // 3. Verify Alerts & Accounts Carousel
    expect(find.text('Alerts & Upcoming Payments'), findsOneWidget);
    expect(find.text('Accounts & Vaults'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);

    // 4. Verify link to detailed Reports & Analysis exists
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders without overflow on compact mobile screen (360x640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final db = AppDatabase.inMemory();
    final accRepo = AccountRepository(db);
    final txRepo = TransactionRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accRepo),
          transactionRepositoryProvider.overrideWithValue(txRepo),
          upcomingPaymentsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Financial Overview'), findsOneWidget);
    expect(find.text('Total Balance'), findsOneWidget);
  });
}
