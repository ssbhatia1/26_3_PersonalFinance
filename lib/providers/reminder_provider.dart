import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/settings_repository.dart';
import 'database_provider.dart';

class ReminderState {
  final bool isEnabled;
  final TimeOfDay reminderTime;
  final bool hasBeenPrompted;
  final bool isInitializing;

  const ReminderState({
    this.isEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 20, minute: 0),
    this.hasBeenPrompted = false,
    this.isInitializing = true,
  });

  ReminderState copyWith({
    bool? isEnabled,
    TimeOfDay? reminderTime,
    bool? hasBeenPrompted,
    bool? isInitializing,
  }) {
    return ReminderState(
      isEnabled: isEnabled ?? this.isEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      hasBeenPrompted: hasBeenPrompted ?? this.hasBeenPrompted,
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }

  String get timeFormatted {
    final hour = reminderTime.hourOfPeriod == 0 ? 12 : reminderTime.hourOfPeriod;
    final minute = reminderTime.minute.toString().padLeft(2, '0');
    final period = reminderTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String get timeString {
    final h = reminderTime.hour.toString().padLeft(2, '0');
    final m = reminderTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class ReminderNotifier extends Notifier<ReminderState> {
  static const String keyEnabled = 'daily_reminder_enabled';
  static const String keyTime = 'daily_reminder_time';
  static const String keyPrompted = 'daily_reminder_prompted';

  SettingsRepository get _settingsRepo => ref.read(settingsRepositoryProvider);

  @override
  ReminderState build() {
    Future.microtask(initReminder);
    return const ReminderState(isInitializing: true);
  }

  Future<void> initReminder() async {
    try {
      final enabledStr = await _settingsRepo.getSetting(keyEnabled, defaultValue: 'false');
      final timeStr = await _settingsRepo.getSetting(keyTime, defaultValue: '20:00');
      final promptedStr = await _settingsRepo.getSetting(keyPrompted, defaultValue: 'false');

      TimeOfDay parsedTime = const TimeOfDay(hour: 20, minute: 0);
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 20;
        final m = int.tryParse(parts[1]) ?? 0;
        parsedTime = TimeOfDay(hour: h, minute: m);
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        isEnabled: enabledStr.trim().toLowerCase() == 'true',
        reminderTime: parsedTime,
        hasBeenPrompted: promptedStr.trim().toLowerCase() == 'true',
        isInitializing: false,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(isInitializing: false);
    }
  }

  Future<void> toggleReminder(bool enabled) async {
    state = state.copyWith(isEnabled: enabled);
    try {
      await _settingsRepo.setSetting(keyEnabled, enabled ? 'true' : 'false');
    } catch (_) {}
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    state = state.copyWith(reminderTime: time);
    try {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      await _settingsRepo.setSetting(keyTime, '$h:$m');
    } catch (_) {}
  }

  Future<void> setupFirstTimeReminder({
    required bool enabled,
    TimeOfDay? time,
  }) async {
    final finalTime = time ?? state.reminderTime;
    state = state.copyWith(
      isEnabled: enabled,
      reminderTime: finalTime,
      hasBeenPrompted: true,
    );
    try {
      final h = finalTime.hour.toString().padLeft(2, '0');
      final m = finalTime.minute.toString().padLeft(2, '0');
      await _settingsRepo.setSetting(keyEnabled, enabled ? 'true' : 'false');
      await _settingsRepo.setSetting(keyTime, '$h:$m');
      await _settingsRepo.setSetting(keyPrompted, 'true');
    } catch (_) {}
  }
}

final reminderProvider = NotifierProvider<ReminderNotifier, ReminderState>(
  ReminderNotifier.new,
);
