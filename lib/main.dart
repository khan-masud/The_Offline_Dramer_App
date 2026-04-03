import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/notification_service.dart';
import 'core/database/database_provider.dart';
import 'providers/notification_preferences_provider.dart';
import 'app.dart';

// Global navigator key to show dialogs from anywhere (like system share intent)
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Init Notifications (singleton - same instance used by provider)
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
  @override
  void initState() {
    super.initState();
    // Reschedule all routine notifications on app start
    _rescheduleNotificationsOnStartup();
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

      await notif.rescheduleAllBirthdayReminders(
        birthdays: birthdays,
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
