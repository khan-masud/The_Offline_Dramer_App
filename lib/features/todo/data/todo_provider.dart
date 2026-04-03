import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Filter state
enum TodoFilter { all, pending, completed }

final todoFilterProvider = StateProvider<TodoFilter>((ref) => TodoFilter.pending);

// Reactive todo list
final todosProvider = StreamProvider<List<Todo>>((ref) {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(todoFilterProvider);

  switch (filter) {
    case TodoFilter.all:
      return db.watchAllTodos();
    case TodoFilter.pending:
      return db.watchAllTodos(completed: false);
    case TodoFilter.completed:
      return db.watchAllTodos(completed: true);
  }
});

// Todo stats
final todoStatsProvider = StreamProvider<({int total, int completed, int pending})>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllTodos().map((todos) => (
    total: todos.length,
    completed: todos.where((t) => t.isCompleted).length,
    pending: todos.where((t) => !t.isCompleted).length,
  ));
});

// --- SUBTASKS ---
final subTasksProvider = StreamProvider.family<List<SubTask>, int>((ref, todoId) {
  final db = ref.watch(databaseProvider);
  return db.watchSubTasks(todoId);
});

// --- FOCUS SESSIONS ---
final focusSessionsProvider = StreamProvider.family<List<FocusSession>, int>((ref, todoId) {
  final db = ref.watch(databaseProvider);
  return db.watchFocusSessions(todoId);
});

final totalFocusTimeProvider = Provider.family<int, int>((ref, todoId) {
  final sessionsAsync = ref.watch(focusSessionsProvider(todoId));
  return sessionsAsync.maybeWhen(
    data: (sessions) => sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds),
    orElse: () => 0,
  );
});
