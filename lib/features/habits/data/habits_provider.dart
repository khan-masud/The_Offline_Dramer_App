import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// All habits
final habitsProvider = StreamProvider<List<Habit>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllHabits();
});

// Today's habit completions
final todayHabitCompletionsProvider = StreamProvider<List<HabitCompletion>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTodayHabitCompletions();
});

// Habit streaks (computed)
final habitStreakProvider = FutureProvider.family<int, int>((ref, habitId) {
  final db = ref.watch(databaseProvider);
  return db.getHabitStreak(habitId);
});

// Available habit colors
const Map<String, String> habitColorNames = {
  'primary': '🔵',
  'success': '🟢',
  'error': '🔴',
  'warning': '🟡',
  'purple': '🟣',
  'teal': '🩵',
  'orange': '🟠',
  'pink': '🩷',
};

// Available emojis for habits
const List<String> habitEmojis = [
  '🎯', '💪', '📚', '🏃', '🧘', '💧', '🥗', '😴',
  '✍️', '🎵', '🧩', '🌱', '💊', '🚶', '📝', '🎨',
];
