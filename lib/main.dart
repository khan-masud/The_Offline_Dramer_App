import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/services/analytics_service.dart';
import 'core/services/incomplete_reminder_scheduler.dart';
import 'core/services/notification_service.dart';
import 'core/database/database_provider.dart';
import 'providers/notification_preferences_provider.dart';
import 'app.dart';

// Global navigator key to show dialogs from anywhere (like system share intent)
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (mobile platforms)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();

      // Enable Crashlytics (auto-captures Flutter errors)
      FlutterError.onError = (details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Initialize analytics
      AnalyticsService().init();
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }
  }

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Dotenv load error: $e');
  }

  // Init Notifications (singleton - same instance used by provider)
  if (!kIsWeb) {
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.requestPermissions();

    // Lock to portrait
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
    );
  }

  runApp(
    ProviderScope(
      child: _AppWithStartupTasks(),
    ),
  );
}

/// Wrapper widget to run startup tasks that need provider access
class _AppWithStartupTasks extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppWithStartupTasks> createState() => _AppWithStartupTasksState();
}

class _AppWithStartupTasksState extends ConsumerState<_AppWithStartupTasks> {
  StreamSubscription<dynamic>? _todoWatcher;
  StreamSubscription<dynamic>? _routineWatcher;
  StreamSubscription<dynamic>? _routineItemWatcher;
  StreamSubscription<dynamic>? _todayCompletionWatcher;
  StreamSubscription<dynamic>? _habitWatcher;
  StreamSubscription<dynamic>? _todayHabitCompletionWatcher;
  Timer? _incompleteReminderDebounce;

  @override
  void initState() {
    super.initState();
    // Reschedule all routine notifications on app start
    _rescheduleNotificationsOnStartup();
    _setupIncompleteReminderWatchers();
  }

  @override
  void dispose() {
    _incompleteReminderDebounce?.cancel();
    _todoWatcher?.cancel();
    _routineWatcher?.cancel();
    _routineItemWatcher?.cancel();
    _todayCompletionWatcher?.cancel();
    _habitWatcher?.cancel();
    _todayHabitCompletionWatcher?.cancel();
    super.dispose();
  }

  void _setupIncompleteReminderWatchers() {
    final db = ref.read(databaseProvider);

    _todoWatcher = db.watchAllTodos().listen((_) {
      _queueIncompleteReminderRefresh();
    });
    _routineWatcher = db.watchAllRoutines().listen((_) {
      _queueIncompleteReminderRefresh();
    });
    _routineItemWatcher = db.watchAllRoutineItems().listen((_) {
      _queueIncompleteReminderRefresh();
    });
    _todayCompletionWatcher = db.watchTodayCompletions().listen((_) {
      _queueIncompleteReminderRefresh();
    });
    _habitWatcher = db.watchAllHabits().listen((_) {
      _queueIncompleteReminderRefresh();
    });
    _todayHabitCompletionWatcher = db.watchTodayHabitCompletions().listen((_) {
      _queueIncompleteReminderRefresh();
    });
  }

  void _queueIncompleteReminderRefresh() {
    _incompleteReminderDebounce?.cancel();
    _incompleteReminderDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _refreshIncompleteReminderSchedule(),
    );
  }

  Future<void> _refreshIncompleteReminderSchedule() async {
    if (!mounted) return;

    try {
      final db = ref.read(databaseProvider);
      final prefs = ref.read(notificationPreferencesProvider);
      final notif = NotificationService();

      await IncompleteReminderScheduler.refresh(
        db: db,
        notification: notif,
        globalReminderTime: prefs.routineReminderTime,
        intervalHours: prefs.incompleteReminderIntervalHours,
        alertMode: prefs.alertMode,
      );
    } catch (e) {
      debugPrint('Incomplete reminder refresh error: $e');
    }
  }

  Future<void> _rescheduleNotificationsOnStartup() async {
    try {
      // Wait a bit for providers to be ready
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final db = ref.read(databaseProvider);
      final prefs = ref.read(notificationPreferencesProvider);
      final notif = NotificationService();

      final routines = await db.getAllRoutines();
      final birthdays = await db.getAllBirthdays();
      final todos = await db.watchAllTodos().first;
      final habits = await db.watchAllHabits().first;
      final reminderInfos = routines.map((r) {
        final days = r.days.split(',').map((d) => int.tryParse(d)).whereType<int>().toList();
        final reminderTimes = <TimeOfDay>[];
        int? customHour;
        int? customMinute;

        if (r.reminderTime != null && r.reminderTime!.trim().isNotEmpty) {
          final chunks = r.reminderTime!.split(',');
          for (final chunk in chunks) {
            final parts = chunk.trim().split(':');
            if (parts.length != 2) continue;
            final hour = int.tryParse(parts[0]);
            final minute = int.tryParse(parts[1]);
            if (hour == null || minute == null) continue;
            if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
            reminderTimes.add(TimeOfDay(hour: hour, minute: minute));
          }

          if (reminderTimes.isNotEmpty) {
            customHour = reminderTimes.first.hour;
            customMinute = reminderTimes.first.minute;
          }
        }

        return RoutineReminderInfo(
          id: r.id,
          title: r.title,
          description: r.description,
          days: days,
          reminderTimes: reminderTimes,
          customHour: customHour,
          customMinute: customMinute,
        );
      }).toList();

      await notif.rescheduleAllRoutineReminders(
        routines: reminderInfos,
        globalReminderTime: prefs.routineReminderTime,
        alertMode: prefs.alertMode,
      );

      await notif.cancelGlobalDailyReminder();
      await notif.cancelDailyTaskDigestReminders();

      await notif.rescheduleAllBirthdayReminders(
        birthdays: birthdays,
        alertMode: prefs.alertMode,
        hour: prefs.birthdayReminderTime.hour,
        minute: prefs.birthdayReminderTime.minute,
      );

      await notif.rescheduleAllTodoReminders(
        todos: todos,
        alertMode: prefs.alertMode,
      );

      await notif.rescheduleAllHabitReminders(
        habits: habits,
        alertMode: prefs.alertMode,
      );

      await IncompleteReminderScheduler.refresh(
        db: db,
        notification: notif,
        globalReminderTime: prefs.routineReminderTime,
        intervalHours: prefs.incompleteReminderIntervalHours,
        alertMode: prefs.alertMode,
      );
    } catch (e) {
      debugPrint('Startup notification reschedule error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const TODApp();
  }
}
