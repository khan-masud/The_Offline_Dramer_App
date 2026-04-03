import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notification_preferences_provider.dart';
import '../database/app_database.dart';

// Singleton provider - uses the SAME instance initialized in main.dart
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const _welcomeShownKey = 'notif_welcomed';
  static const _globalDailyReminderId = 700000;
  static const _birthdayBaseId = 800000;

  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {},
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;

    try {
      bool permissionGranted = false;

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final androidGranted =
          await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();

        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      permissionGranted =
          (androidGranted ?? false) || (iosGranted ?? false);

      // Show welcome notification ONLY ONCE when permission is first granted
      if (permissionGranted) {
        final prefs = await SharedPreferences.getInstance();
        final alreadyShown = prefs.getBool(_welcomeShownKey) ?? false;
        if (!alreadyShown) {
          await _notificationsPlugin.show(
            id: _globalDailyReminderId + 1,
            title: 'Welcome to TOD',
            body: 'Notifications are ready. You will only see this once.',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'welcome_channel',
                'Welcome',
                channelDescription: 'Welcome notification',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
          await prefs.setBool(_welcomeShownKey, true);
        }
      }
    } catch (e) {
      debugPrint('Notification request permissions error: $e');
    }
  }

  Future<void> scheduleTodoReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: _buildDetails(
          channelBaseId: 'todo_reminders',
          channelBaseName: 'Todo Reminders',
          channelDescription: 'Reminders for your upcoming tasks',
          alertMode: alertMode,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notification schedule error');
    }
  }

  Future<void> scheduleRoutineReminder({
    required int routineId,
    required String title,
    required String body,
    required List<int> daysOfWeek, // 1 to 7
    required int hour,
    required int minute,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    final reminderTimes = <TimeOfDay>[TimeOfDay(hour: hour, minute: minute)];
    await scheduleRoutineReminders(
      routineId: routineId,
      title: title,
      body: body,
      daysOfWeek: daysOfWeek,
      reminderTimes: reminderTimes,
      alertMode: alertMode,
    );
  }

  Future<void> scheduleRoutineReminders({
    required int routineId,
    required String title,
    required String body,
    required List<int> daysOfWeek,
    required List<TimeOfDay> reminderTimes,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    final validDays = daysOfWeek.where((d) => d >= 1 && d <= 7).toList();
    if (validDays.isEmpty || reminderTimes.isEmpty) return;

    for (int reminderIndex = 0;
        reminderIndex < reminderTimes.length;
        reminderIndex++) {
      final reminder = reminderTimes[reminderIndex];

      for (final day in validDays) {
        final uniqueId = _routineNotificationId(
          routineId: routineId,
          reminderIndex: reminderIndex,
          dayOfWeek: day,
        );
        final scheduledDate =
            _nextInstanceOfDayAt(day, reminder.hour, reminder.minute);

        try {
          await _notificationsPlugin.zonedSchedule(
            id: uniqueId,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            notificationDetails: _buildDetails(
              channelBaseId: 'routine_reminders',
              channelBaseName: 'Routine Reminders',
              channelDescription: 'Reminders for your routines',
              alertMode: alertMode,
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e) {
          debugPrint('Routine notification schedule error: $e');
        }
      }
    }
  }

  Future<void> scheduleGlobalDailyReminder({
    required TimeOfDay time,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    await cancelGlobalDailyReminder();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id: _globalDailyReminderId,
        title: 'TOD Reminder',
        body: 'Check your routines and plan your day.',
        scheduledDate: scheduled,
        notificationDetails: _buildDetails(
          channelBaseId: 'daily_routine_reminder',
          channelBaseName: 'Daily Routine Reminder',
          channelDescription: 'Global daily reminder for TOD',
          alertMode: alertMode,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Global reminder schedule error: $e');
    }
  }

  Future<void> cancelGlobalDailyReminder() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id: _globalDailyReminderId);
    } catch (_) {
      // ignore
    }
  }

  Future<void> scheduleHabitReminder({
    required int habitId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    for (int day = 1; day <= 7; day++) {
      final uniqueId = int.parse('20$habitId$day');
      tz.TZDateTime scheduledDate = _nextInstanceOfDayAt(day, hour, minute);

      try {
        await _notificationsPlugin.zonedSchedule(
          id: uniqueId,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: _buildDetails(
            channelBaseId: 'habit_reminders',
            channelBaseName: 'Habit Reminders',
            channelDescription: 'Reminders for your daily habits',
            alertMode: alertMode,
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint('Habit notification schedule error: $e');
      }
    }
  }

  Future<void> scheduleBirthdayReminders({
    required int birthdayId,
    required String personName,
    required DateTime dateOfBirth,
    required bool remindDayBefore,
    required bool remindOnDay,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    await cancelBirthdayReminders(birthdayId);

    final now = tz.TZDateTime.now(tz.local);

    if (remindDayBefore) {
      final dayBefore = DateTime(now.year, dateOfBirth.month, dateOfBirth.day).subtract(const Duration(days: 1));
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        dayBefore.year,
        dayBefore.month,
        dayBefore.day,
        0,
        0,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = tz.TZDateTime(
          tz.local,
          dayBefore.year + 1,
          dayBefore.month,
          dayBefore.day,
          0,
          0,
        );
      }

      await _notificationsPlugin.zonedSchedule(
        id: _birthdayNotificationId(birthdayId, 1),
        title: 'Birthday Tomorrow',
        body: '$personName has a birthday tomorrow.',
        scheduledDate: scheduled,
        notificationDetails: _buildDetails(
          channelBaseId: 'birthday_reminders',
          channelBaseName: 'Birthday Reminders',
          channelDescription: 'Reminders for saved birthdays',
          alertMode: alertMode,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }

    if (remindOnDay) {
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        dateOfBirth.month,
        dateOfBirth.day,
        0,
        0,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = tz.TZDateTime(
          tz.local,
          now.year + 1,
          dateOfBirth.month,
          dateOfBirth.day,
          0,
          0,
        );
      }

      await _notificationsPlugin.zonedSchedule(
        id: _birthdayNotificationId(birthdayId, 2),
        title: 'Birthday Today',
        body: 'Today is $personName\'s birthday.',
        scheduledDate: scheduled,
        notificationDetails: _buildDetails(
          channelBaseId: 'birthday_reminders',
          channelBaseName: 'Birthday Reminders',
          channelDescription: 'Reminders for saved birthdays',
          alertMode: alertMode,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  Future<void> cancelBirthdayReminders(int birthdayId) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id: _birthdayNotificationId(birthdayId, 1));
    await _notificationsPlugin.cancel(id: _birthdayNotificationId(birthdayId, 2));
  }

  Future<void> rescheduleAllBirthdayReminders({
    required List<Birthday> birthdays,
    required ReminderAlertMode alertMode,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    for (final birthday in birthdays) {
      await scheduleBirthdayReminders(
        birthdayId: birthday.id,
        personName: birthday.personName,
        dateOfBirth: birthday.dateOfBirth,
        remindDayBefore: birthday.remindDayBefore,
        remindOnDay: birthday.remindOnDay,
        alertMode: alertMode,
      );
    }
  }

  tz.TZDateTime _nextInstanceOfDayAt(int dayOfWeek, int hour, int minute) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute, 0);

    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  NotificationDetails _buildDetails({
    required String channelBaseId,
    required String channelBaseName,
    required String channelDescription,
    required ReminderAlertMode alertMode,
  }) {
    final playSound =
        alertMode == ReminderAlertMode.ring || alertMode == ReminderAlertMode.ringAndVibration;
    final enableVibration =
        alertMode == ReminderAlertMode.vibration || alertMode == ReminderAlertMode.ringAndVibration;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        '${channelBaseId}_${alertMode.name}',
        '$channelBaseName (${_modeLabel(alertMode)})',
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );
  }

  String _modeLabel(ReminderAlertMode mode) {
    switch (mode) {
      case ReminderAlertMode.ring:
        return 'Ring';
      case ReminderAlertMode.ringAndVibration:
        return 'Ring+Vibration';
      case ReminderAlertMode.vibration:
        return 'Vibration';
      case ReminderAlertMode.silent:
        return 'Silent';
    }
  }

  Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Notification cancel error');
    }
  }

  Future<void> cancelRoutineReminders(int routineId) async {
    if (kIsWeb) return;
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      final lower = routineId * 10000;
      final upper = lower + 9999;
      for (final req in pending) {
        if (req.id >= lower && req.id <= upper) {
          await _notificationsPlugin.cancel(id: req.id);
        }
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Notification cancelAll error');
    }
  }

  /// Reschedule ALL routine reminders (call on app startup)
  Future<void> rescheduleAllRoutineReminders({
    required List<RoutineReminderInfo> routines,
    required TimeOfDay globalReminderTime,
    required ReminderAlertMode alertMode,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    await scheduleGlobalDailyReminder(
      time: globalReminderTime,
      alertMode: alertMode,
    );

    for (final routine in routines) {
      await cancelRoutineReminders(routine.id);
      if (routine.days.isEmpty) continue;

      final times =
          routine.reminderTimes != null && routine.reminderTimes!.isNotEmpty
              ? routine.reminderTimes!
              : [
                  TimeOfDay(
                    hour: routine.customHour ?? globalReminderTime.hour,
                    minute: routine.customMinute ?? globalReminderTime.minute,
                  ),
                ];

      await scheduleRoutineReminders(
        routineId: routine.id,
        title: 'Routine: ${routine.title}',
        body: routine.description ?? 'Time to start your routine!',
        daysOfWeek: routine.days,
        reminderTimes: times,
        alertMode: alertMode,
      );
    }
  }

  int _routineNotificationId({
    required int routineId,
    required int reminderIndex,
    required int dayOfWeek,
  }) {
    return (routineId * 10000) + (reminderIndex * 10) + dayOfWeek;
  }

  int _birthdayNotificationId(int birthdayId, int type) {
    return _birthdayBaseId + (birthdayId * 10) + type;
  }
}

/// Lightweight info object for rescheduling
class RoutineReminderInfo {
  final int id;
  final String title;
  final String? description;
  final List<int> days;
  final List<TimeOfDay>? reminderTimes;
  final int? customHour;
  final int? customMinute;

  RoutineReminderInfo({
    required this.id,
    required this.title,
    this.description,
    required this.days,
    this.reminderTimes,
    this.customHour,
    this.customMinute,
  });
}
