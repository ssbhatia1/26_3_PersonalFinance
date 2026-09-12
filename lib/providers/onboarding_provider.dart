import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/settings_repository.dart';
import 'database_provider.dart';

class OnboardingState {
  final bool hasSeenTutorial;
  final bool isInitializing;

  const OnboardingState({
    this.hasSeenTutorial = false,
    this.isInitializing = true,
  });

  OnboardingState copyWith({
    bool? hasSeenTutorial,
    bool? isInitializing,
  }) {
    return OnboardingState(
      hasSeenTutorial: hasSeenTutorial ?? this.hasSeenTutorial,
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const String onboardingKey = 'has_seen_onboarding';
  SettingsRepository get _settingsRepo => ref.read(settingsRepositoryProvider);

  @override
  OnboardingState build() {
    Future.microtask(initOnboarding);
    return const OnboardingState(isInitializing: true);
  }

  Future<void> initOnboarding() async {
    try {
      final value = await _settingsRepo.getSetting(onboardingKey, defaultValue: 'false');
      if (!ref.mounted) return;
      state = state.copyWith(
        hasSeenTutorial: value.trim().toLowerCase() == 'true',
        isInitializing: false,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        hasSeenTutorial: false,
        isInitializing: false,
      );
    }
  }

  Future<void> completeTutorial() async {
    try {
      await _settingsRepo.setSetting(onboardingKey, 'true');
      if (!ref.mounted) return;
      state = state.copyWith(hasSeenTutorial: true, isInitializing: false);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(hasSeenTutorial: true, isInitializing: false);
    }
  }

  Future<void> resetTutorial() async {
    try {
      await _settingsRepo.setSetting(onboardingKey, 'false');
      if (!ref.mounted) return;
      state = state.copyWith(hasSeenTutorial: false, isInitializing: false);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(hasSeenTutorial: false, isInitializing: false);
    }
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
