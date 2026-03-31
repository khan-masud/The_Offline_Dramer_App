import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReminderAlertMode { ring, ringAndVibration, vibration, silent }

class NotificationPreferencesState {
  final TimeOfDay routineReminderTime;
  final ReminderAlertMode alertMode;
  final bool isLoading;

  const NotificationPreferencesState({
    this.routineReminderTime = const TimeOfDay(hour: 7, minute: 0),
    this.alertMode = ReminderAlertMode.ringAndVibration,
    this.isLoading = true,
  });

  NotificationPreferencesState copyWith({
    TimeOfDay? routineReminderTime,
    ReminderAlertMode? alertMode,
    bool? isLoading,
  }) {
    return NotificationPreferencesState(
      routineReminderTime: routineReminderTime ?? this.routineReminderTime,
      alertMode: alertMode ?? this.alertMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, NotificationPreferencesState>(
  (ref) => NotificationPreferencesNotifier(),
);

class NotificationPreferencesNotifier extends StateNotifier<NotificationPreferencesState> {
  NotificationPreferencesNotifier() : super(const NotificationPreferencesState()) {
    _load();
  }

  static const _hourKey = 'routine_reminder_hour';
  static const _minuteKey = 'routine_reminder_minute';
  static const _alertModeKey = 'notification_alert_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_hourKey) ?? 7;
    final minute = prefs.getInt(_minuteKey) ?? 0;
    final modeName = prefs.getString(_alertModeKey);
    final mode = ReminderAlertMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ReminderAlertMode.ringAndVibration,
    );

    state = state.copyWith(
      routineReminderTime: TimeOfDay(hour: hour, minute: minute),
      alertMode: mode,
      isLoading: false,
    );
  }

  Future<void> setRoutineReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
    state = state.copyWith(routineReminderTime: time);
  }

  Future<void> setAlertMode(ReminderAlertMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertModeKey, mode.name);
    state = state.copyWith(alertMode: mode);
  }
}