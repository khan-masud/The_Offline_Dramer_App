import 'package:drift/drift.dart';
import 'connection/connection.dart' as conn;

part 'app_database.g.dart';

// ==================== TODOS ====================
class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 0=none,1=low,2=medium,3=high
  TextColumn get category => text().nullable()();
  
  // New features for advanced task management
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // Store as JSON list
  DateTimeColumn get remindAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class SubTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get todoId => integer().references(Todos, #id)();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

class FocusSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get todoId => integer().nullable().references(Todos, #id)();
  IntColumn get routineItemId => integer().nullable().references(RoutineItems, #id)();
  TextColumn get sessionType => text().withDefault(const Constant('pomodoro'))(); // 'pomodoro' or 'stopwatch'
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get startTime => dateTime()();  DateTimeColumn get endTime => dateTime()();
}
// ==================== NOTES ====================
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get folder => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ==================== ROUTINES ====================
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get days => text().withDefault(const Constant('1,2,3,4,5'))(); // 1=Mon..7=Sun
  DateTimeColumn get createdAt => dateTime()();
}

class RoutineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().references(Routines, #id)();
  TextColumn get title => text()();
  TextColumn get startTime => text().nullable()(); // "HH:mm"
  TextColumn get endTime => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 0=none,1=low,2=medium,3=high
}

class RoutineSubTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineItemId => integer().references(RoutineItems, #id)();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

class RoutineCompletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineItemId => integer().references(RoutineItems, #id)();
  DateTimeColumn get completedDate => dateTime()(); // The date this was completed
  BoolColumn get isCompleted => boolean().withDefault(const Constant(true))();
}

// ==================== TRANSACTIONS ====================
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get category => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

// ==================== MONTHLY BUDGETS ====================
class MonthlyBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get month => text()(); // "2026-03"
  RealColumn get budgetAmount => real()();
}

// ==================== LINKS ====================
class Links extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get url => text()();
  TextColumn get category => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

// ==================== HABITS ====================
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get emoji => text().withDefault(const Constant('ðŸŽ¯'))();
  IntColumn get targetDaysPerWeek => integer().withDefault(const Constant(7))();
  TextColumn get color => text().withDefault(const Constant('primary'))();
  DateTimeColumn get createdAt => dateTime()();
}

class HabitCompletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId => integer().references(Habits, #id)();
  DateTimeColumn get completedDate => dateTime()();
}

// ==================== DATABASE ====================
@DriftDatabase(tables: [
  Todos, SubTasks, FocusSessions, 
  Notes, Routines, RoutineItems, RoutineSubTasks, RoutineCompletions,
  Transactions, MonthlyBudgets, Links, Habits, HabitCompletions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(conn.connect());

  @override
int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(transactions);
        await m.createTable(monthlyBudgets);
      }
      if (from < 3) {
        await m.createTable(links);
        await m.createTable(habits);
        await m.createTable(habitCompletions);
      }
      if (from < 4) {
        // Ignore as the column is removed in schema 5
      }
      if (from < 5) {
        await m.createTable(subTasks);
        await m.createTable(focusSessions);
        await m.addColumn(todos, todos.tags);
        await m.addColumn(todos, todos.remindAt);
        await m.addColumn(todos, todos.sortOrder);
      }
      if (from < 6) {
        await m.addColumn(routineItems, routineItems.priority);
        await m.addColumn(focusSessions, focusSessions.routineItemId);
      }
      if (from < 7) {
        await m.createTable(routineSubTasks);
      }
    },
  );

  // === TODO QUERIES ===
  Stream<List<Todo>> watchAllTodos({bool? completed, int? priority}) {
    final query = select(todos)..orderBy([
      (t) => OrderingTerm.asc(t.isCompleted),
      (t) => OrderingTerm.desc(t.priority),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    if (completed != null) {
      query.where((t) => t.isCompleted.equals(completed));
    }
    if (priority != null) {
      query.where((t) => t.priority.equals(priority));
    }
    return query.watch();
  }

  Future<int> addTodo(TodosCompanion entry) => into(todos).insert(entry);

  Future<bool> updateTodo(TodosCompanion entry) =>
      (update(todos)..where((t) => t.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteTodo(int id) async {
    // Delete associated subtasks and focus sessions first
    await (delete(subTasks)..where((t) => t.todoId.equals(id))).go();
    await (delete(focusSessions)..where((t) => t.todoId.equals(id))).go();
    return (delete(todos)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleTodo(int id, bool completed) =>
      (update(todos)..where((t) => t.id.equals(id))).write(
        TodosCompanion(isCompleted: Value(completed), updatedAt: Value(DateTime.now())),
      );

  // === SUB-TASK QUERIES ===
  Stream<List<SubTask>> watchSubTasks(int todoId) {
    return (select(subTasks)
          ..where((t) => t.todoId.equals(todoId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  Future<int> addSubTask(SubTasksCompanion entry) => into(subTasks).insert(entry);

  Future<bool> updateSubTask(SubTasksCompanion entry) =>
      (update(subTasks)..where((t) => t.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteSubTask(int id) =>
      (delete(subTasks)..where((t) => t.id.equals(id))).go();

  Future<void> toggleSubTask(int id, bool completed) =>
      (update(subTasks)..where((t) => t.id.equals(id))).write(
        SubTasksCompanion(isCompleted: Value(completed)),
      );

  // === FOCUS SESSION QUERIES ===
  Stream<List<FocusSession>> watchFocusSessions(int todoId) {
    return (select(focusSessions)
          ..where((t) => t.todoId.equals(todoId))
          ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
        .watch();
  }

  Future<int> addFocusSession(FocusSessionsCompanion entry) => into(focusSessions).insert(entry);
  
  Future<int> getTotalFocusSeconds(int todoId) async {
    final result = await (select(focusSessions)..where((t) => t.todoId.equals(todoId))).get();
    return result.fold<int>(0, (sum, session) => sum + session.durationSeconds);
  }

  // === NOTES QUERIES ===
  Stream<List<Note>> watchAllNotes({String? folder}) {
    final query = select(notes)..orderBy([
      (n) => OrderingTerm.desc(n.isPinned),
      (n) => OrderingTerm.desc(n.updatedAt),
    ]);
    if (folder != null) {
      query.where((n) => n.folder.equals(folder));
    }
    return query.watch();
  }

  Stream<List<String>> watchNoteFolders() {
    final query = selectOnly(notes, distinct: true)..addColumns([notes.folder]);
    return query.watch().map((rows) =>
      rows.map((r) => r.read(notes.folder)).where((f) => f != null).cast<String>().toList(),
    );
  }

  Future<int> addNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateNote(NotesCompanion entry) =>
      (update(notes)..where((n) => n.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteNote(int id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();

  Future<void> toggleNotePin(int id, bool pinned) =>
      (update(notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(isPinned: Value(pinned), updatedAt: Value(DateTime.now())),
      );

  // === ROUTINE QUERIES ===
  Stream<List<Routine>> watchAllRoutines() =>
      (select(routines)..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).watch();

    Future<List<Routine>> getAllRoutines() =>
      (select(routines)..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get();

  Future<int> addRoutine(RoutinesCompanion entry) => into(routines).insert(entry);

  Future<bool> updateRoutine(RoutinesCompanion entry) =>
      (update(routines)..where((r) => r.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteRoutine(int id) {
    return transaction(() async {
      await (delete(routineItems)..where((ri) => ri.routineId.equals(id))).go();
      return (delete(routines)..where((r) => r.id.equals(id))).go();
    });
  }

  Stream<List<RoutineItem>> watchRoutineItems(int routineId) =>
      (select(routineItems)
        ..where((ri) => ri.routineId.equals(routineId))
        ..orderBy([
          (ri) => OrderingTerm.desc(ri.priority),
          (ri) => OrderingTerm.asc(ri.sortOrder),
          (ri) => OrderingTerm.asc(ri.id),
        ])
      ).watch();

  Future<int> addRoutineItem(RoutineItemsCompanion entry) => into(routineItems).insert(entry);

  Future<bool> updateRoutineItem(RoutineItemsCompanion entry) =>
      (update(routineItems)..where((ri) => ri.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteRoutineItem(int id) =>
      transaction(() async {
        await (delete(routineSubTasks)..where((st) => st.routineItemId.equals(id))).go();
        return (delete(routineItems)..where((ri) => ri.id.equals(id))).go();
      });

  Stream<List<RoutineSubTask>> watchRoutineSubTasks(int routineItemId) {
    return (select(routineSubTasks)
          ..where((st) => st.routineItemId.equals(routineItemId))
          ..orderBy([(st) => OrderingTerm.asc(st.sortOrder), (st) => OrderingTerm.asc(st.id)]))
        .watch();
  }

  Future<int> addRoutineSubTask(RoutineSubTasksCompanion entry) => into(routineSubTasks).insert(entry);

  Future<bool> updateRoutineSubTask(RoutineSubTasksCompanion entry) =>
      (update(routineSubTasks)..where((st) => st.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteRoutineSubTask(int id) =>
      (delete(routineSubTasks)..where((st) => st.id.equals(id))).go();

  Future<void> toggleRoutineSubTask(int id, bool completed) =>
      (update(routineSubTasks)..where((st) => st.id.equals(id))).write(
        RoutineSubTasksCompanion(isCompleted: Value(completed)),
      );

  // Completions
  Stream<List<RoutineCompletion>> watchTodayCompletions() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return (select(routineCompletions)
      ..where((c) => c.completedDate.isBiggerOrEqualValue(start) & c.completedDate.isSmallerThanValue(end))
    ).watch();
  }

  Future<int> markRoutineItemCompleted(int itemId) =>
      into(routineCompletions).insert(RoutineCompletionsCompanion(
        routineItemId: Value(itemId),
        completedDate: Value(DateTime.now()),
      ));

  Future<void> unmarkRoutineItemCompleted(int itemId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    await (delete(routineCompletions)
      ..where((c) => c.routineItemId.equals(itemId) &
          c.completedDate.isBiggerOrEqualValue(start) &
          c.completedDate.isSmallerThanValue(end))
    ).go();
  }

  // === TRANSACTION QUERIES ===
  Stream<List<Transaction>> watchTransactions({DateTime? from, DateTime? to}) {
    final query = select(transactions)..orderBy([
      (t) => OrderingTerm.desc(t.date),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    if (from != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.date.isSmallerThanValue(to));
    }
    return query.watch();
  }

  Stream<List<Transaction>> watchTodayTransactions() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return watchTransactions(from: start, to: end);
  }

  Stream<List<Transaction>> watchMonthTransactions(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return watchTransactions(from: start, to: end);
  }

  Future<int> addTransaction(TransactionsCompanion entry) => into(transactions).insert(entry);

  Future<bool> updateTransaction(TransactionsCompanion entry) =>
      (update(transactions)..where((t) => t.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  // === BUDGET QUERIES ===
  Stream<MonthlyBudget?> watchBudget(String month) {
    return (select(monthlyBudgets)..where((b) => b.month.equals(month)))
        .watchSingleOrNull();
  }

  Future<void> setBudget(String month, double amount) async {
    final existing = await (select(monthlyBudgets)..where((b) => b.month.equals(month))).getSingleOrNull();
    if (existing != null) {
      await (update(monthlyBudgets)..where((b) => b.id.equals(existing.id))).write(
        MonthlyBudgetsCompanion(budgetAmount: Value(amount)),
      );
    } else {
      await into(monthlyBudgets).insert(MonthlyBudgetsCompanion(
        month: Value(month),
        budgetAmount: Value(amount),
      ));
    }
  }

  Future<void> deleteBudget(String month) =>
      (delete(monthlyBudgets)..where((b) => b.month.equals(month))).go();

  // === LINK QUERIES ===
  Stream<List<Link>> watchAllLinks({String? category}) {
    final query = select(links)..orderBy([
      (l) => OrderingTerm.desc(l.isFavorite),
      (l) => OrderingTerm.desc(l.createdAt),
    ]);
    if (category != null) {
      query.where((l) => l.category.equals(category));
    }
    return query.watch();
  }

  Stream<List<String>> watchLinkCategories() {
    final query = selectOnly(links, distinct: true)..addColumns([links.category]);
    return query.watch().map((rows) =>
      rows.map((r) => r.read(links.category)).where((c) => c != null).cast<String>().toList(),
    );
  }

  Future<int> addLink(LinksCompanion entry) => into(links).insert(entry);

  Future<bool> updateLink(LinksCompanion entry) =>
      (update(links)..where((l) => l.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteLink(int id) =>
      (delete(links)..where((l) => l.id.equals(id))).go();

  Future<void> toggleLinkFavorite(int id, bool favorite) =>
      (update(links)..where((l) => l.id.equals(id))).write(
        LinksCompanion(isFavorite: Value(favorite)),
      );

  // === HABIT QUERIES ===
  Stream<List<Habit>> watchAllHabits() =>
      (select(habits)..orderBy([(h) => OrderingTerm.desc(h.createdAt)])).watch();

  Future<int> addHabit(HabitsCompanion entry) => into(habits).insert(entry);

  Future<bool> updateHabit(HabitsCompanion entry) =>
      (update(habits)..where((h) => h.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteHabit(int id) {
    return transaction(() async {
      await (delete(habitCompletions)..where((c) => c.habitId.equals(id))).go();
      return (delete(habits)..where((h) => h.id.equals(id))).go();
    });
  }

  Stream<List<HabitCompletion>> watchHabitCompletions({DateTime? from, DateTime? to}) {
    final query = select(habitCompletions)..orderBy([(c) => OrderingTerm.desc(c.completedDate)]);
    if (from != null) {
      query.where((c) => c.completedDate.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((c) => c.completedDate.isSmallerThanValue(to));
    }
    return query.watch();
  }

  Stream<List<HabitCompletion>> watchTodayHabitCompletions() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return watchHabitCompletions(from: start, to: end);
  }

  Future<int> markHabitCompleted(int habitId) =>
      into(habitCompletions).insert(HabitCompletionsCompanion(
        habitId: Value(habitId),
        completedDate: Value(DateTime.now()),
      ));

  Future<void> unmarkHabitCompleted(int habitId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    await (delete(habitCompletions)
      ..where((c) => c.habitId.equals(habitId) &
          c.completedDate.isBiggerOrEqualValue(start) &
          c.completedDate.isSmallerThanValue(end))
    ).go();
  }

  /// Get streak count for a habit (consecutive days completed up to today)
  Future<int> getHabitStreak(int habitId) async {
    final allCompletions = await (select(habitCompletions)
      ..where((c) => c.habitId.equals(habitId))
      ..orderBy([(c) => OrderingTerm.desc(c.completedDate)])
    ).get();

    if (allCompletions.isEmpty) return 0;

    // Get unique dates
    final dates = allCompletions
        .map((c) => DateTime(c.completedDate.year, c.completedDate.month, c.completedDate.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    var checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

    // Allow today to not be completed yet
    if (dates.isNotEmpty && dates.first != checkDate) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    for (final date in dates) {
      if (date == checkDate) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(checkDate)) {
        break;
      }
    }

    return streak;
  }

  // === RECENT ACTIVITY (cross-module) ===
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 5}) async {
    final List<Map<String, dynamic>> activities = [];

    // Recent todos
    final recentTodos = await (select(todos)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(limit)
    ).get();
    for (final t in recentTodos) {
      activities.add({
        'type': 'todo',
        'title': t.isCompleted ? 'Completed: ${t.title}' : 'Added: ${t.title}',
        'time': t.updatedAt,
        'icon': t.isCompleted ? 'check' : 'add_task',
      });
    }

    // Recent notes
    final recentNotes = await (select(notes)
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
      ..limit(limit)
    ).get();
    for (final n in recentNotes) {
      activities.add({
        'type': 'note',
        'title': 'Note: ${n.title}',
        'time': n.updatedAt,
        'icon': 'note',
      });
    }

    // Recent transactions
    final recentTx = await (select(transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit)
    ).get();
    for (final tx in recentTx) {
      final prefix = tx.type == 'income' ? '+' : '-';
      activities.add({
        'type': 'transaction',
        'title': 'Transaction: $prefix${tx.amount.toStringAsFixed(0)} > ${tx.title}',
        'time': tx.createdAt,
        'icon': tx.type == 'income' ? 'income' : 'expense',
      });
    }

    // Sort all by time, take the most recent
    activities.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));
    return activities.take(limit).toList();
  }

  // === CALENDAR QUERIES (cross-module) ===
  Future<Map<DateTime, List<Map<String, dynamic>>>> getMonthEvents(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final Map<DateTime, List<Map<String, dynamic>>> events = {};

    // Todos with due dates in this month
    final monthTodos = await (select(todos)
      ..where((t) => t.dueDate.isNotNull() &
          t.dueDate.isBiggerOrEqualValue(start) &
          t.dueDate.isSmallerThanValue(end))
    ).get();
    for (final t in monthTodos) {
      final day = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      events.putIfAbsent(day, () => []).add({
        'type': 'todo',
        'title': t.title,
        'isCompleted': t.isCompleted,
        'color': 'primary',
      });
    }

    // Transactions in this month
    final monthTx = await (select(transactions)
      ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
    ).get();
    for (final tx in monthTx) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      events.putIfAbsent(day, () => []).add({
        'type': 'transaction',
        'title': 'Transaction: ${tx.type == 'income' ? '+' : '-'}${tx.amount.toStringAsFixed(0)} > ${tx.title}',
        'txType': tx.type,
        'color': tx.type == 'income' ? 'success' : 'error',
      });
    }

    // Habit completions in this month
    final monthHabits = await (select(habitCompletions)
      ..where((c) => c.completedDate.isBiggerOrEqualValue(start) & c.completedDate.isSmallerThanValue(end))
    ).get();
    // Group habit IDs per day
    final habitMap = <DateTime, Set<int>>{};
    for (final hc in monthHabits) {
      final day = DateTime(hc.completedDate.year, hc.completedDate.month, hc.completedDate.day);
      habitMap.putIfAbsent(day, () => {}).add(hc.habitId);
    }
    for (final entry in habitMap.entries) {
      events.putIfAbsent(entry.key, () => []).add({
        'type': 'habit',
        'title': '${entry.value.length} habit(s) done',
        'color': 'purple',
      });
    }

    return events;
  }
}


