import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/main.dart';
import 'package:personal_finance/providers/database_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase.inMemory()),
        ],
        child: const PersonalFinanceApp(),
      ),
    );
    expect(find.byType(PersonalFinanceApp), findsOneWidget);
  });
}
