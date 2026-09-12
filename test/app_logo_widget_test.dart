import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo renders with custom dimensions and border radius', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(size: 48, borderRadius: 12),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('AppLogo renders with shadow enabled', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(size: 64, borderRadius: 16, showShadow: true),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
    final containerFinder = find.descendant(
      of: find.byType(AppLogo),
      matching: find.byType(Container),
    );
    expect(containerFinder, findsWidgets);
  });

  testWidgets('AppLogo wraps in Hero when heroTag is provided', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(size: 72, heroTag: 'test_product_logo'),
        ),
      ),
    );

    expect(find.byType(Hero), findsOneWidget);
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'test_product_logo');
  });
}
