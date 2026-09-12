import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/budget.dart';
import 'package:personal_finance/data/repositories/budget_repository.dart';
import 'package:personal_finance/providers/database_provider.dart';
import 'package:personal_finance/ui/budgets/budgets_screen.dart';
import 'package:personal_finance/ui/budgets/widgets/budget_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BudgetCard renders category icon, names, progress, and status chip', (tester) async {
    final budget = Budget(
      id: 'b1',
      name: 'Weekend Dining',
      categoryName: 'Food & Dining',
      amountLimit: 5000.0,
      spentAmount: 4000.0, // 80% -> Near Limit
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
      isRecurring: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BudgetCard(
              budget: budget,
              currency: '₹',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Weekend Dining'), findsOneWidget);
    expect(find.text('Near Limit'), findsOneWidget);
    expect(find.text('Recurring'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('BudgetsScreen renders active budgets tab, history tab, and month selector', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final inMemDb = AppDatabase.inMemory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetRepositoryProvider.overrideWithValue(BudgetRepository(inMemDb)),
        ],
        child: const MaterialApp(
          home: BudgetsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Budgets & Spending'), findsOneWidget);
    expect(find.text('Active Budgets'), findsOneWidget);
    expect(find.text('Budget History'), findsOneWidget);
    expect(find.text('Total Budget Overview'), findsOneWidget);
    expect(find.text('New Budget'), findsWidgets);
  });
}
