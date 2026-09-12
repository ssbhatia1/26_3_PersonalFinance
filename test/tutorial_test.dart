import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/providers/auth_provider.dart';
import 'package:personal_finance/providers/database_provider.dart';
import 'package:personal_finance/providers/onboarding_provider.dart';
import 'package:personal_finance/core/widgets/responsive_scaffold.dart';
import 'package:personal_finance/main.dart';
import 'package:personal_finance/ui/auth/auth_screen.dart';
import 'package:personal_finance/ui/onboarding/tutorial_screen.dart';
import 'package:personal_finance/ui/splash/splash_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(isInitializing: false);
  }
}

class _MockOnboardingNotifier extends OnboardingNotifier {
  @override
  OnboardingState build() {
    return const OnboardingState(isInitializing: false, hasSeenTutorial: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase testDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testDb = AppDatabase.inMemory();
    await testDb.database;
  });

  tearDown(() async {
    await testDb.close();
  });

  group('Onboarding State & Provider Tests', () {
    test('OnboardingNotifier default state and completion lifecycle', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
      );
      addTearDown(container.dispose);

      // Trigger initial load
      await container.read(onboardingProvider.notifier).initOnboarding();
      expect(container.read(onboardingProvider).hasSeenTutorial, isFalse);

      // Complete tutorial
      await container.read(onboardingProvider.notifier).completeTutorial();
      expect(container.read(onboardingProvider).hasSeenTutorial, isTrue);

      // Reset tutorial
      await container.read(onboardingProvider.notifier).resetTutorial();
      expect(container.read(onboardingProvider).hasSeenTutorial, isFalse);
    });
  });

  group('TutorialScreen Widget Tests', () {
    testWidgets('TutorialScreen renders 5 slides and navigation controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: TutorialScreen(isFromSettings: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check initial slide (Slide 1: Account Hub)
      expect(find.text('Personal Finance'), findsOneWidget);
      expect(find.text('1 of 5 • Account Hub'), findsOneWidget);
      expect(find.text('Unified Multi-Account Ledger'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Advance to Slide 2 (Transactions)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 5 • Transactions'), findsOneWidget);
      expect(find.text('Smart Income, Expense & Transfers'), findsOneWidget);

      // Advance to Slide 3 (Budgeting)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 5 • Budgeting'), findsOneWidget);
      expect(find.text('Proactive Budgets & Spending Limits'), findsOneWidget);

      // Advance to Slide 4 (Loans & Debts)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('4 of 5 • Loans & Debts'), findsOneWidget);
      expect(find.text('Track Loans, EMIs & Money Lent'), findsOneWidget);

      // Advance to Slide 5 (Privacy & Analytics)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('5 of 5 • Privacy & Insights'), findsOneWidget);
      expect(find.text('Deep Analytics, 100% Private'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('TutorialScreen first-time mode shows Skip Intro and Get Started', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: TutorialScreen(isFromSettings: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip Intro'), findsOneWidget);

      // Advance to 5th slide
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
    });
  });

  group('SplashScreen Widget Tests', () {
    testWidgets('SplashScreen mounts branded elements and loading indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_MockAuthNotifier.new),
            onboardingProvider.overrideWith(_MockOnboardingNotifier.new),
          ],
          child: const MaterialApp(
            home: SplashScreen(minDuration: Duration(seconds: 10)),
          ),
        ),
      );

      // Pump single frame to verify UI structure
      await tester.pump();

      expect(find.text('Personal Finance'), findsOneWidget);
      expect(find.text('PRIVATE  •  OFFLINE-FIRST  •  LEDGER'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('100% On-Device SQLite  •  Zero Cloud Dependency'), findsOneWidget);
    });
  });

  group('AppEntryGate Integration & Sign-In Flow Tests', () {
    testWidgets('Transitions from AuthScreen to ResponsiveScaffold upon successful sign in', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: const PersonalFinanceApp(minSplashDuration: Duration.zero),
        ),
      );

      // Allow real-world FFI database queries to complete
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TutorialScreen), findsOneWidget);

      // Tap Skip Intro to proceed to AuthScreen
      await tester.tap(find.text('Skip Intro'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Dismiss first-time reminder prompt if shown
      if (find.text('Maybe Later').evaluate().isNotEmpty) {
        await tester.tap(find.text('Maybe Later'));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }

      // Now AuthScreen is active
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);

      // Tap Sign In button with seeded demo credentials (demouser / demo123)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Should seamlessly navigate to ResponsiveScaffold!
      expect(find.byType(ResponsiveScaffold), findsOneWidget);

      // Allow background initialization and FFI SQLite transactions to complete before tearDown
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
