import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

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
