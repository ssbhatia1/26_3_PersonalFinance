import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/database/app_database.dart';
import 'core/widgets/responsive_scaffold.dart';
import 'providers/auth_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/auth/auth_screen.dart';
import 'ui/onboarding/tutorial_screen.dart';
import 'ui/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite database and clean any untokenized/sample data
  await AppDatabase.instance.database;
  await AppDatabase.instance.cleanUntokenizedData();

  runApp(
    const ProviderScope(
      child: PersonalFinanceApp(),
    ),
  );
}

class PersonalFinanceApp extends ConsumerWidget {
  final Duration minSplashDuration;

  const PersonalFinanceApp({
    super.key,
    this.minSplashDuration = const Duration(milliseconds: 2500),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Personal Finance Ledger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: AppEntryGate(minSplashDuration: minSplashDuration),
    );
  }
}

class AppEntryGate extends ConsumerStatefulWidget {
  final Duration minSplashDuration;

  const AppEntryGate({
    super.key,
    this.minSplashDuration = const Duration(milliseconds: 2500),
  });

  @override
  ConsumerState<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends ConsumerState<AppEntryGate> {
  bool _splashCompleted = false;

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);
    final authState = ref.watch(authProvider);

    Widget currentScreen;
    if (!_splashCompleted) {
      currentScreen = SplashScreen(
        key: const ValueKey('splash_screen'),
        minDuration: widget.minSplashDuration,
        onFinished: () {
          if (mounted) {
            setState(() {
              _splashCompleted = true;
            });
          }
        },
      );
    } else if (!onboardingState.hasSeenTutorial) {
      currentScreen = const TutorialScreen(key: ValueKey('tutorial_screen'));
    } else if (!authState.isAuthenticated) {
      currentScreen = const AuthScreen(key: ValueKey('auth_screen'));
    } else {
      currentScreen = const ResponsiveScaffold(key: ValueKey('main_screen'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: currentScreen,
    );
  }
}
