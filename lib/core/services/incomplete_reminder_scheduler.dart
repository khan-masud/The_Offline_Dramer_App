import 'package:flutter/material.dart';

import '../../providers/notification_preferences_provider.dart';
import '../database/app_database.dart';
import 'notification_service.dart';

class IncompleteReminderScheduler {
  static Future<void> refresh({
    required AppDatabase db,
    required NotificationService notification,
    required TimeOfDay globalReminderTime,
    required int intervalHours,
    required ReminderAlertMode alertMode,
  }) async {
    final allPendingTodos = await db.watchAllTodos(completed: false).first;
    final now = DateTime.now();

    // Priority filter rule:
    // - Priority > 0 (Low, Med, High): Always included in reminder notifications.
    // - Priority == 0 (None):
    //     - If no due date: Do NOT show in reminder notifications at all.
    //     - If due date exists: Show ONLY starting from 24 hours before the due date (day before / within 24h).
    final eligibleTodos = allPendingTodos.where((todo) {
      if (todo.priority > 0) return true;
      if (todo.dueDate == null) return false;
      final threshold = todo.dueDate!.subtract(const Duration(hours: 24));
      return now.isAfter(threshold) || now.isAtSameMomentAs(threshold);
    }).toList();

    final pendingTodoCount = eligibleTodos.length;
    final pendingFollowUpItems = eligibleTodos
      .map((todo) => todo.title.trim())
      .where((title) => title.isNotEmpty)
      .toList();

    final todayDow = DateTime.now().weekday.toString();
    final routines = await db.getAllRoutines();
    final todayRoutines = routines
        .where((routine) => routine.days.split(',').map((d) => d.trim()).contains(todayDow))
        .toList();

    final completions = await db.watchTodayCompletions().first;
    final completedRoutineItemIds = completions.map((c) => c.routineItemId).toSet();

    int pendingRoutineItemCount = 0;
    final includeRoutineName = todayRoutines.length > 1;

    for (final routine in todayRoutines) {
      final items = await db.watchRoutineItems(routine.id).first;

      for (final item in items) {
        if (completedRoutineItemIds.contains(item.id)) continue;

        pendingRoutineItemCount++;
        final taskTitle = item.title.trim();
        if (taskTitle.isEmpty) continue;

        final followUpTitle = includeRoutineName
            ? '$taskTitle (${routine.title})'
            : taskTitle;
        pendingFollowUpItems.add(followUpTitle);
      }
    }

    final habits = await db.watchAllHabits().first;
    final todayHabitCompletions = await db.watchTodayHabitCompletions().first;
    final completedHabitIds = todayHabitCompletions.map((c) => c.habitId).toSet();
    final pendingHabitCount =
        habits.where((habit) => !completedHabitIds.contains(habit.id)).length;

    for (final habit in habits) {
      if (completedHabitIds.contains(habit.id)) continue;
      final name = habit.title.trim();
      if (name.isEmpty) continue;
      pendingFollowUpItems.add('Habit: $name');
    }

    await notification.scheduleIncompleteWorkFollowUpReminders(
      pendingTodoCount: pendingTodoCount,
      pendingRoutineItemCount: pendingRoutineItemCount,
      pendingHabitCount: pendingHabitCount,
      pendingTaskNames: pendingFollowUpItems,
      startTime: globalReminderTime,
      intervalHours: intervalHours,
      alertMode: alertMode,
    );
  }
}
