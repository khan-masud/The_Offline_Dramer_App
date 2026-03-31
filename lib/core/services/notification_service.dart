import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notification_preferences_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {},
      );

      _isInitialized = true;
      
      // Send welcome notification after a short delay to ensure it's visible
      await Future.delayed(const Duration(milliseconds: 500));
      await showWelcomeNotification();
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> showWelcomeNotification() async {
    if (kIsWeb || !_isInitialized) return;

    try {
      await _notificationsPlugin.show(
        id: 0,
        title: '🎉 Welcome to TOD!',
        body: 'Notifications enabled! You\'ll receive reminders for your tasks.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'welcome_channel',
            'Welcome',
            channelDescription: 'Welcome notification',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF6200EE),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Welcome notification error: $e');
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

    for (int day in daysOfWeek) {
      final uniqueId = int.parse('10$routineId$day');
      tz.TZDateTime scheduledDate = _nextInstanceOfDayAt(day, hour, minute);

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

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final permissionGranted = await androidImplementation?.requestNotificationsPermission() ?? false;
      await androidImplementation?.requestExactAlarmsPermission();
      
      // Show confirmation notification if permission granted
      if (permissionGranted) {
        await Future.delayed(const Duration(seconds: 1));
        await _notificationsPlugin.show(
          id: 1,
          title: '✅ Notifications Enabled',
          body: 'You\'ll now receive reminders and updates for your tasks!',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'permissions_channel',
              'Permissions',
              channelDescription: 'Permission confirmation notifications',
              importance: Importance.high,
              priority: Priority.high,
              color: Color(0xFF4CAF50),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Notification request permissions error: $e');
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
    for (int day = 1; day <= 7; day++) {
      try {
        await _notificationsPlugin.cancel(id: int.parse('10$routineId$day'));
      } catch (e) {
        // ignore
      }
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
}
