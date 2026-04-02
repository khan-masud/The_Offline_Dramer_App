import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

enum RoutinePriorityFilter { all, high, medium, low }

final routinePriorityFilterProvider =
  StateProvider<RoutinePriorityFilter>((ref) => RoutinePriorityFilter.all);

// All routines
final routinesProvider = StreamProvider<List<Routine>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllRoutines();
});

// Items for a specific routine
final routineItemsProvider = StreamProvider.family<List<RoutineItem>, int>((ref, routineId) {
  final db = ref.watch(databaseProvider);
  return db.watchRoutineItems(routineId);
});

final routineSubTasksProvider = StreamProvider.family<List<RoutineSubTask>, int>((ref, routineItemId) {
  final db = ref.watch(databaseProvider);
  return db.watchRoutineSubTasks(routineItemId);
});

// Today's completions
final todayCompletionsProvider = StreamProvider<List<RoutineCompletion>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTodayCompletions();
});

// Today's routines (filtered by day of week)
final todayRoutinesProvider = Provider<AsyncValue<List<Routine>>>((ref) {
  final routinesAsync = ref.watch(routinesProvider);
  final todayDow = DateTime.now().weekday.toString(); // 1=Monday..7=Sunday

  return routinesAsync.whenData((routines) =>
    routines.where((r) => r.days.split(',').contains(todayDow)).toList()
  );
});

// Calculate streak
final routineStreakProvider = FutureProvider.family<int, Routine>((ref, routine) async {
  final db = ref.read(databaseProvider);
  final completions = await db.getRoutineCompletions(routine.id);
  
  if (completions.isEmpty) return 0;
  
  final completedDates = completions.map((c) => DateTime(c.completedDate.year, c.completedDate.month, c.completedDate.day)).toSet();
  final scheduledDays = routine.days.split(',').map((e) => int.tryParse(e) ?? 0).where((e) => e != 0).toSet();
  
  int streak = 0;
  DateTime cursor = DateTime.now();
  cursor = DateTime(cursor.year, cursor.month, cursor.day);
  
  for (int i = 0; i < 365; i++) {
    final curDate = cursor.subtract(Duration(days: i));
    
    if (scheduledDays.contains(curDate.weekday)) {
      if (completedDates.contains(curDate)) {
        streak++;
      } else {
        if (i == 0) continue; // Give them until end of today
        break; // Streak broken
      }
    } else {
      if (completedDates.contains(curDate)) {
        streak++;
      }
    }
  }
  return streak;
});
