import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Last 5 used tag suggestions (sorted by updatedAt descending)
final usedTagsProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllTodos().map((allTodos) {
    final sorted = List<Todo>.from(allTodos)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final Set<String> recentTags = {};
    for (final todo in sorted) {
      try {
        final decoded = jsonDecode(todo.tags);
        if (decoded is List) {
          for (final tag in decoded) {
            final s = tag.toString().trim();
            if (s.isNotEmpty) {
              recentTags.add(s);
              if (recentTags.length >= 5) {
                return recentTags.toList();
              }
            }
          }
        }
      } catch (_) {}
    }
    return recentTags.toList();
  });
});

// Smart Filter state (TickTick / Todoist standard)
enum TodoFilter { today, upcoming, overdue, all, completed }

final todoFilterProvider = StateProvider<TodoFilter>((ref) => TodoFilter.today);

// Search state
final todoSearchProvider = StateProvider<String>((ref) => '');

// All todos stream
final allTodosStreamProvider = StreamProvider<List<Todo>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllTodos();
});

// Helper date comparison
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// Filtered todo list based on smart view
final todosProvider = Provider<AsyncValue<List<Todo>>>((ref) {
  final allTodosAsync = ref.watch(allTodosStreamProvider);
  final filter = ref.watch(todoFilterProvider);

  return allTodosAsync.whenData((todos) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final next7Days = endOfToday.add(const Duration(days: 7));

    switch (filter) {
      case TodoFilter.today:
        return todos.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return false;
          return _isSameDay(t.dueDate!, now);
        }).toList();

      case TodoFilter.upcoming:
        return todos.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return false;
          return t.dueDate!.isAfter(endOfToday) && t.dueDate!.isBefore(next7Days.add(const Duration(seconds: 1)));
        }).toList();

      case TodoFilter.overdue:
        return todos.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return false;
          return t.dueDate!.isBefore(startOfToday);
        }).toList();

      case TodoFilter.all:
        return todos.where((t) => !t.isCompleted).toList();

      case TodoFilter.completed:
        return todos.where((t) => t.isCompleted).toList();
    }
  });
});

// Smart Filter Counts
final todoCountsProvider = Provider<AsyncValue<({int today, int upcoming, int overdue, int all, int completed})>>((ref) {
  final allTodosAsync = ref.watch(allTodosStreamProvider);

  return allTodosAsync.whenData((todos) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final next7Days = endOfToday.add(const Duration(days: 7));

    int todayCount = 0;
    int upcomingCount = 0;
    int overdueCount = 0;
    int allIncompleteCount = 0;
    int completedCount = 0;

    for (final t in todos) {
      if (t.isCompleted) {
        completedCount++;
      } else {
        allIncompleteCount++;
        if (t.dueDate != null) {
          if (_isSameDay(t.dueDate!, now)) {
            todayCount++;
          } else if (t.dueDate!.isBefore(startOfToday)) {
            overdueCount++;
          } else if (t.dueDate!.isAfter(endOfToday) && t.dueDate!.isBefore(next7Days.add(const Duration(seconds: 1)))) {
            upcomingCount++;
          }
        }
      }
    }

    return (
      today: todayCount,
      upcoming: upcomingCount,
      overdue: overdueCount,
      all: allIncompleteCount,
      completed: completedCount,
    );
  });
});

// Filtered todo list with search query applied
final filteredTodosProvider = Provider<AsyncValue<List<Todo>>>((ref) {
  final todosAsync = ref.watch(todosProvider);
  final searchQuery = ref.watch(todoSearchProvider).toLowerCase().trim();

  if (searchQuery.isEmpty) return todosAsync;

  return todosAsync.whenData(
    (todos) => todos.where((t) {
      final title = t.title.toLowerCase();
      final desc = (t.description ?? '').toLowerCase();
      String tagsStr = '';
      try {
        if (t.tags.isNotEmpty) {
          tagsStr = (List<String>.from(jsonDecode(t.tags))).join(' ').toLowerCase();
        }
      } catch (_) {}
      return title.contains(searchQuery) ||
          desc.contains(searchQuery) ||
          tagsStr.contains(searchQuery);
    }).toList(),
  );
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
