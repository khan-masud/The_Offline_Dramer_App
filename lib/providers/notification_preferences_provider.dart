import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReminderAlertMode { ring, ringAndVibration, vibration, silent }

class NotificationPreferencesState {
  final TimeOfDay routineReminderTime;
  final TimeOfDay birthdayReminderTime;
  final ReminderAlertMode alertMode;
  final int incompleteReminderIntervalHours;
  final bool enableDebtReminders;
  final TimeOfDay debtReminderTime;
  final bool debtRemindDayBefore;
  final bool isLoading;

  const NotificationPreferencesState({
    this.routineReminderTime = const TimeOfDay(hour: 7, minute: 0),
    this.birthdayReminderTime = const TimeOfDay(hour: 0, minute: 0),
    this.alertMode = ReminderAlertMode.ringAndVibration,
    this.incompleteReminderIntervalHours = 3,
    this.enableDebtReminders = true,
    this.debtReminderTime = const TimeOfDay(hour: 9, minute: 0),
    this.debtRemindDayBefore = true,
    this.isLoading = true,
  });

  NotificationPreferencesState copyWith({
    TimeOfDay? routineReminderTime,
    TimeOfDay? birthdayReminderTime,
    ReminderAlertMode? alertMode,
    int? incompleteReminderIntervalHours,
    bool? enableDebtReminders,
    TimeOfDay? debtReminderTime,
    bool? debtRemindDayBefore,
    bool? isLoading,
  }) {
    return NotificationPreferencesState(
      routineReminderTime: routineReminderTime ?? this.routineReminderTime,
      birthdayReminderTime: birthdayReminderTime ?? this.birthdayReminderTime,
      alertMode: alertMode ?? this.alertMode,
      incompleteReminderIntervalHours:
          incompleteReminderIntervalHours ?? this.incompleteReminderIntervalHours,
      enableDebtReminders: enableDebtReminders ?? this.enableDebtReminders,
      debtReminderTime: debtReminderTime ?? this.debtReminderTime,
      debtRemindDayBefore: debtRemindDayBefore ?? this.debtRemindDayBefore,
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
  static const _birthdayHourKey = 'birthday_reminder_hour';
  static const _birthdayMinuteKey = 'birthday_reminder_minute';
  static const _alertModeKey = 'notification_alert_mode';
  static const _incompleteIntervalHoursKey = 'incomplete_reminder_interval_hours';
  static const _enableDebtRemindersKey = 'enable_debt_reminders';
  static const _debtReminderHourKey = 'debt_reminder_hour';
  static const _debtReminderMinuteKey = 'debt_reminder_minute';
  static const _debtRemindDayBeforeKey = 'debt_remind_day_before';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_hourKey) ?? 7;
    final minute = prefs.getInt(_minuteKey) ?? 0;
    final bHour = prefs.getInt(_birthdayHourKey) ?? 0;
    final bMinute = prefs.getInt(_birthdayMinuteKey) ?? 0;
    final modeName = prefs.getString(_alertModeKey);
    final savedInterval = prefs.getInt(_incompleteIntervalHoursKey) ?? 3;
    final intervalHours = savedInterval < 1
        ? 1
        : (savedInterval > 12 ? 12 : savedInterval);
    final mode = ReminderAlertMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ReminderAlertMode.ringAndVibration,
    );

    final enableDebts = prefs.getBool(_enableDebtRemindersKey) ?? true;
    final dHour = prefs.getInt(_debtReminderHourKey) ?? 9;
    final dMinute = prefs.getInt(_debtReminderMinuteKey) ?? 0;
    final dDayBefore = prefs.getBool(_debtRemindDayBeforeKey) ?? true;

    state = state.copyWith(
      routineReminderTime: TimeOfDay(hour: hour, minute: minute),
      birthdayReminderTime: TimeOfDay(hour: bHour, minute: bMinute),
      alertMode: mode,
      incompleteReminderIntervalHours: intervalHours,
      enableDebtReminders: enableDebts,
      debtReminderTime: TimeOfDay(hour: dHour, minute: dMinute),
      debtRemindDayBefore: dDayBefore,
      isLoading: false,
    );
  }

  Future<void> setRoutineReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
    state = state.copyWith(routineReminderTime: time);
  }

  Future<void> setBirthdayReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_birthdayHourKey, time.hour);
    await prefs.setInt(_birthdayMinuteKey, time.minute);
    state = state.copyWith(birthdayReminderTime: time);
  }

  Future<void> setAlertMode(ReminderAlertMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertModeKey, mode.name);
    state = state.copyWith(alertMode: mode);
  }

  Future<void> setIncompleteReminderIntervalHours(int hours) async {
    final safeHours = hours < 1 ? 1 : (hours > 12 ? 12 : hours);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_incompleteIntervalHoursKey, safeHours);
    state = state.copyWith(incompleteReminderIntervalHours: safeHours);
  }

  Future<void> setEnableDebtReminders(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableDebtRemindersKey, enabled);
    state = state.copyWith(enableDebtReminders: enabled);
  }

  Future<void> setDebtReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_debtReminderHourKey, time.hour);
    await prefs.setInt(_debtReminderMinuteKey, time.minute);
    state = state.copyWith(debtReminderTime: time);
  }

  Future<void> setDebtRemindDayBefore(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_debtRemindDayBeforeKey, enabled);
    state = state.copyWith(debtRemindDayBefore: enabled);
  }
}