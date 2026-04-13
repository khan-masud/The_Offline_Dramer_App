import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  static const _profileNameKey = 'profile_name';
  static const _globalDailyReminderId = 700000;
  static const _dailyRoutineDigestId = 705000;
  static const _dailyTodoDigestId = 705001;
  static const _welcomeNotificationId = 705099;
  static const _incompleteFollowUpBaseId = 710000;
  static const _maxIncompleteFollowUpsPerDay = 24;
  static const _birthdayBaseId = 800000;
  static const _channelVersion = 2;

  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    try {
      tz.initializeTimeZones();
      await _configureLocalTimeZone();

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

  Future<void> _configureLocalTimeZone() async {
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Keep default timezone if device timezone cannot be resolved.
      debugPrint('Timezone setup warning: $e');
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
            id: _welcomeNotificationId,
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
    // Keep only pending-list follow-up notifications.
    await cancelReminder(id);
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
    // Keep only pending-list follow-up notifications.
    await cancelRoutineReminders(routineId);
  }

  Future<void> scheduleGlobalDailyReminder({
    required TimeOfDay time,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;
    // Keep only pending-list follow-up notifications.
    await cancelGlobalDailyReminder();
  }

  Future<void> cancelGlobalDailyReminder() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id: _globalDailyReminderId);
    } catch (_) {
      // ignore
    }
  }

  Future<void> scheduleDailyTaskDigestReminders({
    required TimeOfDay time,
    required String userName,
    required List<String> routineTaskTitles,
    required List<String> todoTaskTitles,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;
    // Keep only pending-list follow-up notifications.
    await cancelDailyTaskDigestReminders();
  }

  Future<void> cancelDailyTaskDigestReminders() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id: _dailyRoutineDigestId);
      await _notificationsPlugin.cancel(id: _dailyTodoDigestId);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _scheduleDailyDigestNotification({
    required int notificationId,
    required TimeOfDay time,
    required String title,
    required String body,
    required String channelBaseId,
    required String channelBaseName,
    required String channelDescription,
    required ReminderAlertMode alertMode,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _buildDetails(
          channelBaseId: channelBaseId,
          channelBaseName: channelBaseName,
          channelDescription: channelDescription,
          alertMode: alertMode,
          expandedText: body,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Daily digest schedule error: $e');
    }
  }

  String _sanitizeNotificationName(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return 'Dreamer';
    return normalized;
  }

  String _buildDigestBody({
    required String heading,
    required List<String> tasks,
  }) {
    final normalizedTasks = tasks
        .map((task) => task.trim())
        .where((task) => task.isNotEmpty)
        .toList();

    if (normalizedTasks.isEmpty) {
      return '$heading\nNo pending tasks for now.';
    }

    const maxVisibleItems = 18;
    final visible = normalizedTasks.take(maxVisibleItems).toList();
    final hiddenCount = normalizedTasks.length - visible.length;

    final buffer = StringBuffer('$heading\n');
    for (int i = 0; i < visible.length; i++) {
      buffer.writeln('${i + 1}. ${visible[i]}');
    }

    if (hiddenCount > 0) {
      buffer.write('+ $hiddenCount more item(s)...');
    }

    return buffer.toString().trimRight();
  }

  Future<void> scheduleIncompleteWorkFollowUpReminders({
    required int pendingTodoCount,
    required int pendingRoutineItemCount,
    required int pendingHabitCount,
    required List<String> pendingTaskNames,
    required TimeOfDay startTime,
    required int intervalHours,
    ReminderAlertMode alertMode = ReminderAlertMode.ringAndVibration,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    final safeIntervalHours = intervalHours < 1
        ? 1
        : (intervalHours > 12 ? 12 : intervalHours);
    final profileName = await _loadProfileName();
    final normalizedPendingTaskNames = pendingTaskNames
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();

    await cancelIncompleteWorkFollowUpReminders();

    final totalPending =
      pendingTodoCount + pendingRoutineItemCount + pendingHabitCount;
    if (totalPending <= 0) return;

    final now = tz.TZDateTime.now(tz.local);
    var nextSlot = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );

    if (!nextSlot.isAfter(now)) {
      final elapsedMinutes = now.difference(nextSlot).inMinutes;
      final stepMinutes = safeIntervalHours * 60;
      final nextStep = (elapsedMinutes ~/ stepMinutes) + 1;
      nextSlot = nextSlot.add(Duration(minutes: nextStep * stepMinutes));
    }

    int slotIndex = 0;
    while (nextSlot.year == now.year &&
        nextSlot.month == now.month &&
        nextSlot.day == now.day &&
        slotIndex < _maxIncompleteFollowUpsPerDay) {
      final reminderTitle = _buildGreetingTitle(profileName, nextSlot.hour);
      final followUpBody = _buildPendingWorkNoticeBody(
        pendingTaskNames: normalizedPendingTaskNames,
        pendingTodoCount: pendingTodoCount,
        pendingRoutineItemCount: pendingRoutineItemCount,
        pendingHabitCount: pendingHabitCount,
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          id: _incompleteFollowUpNotificationId(slotIndex),
          title: reminderTitle,
          body: followUpBody,
          scheduledDate: nextSlot,
          notificationDetails: _buildDetails(
            channelBaseId: 'incomplete_followup_reminders',
            channelBaseName: 'Incomplete Follow-up Reminders',
            channelDescription:
              'Repeated reminders for incomplete tasks, routines, and habits',
            alertMode: alertMode,
            expandedText: followUpBody,
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Incomplete follow-up schedule error: $e');
      }

      slotIndex++;
      nextSlot = nextSlot.add(Duration(hours: safeIntervalHours));
    }
  }

  Future<void> cancelIncompleteWorkFollowUpReminders() async {
    if (kIsWeb) return;
    try {
      for (int i = 0; i < _maxIncompleteFollowUpsPerDay; i++) {
        await _notificationsPlugin.cancel(id: _incompleteFollowUpNotificationId(i));
      }
    } catch (_) {
      // ignore
    }
  }

  String _fallbackPendingTaskName({
    required int pendingTodoCount,
    required int pendingRoutineItemCount,
    required int pendingHabitCount,
  }) {
    final totalPending =
        pendingTodoCount + pendingRoutineItemCount + pendingHabitCount;
    if (totalPending <= 0) return 'pending work';
    if (totalPending == 1 && pendingTodoCount == 1) return 'task';
    if (totalPending == 1 && pendingRoutineItemCount == 1) return 'routine task';
    if (totalPending == 1 && pendingHabitCount == 1) return 'habit';
    return 'multiple pending tasks';
  }

  String _buildPendingWorkNoticeBody({
    required List<String> pendingTaskNames,
    required int pendingTodoCount,
    required int pendingRoutineItemCount,
    required int pendingHabitCount,
  }) {
    final normalizedNames = pendingTaskNames.isNotEmpty
        ? pendingTaskNames
        : <String>[
            _fallbackPendingTaskName(
              pendingTodoCount: pendingTodoCount,
              pendingRoutineItemCount: pendingRoutineItemCount,
              pendingHabitCount: pendingHabitCount,
            ),
          ];
    const maxVisibleItems = 12;
    final visible = normalizedNames.take(maxVisibleItems).toList();
    final hiddenCount = normalizedNames.length - visible.length;

    final buffer = StringBuffer('You have pending tasks:\n');
    for (int i = 0; i < visible.length; i++) {
      buffer.writeln('${i + 1}. ${visible[i]}');
    }
    if (hiddenCount > 0) {
      buffer.writeln('+ $hiddenCount more task(s)...');
    }
    buffer.write('\nPlease complete them in time');

    return buffer.toString().trimRight();
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
    // Keep only pending-list follow-up notifications.
    await cancelHabitReminders(habitId);
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
          expandedText: '$personName has a birthday tomorrow.',
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
          expandedText: 'Today is $personName\'s birthday.',
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
    String? expandedText,
  }) {
    final playSound =
        alertMode == ReminderAlertMode.ring || alertMode == ReminderAlertMode.ringAndVibration;
    final enableVibration =
        alertMode == ReminderAlertMode.vibration || alertMode == ReminderAlertMode.ringAndVibration;
    final vibrationPattern = enableVibration
        ? Int64List.fromList(const <int>[0, 300, 200, 450])
        : null;
    final channelId =
        '${channelBaseId}_${alertMode.name}_v$_channelVersion';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        '$channelBaseName (${_modeLabel(alertMode)})',
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: enableVibration,
        vibrationPattern: vibrationPattern,
        styleInformation: expandedText == null
            ? null
            : BigTextStyleInformation(expandedText),
      ),
    );
  }

  Future<String> _loadProfileName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileNameKey) ?? '';
      final normalized = raw.trim();
      if (normalized.isNotEmpty) return normalized;
    } catch (_) {
      // ignore
    }
    return 'Dreamer';
  }

  String _buildGreetingTitle(String userName, int hour) {
    final safeName = _sanitizeNotificationName(userName);
    return 'Hey $safeName, ${_timeGreetingByHour(hour)}';
  }

  String _timeGreetingByHour(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 14) return 'Good Noon';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Night';
  }

  String _buildPendingTaskNoticeBody(String taskName) {
    final normalizedTask = taskName.trim().isEmpty ? 'Task' : taskName.trim();
    return 'You have a pending task: $normalizedTask\n\nPlease complete it in time';
  }

  String _deriveTaskName({
    required String title,
    required String body,
  }) {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    for (final prefix in const <String>['Routine: ', 'Habit Reminder: ', 'Todo Reminder: ']) {
      if (trimmedTitle.startsWith(prefix)) {
        final extracted = trimmedTitle.substring(prefix.length).trim();
        if (extracted.isNotEmpty) return extracted;
      }
    }

    if (trimmedBody.isNotEmpty &&
        !trimmedBody.toLowerCase().contains('time to') &&
        !trimmedBody.toLowerCase().contains('track')) {
      return trimmedBody;
    }

    if (trimmedTitle.isNotEmpty) return trimmedTitle;
    return 'Task';
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

  Future<void> cancelHabitReminders(int habitId) async {
    if (kIsWeb) return;
    try {
      for (int day = 1; day <= 7; day++) {
        await _notificationsPlugin.cancel(id: _habitNotificationId(habitId, day));

        // Cleanup legacy IDs used in previous app versions.
        final legacyId = int.tryParse('20$habitId$day');
        if (legacyId != null) {
          await _notificationsPlugin.cancel(id: legacyId);
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

  Future<void> rescheduleAllTodoReminders({
    required List<Todo> todos,
    required ReminderAlertMode alertMode,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    final now = DateTime.now();
    for (final todo in todos) {
      await cancelReminder(todo.id);

      if (todo.isCompleted) continue;
      if (todo.remindAt == null) continue;
      if (!todo.remindAt!.isAfter(now)) continue;

      await scheduleTodoReminder(
        id: todo.id,
        title: 'Todo Reminder',
        body: todo.title,
        scheduledDate: todo.remindAt!,
        alertMode: alertMode,
      );
    }
  }

  Future<void> rescheduleAllHabitReminders({
    required List<Habit> habits,
    required ReminderAlertMode alertMode,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    for (final habit in habits) {
      await cancelHabitReminders(habit.id);
      final reminder = _parseTimeOfDay(habit.reminderTime);
      if (reminder == null) continue;

      await scheduleHabitReminder(
        habitId: habit.id,
        title: 'Habit Reminder: ${habit.title}',
        body: 'Time to keep your ${habit.emoji} habit on track!',
        hour: reminder.hour,
        minute: reminder.minute,
        alertMode: alertMode,
      );
    }
  }

  TimeOfDay? _parseTimeOfDay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
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

  int _incompleteFollowUpNotificationId(int slotIndex) {
    return _incompleteFollowUpBaseId + slotIndex;
  }

  int _habitNotificationId(int habitId, int day) {
    return 2000000 + (habitId * 10) + day;
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
