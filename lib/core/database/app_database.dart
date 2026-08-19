import 'dart:convert';
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
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringPattern => text().nullable()(); // 'daily', 'weekdays', 'weekly', 'monthly'
  
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

class NoteVersions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get content => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
}

// ==================== ROUTINES ====================
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(2))(); // 1=low,2=medium,3=high
  TextColumn get days => text().withDefault(const Constant('1,2,3,4,5'))(); // 1=Mon..7=Sun
  TextColumn get reminderTime => text().nullable()();
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

// ==================== WALLETS ====================
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get icon => text().withDefault(const Constant('account_balance_wallet'))();
  TextColumn get color => text().withDefault(const Constant('primary'))();
  RealColumn get initialBalance => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
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
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringPattern => text().nullable()(); // 'daily', 'weekly', 'monthly', 'yearly'
  IntColumn get walletId => integer().nullable()(); // Link to Wallets table
  DateTimeColumn get createdAt => dateTime()();
}

// ==================== MONTHLY BUDGETS ====================
class MonthlyBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get month => text()(); // "2026-03"
  RealColumn get budgetAmount => real()();
}

class CategoryBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get month => text()(); // "2026-03"
  TextColumn get category => text()();
  RealColumn get budgetAmount => real()();
}

// ==================== LINK FOLDERS ====================
class LinkFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get emoji => text().withDefault(const Constant('📁'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

// ==================== LINKS ====================
class Links extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get url => text()();
  TextColumn get category => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get previewImageUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get folderId => integer().nullable().references(LinkFolders, #id)();
  TextColumn get tags => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

// ==================== HABITS ====================
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get emoji => text().withDefault(const Constant('🎯'))();
  IntColumn get targetDaysPerWeek => integer().withDefault(const Constant(7))();
  TextColumn get color => text().withDefault(const Constant('primary'))();
  TextColumn get reminderTime => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class HabitCompletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId => integer().references(Habits, #id)();
  DateTimeColumn get completedDate => dateTime()();
}

// ==================== DEBTS ====================
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get personName => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  TextColumn get type => text()(); // 'given' (I lent) or 'taken' (I borrowed)
  TextColumn get note => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  BoolColumn get linkedToWallet => boolean().withDefault(const Constant(false))();
  IntColumn get linkedTransactionId => integer().nullable()();
  IntColumn get settlementTransactionId => integer().nullable()();
  IntColumn get walletId => integer().nullable()(); // Link to Wallets table
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id)();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get paidAt => dateTime()();
  IntColumn get linkedTransactionId => integer().nullable()();
  IntColumn get walletId => integer().nullable()(); // Link to Wallets table
}

// ==================== BIRTHDAYS ====================
class Birthdays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get personName => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dateOfBirth => dateTime()();
  BoolColumn get remindDayBefore => boolean().withDefault(const Constant(true))();
  BoolColumn get remindOnDay => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ==================== CONTACT LIST ====================
class ContactEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get displayName => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().withLength(min: 1, max: 80)();
  TextColumn get normalizedPhone => text().withLength(min: 1, max: 80)();
  TextColumn get source => text().withDefault(const Constant('manual'))(); // manual or phone
  TextColumn get externalContactId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ==================== DIARY / JOURNAL ====================
class DiaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()(); // normalized entry date
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get weather => text().nullable()(); // 'sunny', 'rainy', 'cloudy', 'clear_night'
  TextColumn get location => text().nullable()();
  TextColumn get tags => text().nullable()(); // comma-separated tags
  TextColumn get templateType => text().nullable()(); // 'standup', 'evening_review', 'strategy', 'freeform'
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ==================== DATABASE ====================
@DriftDatabase(tables: [
  Todos, SubTasks, FocusSessions, 
  Notes, NoteVersions, Routines, RoutineItems, RoutineSubTasks, RoutineCompletions,
  Wallets, Transactions, MonthlyBudgets, CategoryBudgets, LinkFolders, Links, Habits, HabitCompletions,
  Debts, DebtPayments,
  Birthdays, ContactEntries,
  DiaryEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(conn.connect());

  @override
  int get schemaVersion => 19;

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
      if (from < 8) {
        await m.createTable(debts);
        await m.createTable(debtPayments);
      }
      if (from < 9) {
        await m.addColumn(routines, routines.reminderTime);
        await m.addColumn(habits, habits.reminderTime);
        await m.addColumn(transactions, transactions.isRecurring);
        await m.addColumn(transactions, transactions.recurringPattern);
      }
      if (from < 10) {
        await m.createTable(linkFolders);
      }
      if (from < 11) {
        await m.addColumn(routines, routines.priority);
      }
      if (from < 12) {
        await m.createTable(birthdays);
        await m.createTable(contactEntries);
      }
      if (from < 13) {
        await m.addColumn(debts, debts.linkedToWallet);
        await m.addColumn(debts, debts.linkedTransactionId);
        await m.addColumn(debts, debts.settlementTransactionId);
      }
      if (from < 14) {
        await m.addColumn(debtPayments, debtPayments.linkedTransactionId);
      }
      if (from < 15) {
        await m.createTable(noteVersions);
      }
      if (from < 16) {
        await m.addColumn(todos, todos.isRecurring);
        await m.addColumn(todos, todos.recurringPattern);
      }
      if (from < 17) {
        await m.createTable(wallets);
        await m.createTable(categoryBudgets);
        await m.addColumn(transactions, transactions.walletId);
        await m.addColumn(debts, debts.walletId);
        await m.addColumn(debtPayments, debtPayments.walletId);
      }
      if (from < 18) {
        await m.addColumn(links, links.isRead);
        await m.addColumn(links, links.previewImageUrl);
        await m.addColumn(links, links.description);
        await m.addColumn(links, links.folderId);
        await m.addColumn(links, links.tags);
      }
      if (from < 19) {
        await m.createTable(diaryEntries);
      }
    },
  );

  // === TODO QUERIES ===
  Stream<List<Todo>> watchAllTodos({bool? completed, int? priority}) {
    final query = select(todos)..orderBy([
      (t) => OrderingTerm.asc(t.isCompleted),
      (t) => OrderingTerm.desc(t.priority),
      (t) => OrderingTerm.asc(t.sortOrder),
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

  Future<void> completeTodoWithRecurrence(int id, bool completed) async {
    final now = DateTime.now();
    await (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(isCompleted: Value(completed), updatedAt: Value(now)),
    );

    // If marked as completed and is recurring, spawn next occurrence
    if (completed) {
      final todo = await (select(todos)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (todo != null && todo.isRecurring && todo.recurringPattern != null && todo.recurringPattern!.isNotEmpty) {
        DateTime? nextDueDate;
        final baseDate = todo.dueDate ?? now;

        switch (todo.recurringPattern) {
          case 'daily':
            nextDueDate = baseDate.add(const Duration(days: 1));
            break;
          case 'weekdays':
            var next = baseDate.add(const Duration(days: 1));
            while (next.weekday == DateTime.saturday || next.weekday == DateTime.sunday) {
              next = next.add(const Duration(days: 1));
            }
            nextDueDate = next;
            break;
          case 'weekly':
            nextDueDate = baseDate.add(const Duration(days: 7));
            break;
          case 'monthly':
            nextDueDate = DateTime(baseDate.year, baseDate.month + 1, baseDate.day, baseDate.hour, baseDate.minute);
            break;
          default:
            nextDueDate = baseDate.add(const Duration(days: 1));
        }

        DateTime? nextRemindAt;
        if (todo.remindAt != null && todo.dueDate != null) {
          final diff = todo.dueDate!.difference(todo.remindAt!);
          nextRemindAt = nextDueDate.subtract(diff);
        } else if (todo.remindAt != null) {
          nextRemindAt = nextDueDate;
        }

        final newTodoId = await into(todos).insert(TodosCompanion(
          title: Value(todo.title),
          description: Value(todo.description),
          dueDate: Value(nextDueDate),
          remindAt: Value(nextRemindAt),
          priority: Value(todo.priority),
          category: Value(todo.category),
          tags: Value(todo.tags),
          isRecurring: const Value(true),
          recurringPattern: Value(todo.recurringPattern),
          isCompleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));

        // Clone subtasks for the new recurring instance
        final currentSubtasks = await (select(subTasks)..where((st) => st.todoId.equals(id))).get();
        for (final st in currentSubtasks) {
          await into(subTasks).insert(SubTasksCompanion(
            todoId: Value(newTodoId),
            title: Value(st.title),
            isCompleted: const Value(false),
            sortOrder: Value(st.sortOrder),
            createdAt: Value(now),
          ));
        }
      }
    }
  }

  Future<void> updateTodoSortOrders(List<({int id, int sortOrder})> updates) async {
    await batch((b) {
      for (final item in updates) {
        b.update(
          todos,
          TodosCompanion(sortOrder: Value(item.sortOrder)),
          where: (t) => t.id.equals(item.id),
        );
      }
    });
  }

  Future<List<String>> getAllTodoTags() async {
    final allTodos = await select(todos).get();
    final Map<String, int> tagCount = {};
    for (final todo in allTodos) {
      try {
        final decoded = jsonDecode(todo.tags);
        if (decoded is List) {
          for (final tag in decoded) {
            final s = tag.toString().trim();
            if (s.isNotEmpty) {
              tagCount[s] = (tagCount[s] ?? 0) + 1;
            }
          }
        }
      } catch (_) {}
    }
    final sorted = tagCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

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

  // === NOTE VERSIONS QUERIES ===
  static const int maxNoteVersionsPerNote = 10;

  Stream<List<NoteVersion>> watchNoteVersions(int noteId) {
    return (select(noteVersions)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .watch();
  }

  Future<List<NoteVersion>> getNoteVersions(int noteId) {
    return (select(noteVersions)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .get();
  }

  Future<int> addNoteVersion(NoteVersionsCompanion entry) async {
    final insertedId = await into(noteVersions).insert(entry);
    await _pruneOldNoteVersions(entry.noteId.value);
    return insertedId;
  }

  Future<void> _pruneOldNoteVersions(int noteId) async {
    final allVersions = await (select(noteVersions)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .get();

    if (allVersions.length > maxNoteVersionsPerNote) {
      final excess = allVersions.sublist(maxNoteVersionsPerNote);
      final excessIds = excess.map((v) => v.id).toList();
      await (delete(noteVersions)..where((v) => v.id.isIn(excessIds))).go();
    }
  }

  Future<int> deleteNoteVersion(int id) =>
      (delete(noteVersions)..where((v) => v.id.equals(id))).go();

  Future<bool> restoreNoteVersion(int noteId, int versionId) async {
    final version = await (select(noteVersions)..where((v) => v.id.equals(versionId))).getSingleOrNull();
    if (version == null) return false;

    // Snapshot current state first so user can never lose anything
    final current = await (select(notes)..where((n) => n.id.equals(noteId))).getSingleOrNull();
    if (current != null) {
      await addNoteVersion(NoteVersionsCompanion(
        noteId: Value(noteId),
        title: Value(current.title),
        content: Value(current.content),
        createdAt: Value(DateTime.now()),
      ));
    }

    await (update(notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        title: Value(version.title),
        content: Value(version.content),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return true;
  }

  // === ROUTINE QUERIES ===
  Stream<List<Routine>> watchAllRoutines() =>
      (select(routines)
        ..orderBy([
          (r) => OrderingTerm.desc(r.priority),
          (r) => OrderingTerm.desc(r.createdAt),
        ])).watch();

    Future<List<Routine>> getAllRoutines() =>
      (select(routines)
        ..orderBy([
          (r) => OrderingTerm.desc(r.priority),
          (r) => OrderingTerm.desc(r.createdAt),
        ])).get();

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

  Stream<List<RoutineItem>> watchAllRoutineItems() =>
      (select(routineItems)
        ..orderBy([
          (ri) => OrderingTerm.asc(ri.routineId),
          (ri) => OrderingTerm.desc(ri.priority),
          (ri) => OrderingTerm.asc(ri.sortOrder),
          (ri) => OrderingTerm.asc(ri.id),
        ])).watch();

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

  Future<void> toggleRoutineSubTask(int id, bool completed) async {
    await (update(routineSubTasks)..where((st) => st.id.equals(id))).write(
      RoutineSubTasksCompanion(isCompleted: Value(completed)),
    );
    if (completed) {
      final subTask = await (select(routineSubTasks)..where((st) => st.id.equals(id))).getSingle();
      final siblings = await (select(routineSubTasks)..where((st) => st.routineItemId.equals(subTask.routineItemId))).get();
      if (siblings.isNotEmpty && siblings.every((st) => st.isCompleted)) {
        // check if already completed today
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        final end = start.add(const Duration(days: 1));
        final alreadyDone = await (select(routineCompletions)
          ..where((c) => c.routineItemId.equals(subTask.routineItemId) &
              c.completedDate.isBiggerOrEqualValue(start) &
              c.completedDate.isSmallerThanValue(end))).getSingleOrNull();
        if (alreadyDone == null) {
          await markRoutineItemCompleted(subTask.routineItemId);
        }
      }
    }
  }

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

  Future<List<RoutineCompletion>> getRoutineCompletions(int routineId) {
    final query = select(routineCompletions).join([
      innerJoin(routineItems, routineItems.id.equalsExp(routineCompletions.routineItemId))
    ])
      ..where(routineItems.routineId.equals(routineId))
      ..orderBy([OrderingTerm.desc(routineCompletions.completedDate)]);
      
    return query.map((row) => row.readTable(routineCompletions)).get();
  }

  Future<Map<DateTime, double>> getMonthlyRoutineCompletions(int routineId, int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);

    final items = await (select(routineItems)..where((ri) => ri.routineId.equals(routineId))).get();
    if (items.isEmpty) return {};

    final itemIds = items.map((i) => i.id).toSet();
    final totalItems = items.length;

    final completions = await (select(routineCompletions)
      ..where((c) => c.routineItemId.isIn(itemIds) &
          c.completedDate.isBiggerOrEqualValue(start) &
          c.completedDate.isSmallerThanValue(end))
    ).get();

    final Map<DateTime, Set<int>> dayCompletedItemIds = {};
    for (final c in completions) {
      final day = DateTime(c.completedDate.year, c.completedDate.month, c.completedDate.day);
      dayCompletedItemIds.putIfAbsent(day, () => <int>{}).add(c.routineItemId);
    }

    final Map<DateTime, double> rates = {};
    for (final entry in dayCompletedItemIds.entries) {
      rates[entry.key] = (entry.value.length / totalItems).clamp(0.0, 1.0);
    }
    return rates;
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

  // === CATEGORY BUDGET QUERIES ===
  Stream<List<CategoryBudget>> watchCategoryBudgets(String month) {
    return (select(categoryBudgets)..where((b) => b.month.equals(month))).watch();
  }

  Future<void> setCategoryBudget(String month, String category, double amount) async {
    final existing = await (select(categoryBudgets)
      ..where((b) => b.month.equals(month) & b.category.equals(category))
    ).getSingleOrNull();

    if (existing != null) {
      await (update(categoryBudgets)..where((b) => b.id.equals(existing.id))).write(
        CategoryBudgetsCompanion(budgetAmount: Value(amount)),
      );
    } else {
      await into(categoryBudgets).insert(CategoryBudgetsCompanion(
        month: Value(month),
        category: Value(category),
        budgetAmount: Value(amount),
      ));
    }
  }

  Future<void> deleteCategoryBudget(String month, String category) =>
      (delete(categoryBudgets)
        ..where((b) => b.month.equals(month) & b.category.equals(category))
      ).go();

  // === WALLET / ACCOUNT QUERIES ===
  Stream<List<Wallet>> watchAllWallets() =>
      (select(wallets)..orderBy([(w) => OrderingTerm.asc(w.id)])).watch();

  Future<List<Wallet>> getAllWallets() =>
      (select(wallets)..orderBy([(w) => OrderingTerm.asc(w.id)])).get();

  Future<int> addWallet(WalletsCompanion entry) => into(wallets).insert(entry);

  Future<bool> updateWallet(WalletsCompanion entry) =>
      (update(wallets)..where((w) => w.id.equals(entry.id.value))).write(entry).then((r) => r > 0);

  Future<int> deleteWallet(int id) =>
      (delete(wallets)..where((w) => w.id.equals(id))).go();

  Future<void> ensureDefaultWallets() async {
    final existing = await getAllWallets();
    if (existing.isEmpty) {
      final now = DateTime.now();
      await into(wallets).insert(WalletsCompanion(
        name: const Value('Cash'),
        icon: const Value('payments_rounded'),
        color: const Value('green'),
        initialBalance: const Value(0),
        createdAt: Value(now),
      ));
      await into(wallets).insert(WalletsCompanion(
        name: const Value('Bank'),
        icon: const Value('account_balance_rounded'),
        color: const Value('blue'),
        initialBalance: const Value(0),
        createdAt: Value(now),
      ));
      await into(wallets).insert(WalletsCompanion(
        name: const Value('bKash'),
        icon: const Value('phone_android_rounded'),
        color: const Value('pink'),
        initialBalance: const Value(0),
        createdAt: Value(now),
      ));
      await into(wallets).insert(WalletsCompanion(
        name: const Value('Nagad'),
        icon: const Value('account_balance_wallet_rounded'),
        color: const Value('orange'),
        initialBalance: const Value(0),
        createdAt: Value(now),
      ));
    }
  }

  // === 6-MONTH CASHFLOW QUERY ===
  Future<List<({String month, double income, double expense})>> getCashflowLast6Months() async {
    final now = DateTime.now();
    final List<({String month, double income, double expense})> result = [];

    for (int i = 5; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final monthStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}';
      final start = targetDate;
      final end = (targetDate.month == 12)
          ? DateTime(targetDate.year + 1, 1, 1)
          : DateTime(targetDate.year, targetDate.month + 1, 1);

      final txs = await (select(transactions)
        ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
      ).get();

      double inc = 0;
      double exp = 0;
      for (final t in txs) {
        if (t.type == 'income') {
          inc += t.amount;
        } else {
          exp += t.amount;
        }
      }

      result.add((month: monthStr, income: inc, expense: exp));
    }

    return result;
  }

  // === LINK FOLDER QUERIES ===
  Stream<List<LinkFolder>> watchAllLinkFolders() =>
      (select(linkFolders)..orderBy([
        (f) => OrderingTerm.asc(f.sortOrder),
        (f) => OrderingTerm.asc(f.createdAt),
      ])).watch();

  Future<List<LinkFolder>> getAllLinkFolders() =>
      (select(linkFolders)..orderBy([
        (f) => OrderingTerm.asc(f.sortOrder),
        (f) => OrderingTerm.asc(f.createdAt),
      ])).get();

  Future<int> addLinkFolder(LinkFoldersCompanion entry) => into(linkFolders).insert(entry);

  Future<bool> updateLinkFolder(LinkFoldersCompanion entry) async {
    final oldFolder = await (select(linkFolders)..where((f) => f.id.equals(entry.id.value))).getSingleOrNull();
    final updated = await (update(linkFolders)..where((f) => f.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);
    if (updated && oldFolder != null && entry.name.present && entry.name.value != oldFolder.name) {
      // Sync links that stored the category name
      await (update(links)..where((l) => l.folderId.equals(entry.id.value) | l.category.equals(oldFolder.name))).write(
        LinksCompanion(category: Value(entry.name.value)),
      );
    }
    return updated;
  }

  Future<int> deleteLinkFolder(int id) async {
    final folder = await (select(linkFolders)..where((f) => f.id.equals(id))).getSingleOrNull();
    if (folder != null) {
      await (delete(links)..where((l) => l.folderId.equals(id) | l.category.equals(folder.name))).go();
    }
    return (delete(linkFolders)..where((f) => f.id.equals(id))).go();
  }

  Future<int> getLinkCountInFolder(int? folderId, {String? folderName}) async {
    final query = select(links);
    if (folderId != null) {
      query.where((l) => l.folderId.equals(folderId) | (l.category.equals(folderName ?? '')));
    } else if (folderName != null) {
      query.where((l) => l.category.equals(folderName));
    }
    final result = await query.get();
    return result.length;
  }

  // === LINK QUERIES ===
  Stream<List<Link>> watchAllLinks({String? category, int? folderId, bool? isFavorite, bool? isRead}) {
    final query = select(links)..orderBy([
      (l) => OrderingTerm.desc(l.isFavorite),
      (l) => OrderingTerm.desc(l.createdAt),
    ]);
    if (folderId != null) {
      query.where((l) => l.folderId.equals(folderId) | (category != null ? l.category.equals(category) : const Constant(false)));
    } else if (category != null) {
      query.where((l) => l.category.equals(category));
    }
    if (isFavorite != null) {
      query.where((l) => l.isFavorite.equals(isFavorite));
    }
    if (isRead != null) {
      query.where((l) => l.isRead.equals(isRead));
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

  Future<void> toggleLinkReadStatus(int id, bool isRead) =>
      (update(links)..where((l) => l.id.equals(id))).write(
        LinksCompanion(isRead: Value(isRead)),
      );

  Future<Link?> getDuplicateLink(String url) async {
    final trimmed = url.trim().toLowerCase();
    final all = await select(links).get();
    return all.where((l) => l.url.trim().toLowerCase() == trimmed).firstOrNull;
  }

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

    // Routine completions in this month
    final monthRoutines = await (select(routineCompletions)
      ..where((c) => c.completedDate.isBiggerOrEqualValue(start) & c.completedDate.isSmallerThanValue(end))
    ).get();
    final routineDayMap = <DateTime, Set<int>>{};
    for (final rc in monthRoutines) {
      final day = DateTime(rc.completedDate.year, rc.completedDate.month, rc.completedDate.day);
      routineDayMap.putIfAbsent(day, () => {}).add(rc.routineItemId);
    }
    for (final entry in routineDayMap.entries) {
      events.putIfAbsent(entry.key, () => []).add({
        'type': 'routine',
        'title': '${entry.value.length} routine item(s) done',
        'color': 'warning',
      });
    }

    // Focus sessions / timer history in this month
    final monthFocus = await (select(focusSessions)
      ..where((f) => f.startTime.isBiggerOrEqualValue(start) & f.startTime.isSmallerThanValue(end))
    ).get();
    final focusDayMap = <DateTime, List<Map<String, dynamic>>>{};
    for (final f in monthFocus) {
      final day = DateTime(f.startTime.year, f.startTime.month, f.startTime.day);
      focusDayMap.putIfAbsent(day, () => []).add({
        'duration': f.durationSeconds,
        'type': f.sessionType,
      });
    }
    for (final entry in focusDayMap.entries) {
      final totalMin = entry.value.fold<int>(0, (sum, e) => sum + (e['duration'] as int)) ~/ 60;
      events.putIfAbsent(entry.key, () => []).add({
        'type': 'focus',
        'title': 'Focus: ${totalMin}min (${entry.value.length} session${entry.value.length > 1 ? 's' : ''})',
        'color': 'teal',
      });
    }

    // Debts with due dates in this month
    final monthDebts = await (select(debts)
      ..where((d) => d.dueDate.isNotNull() &
          d.dueDate.isBiggerOrEqualValue(start) &
          d.dueDate.isSmallerThanValue(end))
    ).get();
    for (final d in monthDebts) {
      final day = DateTime(d.dueDate!.year, d.dueDate!.month, d.dueDate!.day);
      final label = d.isSettled ? 'Settled' : 'Due';
      events.putIfAbsent(day, () => []).add({
        'type': 'debt',
        'title': 'Debt $label: ${d.personName} ৳${d.amount.toStringAsFixed(0)}',
        'color': d.isSettled ? 'success' : 'error',
        'isSettled': d.isSettled,
      });
    }

    // Birthdays in this month (use calendar year, not birth year; convert to local timezone)
    final allBirthdays = await getAllBirthdays();
    for (final b in allBirthdays) {
      final localDob = b.dateOfBirth.toLocal();
      if (localDob.month == month) {
        final bday = DateTime(year, localDob.month, localDob.day);
        events.putIfAbsent(bday, () => []).add({
          'type': 'birthday',
          'title': "${b.personName}'s Birthday",
          'color': 'pink',
          'id': b.id,
        });
      }
    }

    // Diary entries in this month
    final monthDiary = await (select(diaryEntries)
      ..where((d) => d.date.isBiggerOrEqualValue(start) & d.date.isSmallerThanValue(end))
    ).get();
    for (final de in monthDiary) {
      final day = DateTime(de.date.year, de.date.month, de.date.day);
      events.putIfAbsent(day, () => []).add({
        'id': de.id,
        'type': 'diary',
        'title': de.title != null && de.title!.isNotEmpty ? de.title! : 'Journal Entry',
        'color': 'purple',
      });
    }

    return events;
  }

  // === DAY EVENTS (detailed per-day view) ===
  Future<List<Map<String, dynamic>>> getDayEvents(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final events = <Map<String, dynamic>>[];

    // Todos due on this day
    final dayTodos = await (select(todos)
      ..where((t) => t.dueDate.isNotNull() &
          t.dueDate.isBiggerOrEqualValue(start) &
          t.dueDate.isSmallerThanValue(end))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.desc(t.createdAt)])
    ).get();
    for (final t in dayTodos) {
      events.add({
        'id': t.id,
        'type': 'todo',
        'title': t.title,
        'isCompleted': t.isCompleted,
        'color': 'primary',
        'priority': t.priority,
        'description': t.description,
        'dueDate': t.dueDate,
        'remindAt': t.remindAt,
      });
    }

    // Transactions on this day
    final dayTx = await (select(transactions)
      ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
    ).get();
    for (final tx in dayTx) {
      events.add({
        'id': tx.id,
        'type': 'transaction',
        'title': tx.title,
        'amount': tx.amount,
        'txType': tx.type,
        'category': tx.category,
        'color': tx.type == 'income' ? 'success' : 'error',
        'date': tx.date,
      });
    }

    // Habit completions on this day (Bulk lookup to prevent N+1 query loop)
    final dayHabits = await (select(habitCompletions)
      ..where((c) => c.completedDate.isBiggerOrEqualValue(start) & c.completedDate.isSmallerThanValue(end))
    ).get();
    if (dayHabits.isNotEmpty) {
      final allHabits = await select(habits).get();
      final habitNames = {for (final h in allHabits) h.id: '${h.emoji} ${h.title}'};
      for (final hc in dayHabits) {
        events.add({
          'id': hc.id,
          'habitId': hc.habitId,
          'type': 'habit',
          'title': habitNames[hc.habitId] ?? 'Habit done',
          'color': 'purple',
          'completedDate': hc.completedDate,
        });
      }
    }

    // Routine completions on this day (Bulk lookup to prevent N+1 query loop)
    final dayRoutines = await (select(routineCompletions)
      ..where((c) => c.completedDate.isBiggerOrEqualValue(start) & c.completedDate.isSmallerThanValue(end))
    ).get();
    if (dayRoutines.isNotEmpty) {
      final allRoutineItems = await select(routineItems).get();
      final itemNames = {for (final ri in allRoutineItems) ri.id: ri.title};
      for (final rc in dayRoutines) {
        events.add({
          'id': rc.id,
          'routineItemId': rc.routineItemId,
          'type': 'routine',
          'title': itemNames[rc.routineItemId] ?? 'Routine done',
          'color': 'warning',
          'completedDate': rc.completedDate,
        });
      }
    }

    // Focus sessions on this day
    final dayFocus = await (select(focusSessions)
      ..where((f) => f.startTime.isBiggerOrEqualValue(start) & f.startTime.isSmallerThanValue(end))
      ..orderBy([(f) => OrderingTerm.desc(f.startTime)])
    ).get();
    for (final f in dayFocus) {
      final min = f.durationSeconds ~/ 60;
      final sec = f.durationSeconds % 60;
      events.add({
        'id': f.id,
        'type': 'focus',
        'title': 'Focus: ${min}m ${sec}s',
        'color': 'teal',
        'sessionType': f.sessionType,
        'startTime': f.startTime,
        'durationSeconds': f.durationSeconds,
      });
    }

    // Debts due on this day
    final dayDebts = await (select(debts)
      ..where((d) => d.dueDate.isNotNull() &
          d.dueDate.isBiggerOrEqualValue(start) &
          d.dueDate.isSmallerThanValue(end))
    ).get();
    for (final d in dayDebts) {
      events.add({
        'id': d.id,
        'type': 'debt',
        'title': '${d.personName} - ৳${d.amount.toStringAsFixed(0)}',
        'personName': d.personName,
        'phone': d.phone,
        'amount': d.amount,
        'paidAmount': d.paidAmount,
        'debtType': d.type,
        'color': d.isSettled ? 'success' : 'error',
        'isSettled': d.isSettled,
        'dueDate': d.dueDate,
      });
    }

    // Birthdays on this day (convert to local timezone)
    final allBdays = await getAllBirthdays();
    for (final b in allBdays) {
      final localDob = b.dateOfBirth.toLocal();
      if (localDob.month == day.month && localDob.day == day.day) {
        events.add({
          'type': 'birthday',
          'title': "${b.personName}'s Birthday",
          'color': 'pink',
          'id': b.id,
          'phone': b.phone,
        });
      }
    }

    // Diary entries on this day
    final dayDiary = await (select(diaryEntries)
      ..where((d) => d.date.isBiggerOrEqualValue(start) & d.date.isSmallerThanValue(end))
    ).get();
    for (final de in dayDiary) {
      events.add({
        'id': de.id,
        'type': 'diary',
        'title': de.title != null && de.title!.isNotEmpty ? de.title! : 'Journal Entry',
        'content': de.content,
        'location': de.location,
        'weather': de.weather,
        'tags': de.tags,
        'wordCount': de.wordCount,
        'isLocked': de.isLocked,
        'color': 'purple',
        'createdAt': de.createdAt,
      });
    }

    return events;
  }

  // === DEBT QUERIES ===
  Stream<List<Debt>> watchAllDebts({bool? isSettled, String? type}) {
    final query = select(debts)..orderBy([
      (d) => OrderingTerm.asc(d.isSettled),
      (d) => OrderingTerm.desc(d.createdAt),
    ]);
    if (isSettled != null) {
      query.where((d) => d.isSettled.equals(isSettled));
    }
    if (type != null) {
      query.where((d) => d.type.equals(type));
    }
    return query.watch();
  }

  Future<List<Debt>> getAllDebts({bool? isSettled, String? type}) {
    final query = select(debts)..orderBy([
      (d) => OrderingTerm.asc(d.isSettled),
      (d) => OrderingTerm.desc(d.createdAt),
    ]);
    if (isSettled != null) {
      query.where((d) => d.isSettled.equals(isSettled));
    }
    if (type != null) {
      query.where((d) => d.type.equals(type));
    }
    return query.get();
  }

  Future<Debt?> getDebt(int id) =>
      (select(debts)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<int> addDebt(DebtsCompanion entry) => into(debts).insert(entry);

  Future<bool> updateDebt(DebtsCompanion entry) async {
    final existingDebt = await getDebt(entry.id.value);
    if (existingDebt == null) return false;

    final newLinkedToWallet = entry.linkedToWallet.present
        ? entry.linkedToWallet.value
        : existingDebt.linkedToWallet;
    final newType = entry.type.present ? entry.type.value : existingDebt.type;
    final newAmount = entry.amount.present ? entry.amount.value : existingDebt.amount;
    final newName = entry.personName.present ? entry.personName.value : existingDebt.personName;
    final now = DateTime.now();

    int? linkedTxId = existingDebt.linkedTransactionId;

    if (!existingDebt.linkedToWallet && newLinkedToWallet) {
      // Switched ON: Create new linked transaction in wallet
      final txType = newType == 'given' ? 'expense' : 'income';
      final txCategory = newType == 'given' ? 'Debt Given' : 'Debt Received';
      linkedTxId = await into(transactions).insert(TransactionsCompanion(
        amount: Value(newAmount),
        type: Value(txType),
        title: Value('Debt — $newName'),
        category: Value(txCategory),
        note: const Value('Auto-created from debt'),
        date: Value(now),
        createdAt: Value(now),
      ));
    } else if (existingDebt.linkedToWallet && !newLinkedToWallet) {
      // Switched OFF: Delete linked transaction
      if (linkedTxId != null) {
        await (delete(transactions)..where((t) => t.id.equals(linkedTxId!))).go();
        linkedTxId = null;
      }
    } else if (existingDebt.linkedToWallet && newLinkedToWallet) {
      // Remained ON: Update existing linked transaction if amount/type/name changed
      final txType = newType == 'given' ? 'expense' : 'income';
      final txCategory = newType == 'given' ? 'Debt Given' : 'Debt Received';
      if (linkedTxId != null) {
        await (update(transactions)..where((t) => t.id.equals(linkedTxId!))).write(
          TransactionsCompanion(
            amount: Value(newAmount),
            type: Value(txType),
            title: Value('Debt — $newName'),
            category: Value(txCategory),
          ),
        );
      } else {
        linkedTxId = await into(transactions).insert(TransactionsCompanion(
          amount: Value(newAmount),
          type: Value(txType),
          title: Value('Debt — $newName'),
          category: Value(txCategory),
          note: const Value('Auto-created from debt'),
          date: Value(now),
          createdAt: Value(now),
        ));
      }
    }

    final updatedCompanion = entry.copyWith(
      linkedToWallet: Value(newLinkedToWallet),
      linkedTransactionId: Value(linkedTxId),
    );

    return (update(debts)..where((d) => d.id.equals(entry.id.value)))
        .write(updatedCompanion)
        .then((rows) => rows > 0);
  }

  Future<int> deleteDebt(int id) async {
    // Clean up linked transactions before deleting
    final debt = await getDebt(id);
    if (debt != null) {
      if (debt.linkedTransactionId != null) {
        await (delete(transactions)..where((t) => t.id.equals(debt.linkedTransactionId!))).go();
      }
      if (debt.settlementTransactionId != null) {
        await (delete(transactions)..where((t) => t.id.equals(debt.settlementTransactionId!))).go();
      }
    }
    await (delete(debtPayments)..where((p) => p.debtId.equals(id))).go();
    return (delete(debts)..where((d) => d.id.equals(id))).go();
  }

  Future<void> settleDebt(int id) =>
      (update(debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(
          isSettled: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> unsettleDebt(int id) =>
      (update(debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(
          isSettled: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<List<Debt>> getOverdueDebts() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return (select(debts)
      ..where((d) => d.isSettled.equals(false) & d.dueDate.isNotNull() & d.dueDate.isSmallerThanValue(startOfToday))
      ..orderBy([(d) => OrderingTerm.asc(d.dueDate)])
    ).get();
  }

  // === WALLET-LINKED DEBT METHODS ===

  Future<int> addDebtWithWallet(DebtsCompanion entry) async {
    final debtId = await into(debts).insert(entry);
    final debt = await getDebt(debtId);
    if (debt == null) return debtId;

    final now = DateTime.now();
    final String txCategory;
    final String txType;
    if (debt.type == 'given') {
      txCategory = 'Debt Given';
      txType = 'expense';
    } else {
      txCategory = 'Debt Received';
      txType = 'income';
    }

    final txId = await into(transactions).insert(TransactionsCompanion(
      amount: Value(debt.amount),
      type: Value(txType),
      title: Value('Debt — ${debt.personName}'),
      category: Value(txCategory),
      note: const Value('Auto-created from debt'),
      date: Value(now),
      createdAt: Value(now),
    ));

    await (update(debts)..where((d) => d.id.equals(debtId))).write(
      DebtsCompanion(
        linkedTransactionId: Value(txId),
        updatedAt: Value(now),
      ),
    );

    return debtId;
  }

  Future<void> settleDebtWithWallet(int debtId) async {
    final debt = await getDebt(debtId);
    if (debt == null) return;

    final now = DateTime.now();
    final remainingAmount = debt.amount - debt.paidAmount;
    final String txCategory;
    final String txType;
    if (debt.type == 'given') {
      txCategory = 'Debt Settled';
      txType = 'income';
    } else {
      txCategory = 'Debt Repaid';
      txType = 'expense';
    }

    // Only create a settlement transaction if there is still an outstanding balance
    int? txId;
    if (remainingAmount > 0) {
      txId = await into(transactions).insert(TransactionsCompanion(
        amount: Value(remainingAmount),
        type: Value(txType),
        title: Value('Debt Settled — ${debt.personName}'),
        category: Value(txCategory),
        note: const Value('Auto-created on debt settlement'),
        date: Value(now),
        createdAt: Value(now),
      ));
    }

    await (update(debts)..where((d) => d.id.equals(debtId))).write(
      DebtsCompanion(
        isSettled: const Value(true),
        settlementTransactionId: Value(txId),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> unsettleDebtWithWallet(int debtId) async {
    final debt = await getDebt(debtId);
    if (debt == null) return;

    // Delete the settlement transaction
    if (debt.settlementTransactionId != null) {
      await (delete(transactions)..where((t) => t.id.equals(debt.settlementTransactionId!))).go();
    }

    await (update(debts)..where((d) => d.id.equals(debtId))).write(
      DebtsCompanion(
        isSettled: const Value(false),
        settlementTransactionId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Payments
  Stream<List<DebtPayment>> watchDebtPayments(int debtId) {
    return (select(debtPayments)
          ..where((p) => p.debtId.equals(debtId))
          ..orderBy([(p) => OrderingTerm.desc(p.paidAt)]))
        .watch();
  }

  Future<int> addDebtPayment(DebtPaymentsCompanion entry) async {
    final paymentId = await into(debtPayments).insert(entry);
    // Update paid amount on debt
    final payments = await (select(debtPayments)..where((p) => p.debtId.equals(entry.debtId.value))).get();
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final debt = await getDebt(entry.debtId.value);
    if (debt != null) {
      final isFullyPaid = totalPaid >= debt.amount;
      await (update(debts)..where((d) => d.id.equals(entry.debtId.value))).write(
        DebtsCompanion(
          paidAmount: Value(totalPaid),
          isSettled: Value(isFullyPaid),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // If debt is linked to wallet, create a corresponding transaction
      if (debt.linkedToWallet) {
        final now = DateTime.now();
        final txType = debt.type == 'given' ? 'income' : 'expense';
        final txCategory = debt.type == 'given' ? 'Debt Payment Received' : 'Debt Payment Made';
        final txId = await into(transactions).insert(TransactionsCompanion(
          amount: Value(entry.amount.value),
          type: Value(txType),
          title: Value('Debt Payment — ${debt.personName}'),
          category: Value(txCategory),
          note: Value(entry.note.value),
          date: Value(entry.paidAt.value),
          createdAt: Value(now),
        ));
        // Link the transaction back to this payment
        await (update(debtPayments)..where((p) => p.id.equals(paymentId))).write(
          DebtPaymentsCompanion(linkedTransactionId: Value(txId)),
        );
      }
    }
    return paymentId;
  }

  Future<int> deleteDebtPayment(int paymentId, int debtId) async {
    // Delete linked wallet transaction if present
    final payment = await (select(debtPayments)..where((p) => p.id.equals(paymentId))).getSingleOrNull();
    if (payment?.linkedTransactionId != null) {
      await (delete(transactions)..where((t) => t.id.equals(payment!.linkedTransactionId!))).go();
    }
    final result = await (delete(debtPayments)..where((p) => p.id.equals(paymentId))).go();
    // Recalculate paid amount
    final payments = await (select(debtPayments)..where((p) => p.debtId.equals(debtId))).get();
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final debt = await getDebt(debtId);
    if (debt != null) {
      await (update(debts)..where((d) => d.id.equals(debtId))).write(
        DebtsCompanion(
          paidAmount: Value(totalPaid),
          isSettled: Value(totalPaid >= debt.amount),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    return result;
  }

  // === BIRTHDAY QUERIES ===
  Stream<List<Birthday>> watchAllBirthdays() {
    return (select(birthdays)
          ..orderBy([
            (b) => OrderingTerm.asc(b.dateOfBirth),
            (b) => OrderingTerm.asc(b.personName),
          ]))
        .watch();
  }

  Future<List<Birthday>> getAllBirthdays() {
    return (select(birthdays)
          ..orderBy([
            (b) => OrderingTerm.asc(b.dateOfBirth),
            (b) => OrderingTerm.asc(b.personName),
          ]))
        .get();
  }

  Future<int> addBirthday(BirthdaysCompanion entry) => into(birthdays).insert(entry);

  Future<bool> updateBirthday(BirthdaysCompanion entry) =>
      (update(birthdays)..where((b) => b.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteBirthday(int id) => (delete(birthdays)..where((b) => b.id.equals(id))).go();

  // === CONTACT QUERIES ===
  Stream<List<ContactEntry>> watchAllContactEntries({String? search}) {
    final query = select(contactEntries)
      ..orderBy([
        (c) => OrderingTerm.asc(c.displayName),
        (c) => OrderingTerm.desc(c.updatedAt),
      ]);

    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      query.where((c) => c.displayName.like(q) | c.phone.like(q));
    }

    return query.watch();
  }

  Future<List<ContactEntry>> getAllContactEntries() {
    return (select(contactEntries)
          ..orderBy([
            (c) => OrderingTerm.asc(c.displayName),
            (c) => OrderingTerm.desc(c.updatedAt),
          ]))
        .get();
  }

  Future<ContactEntry?> getContactByExternalId(String externalId) {
    return (select(contactEntries)..where((c) => c.externalContactId.equals(externalId))).getSingleOrNull();
  }

  Future<ContactEntry?> getContactByNormalizedPhone(String normalizedPhone) {
    return (select(contactEntries)..where((c) => c.normalizedPhone.equals(normalizedPhone))).getSingleOrNull();
  }

  Future<int> addContactEntry(ContactEntriesCompanion entry) => into(contactEntries).insert(entry);

  Future<bool> updateContactEntry(ContactEntriesCompanion entry) =>
      (update(contactEntries)..where((c) => c.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteContactEntry(int id) => (delete(contactEntries)..where((c) => c.id.equals(id))).go();

  // === DIARY / JOURNAL QUERIES ===
  Stream<List<DiaryEntry>> watchAllDiaryEntries({String? tag, bool? isFavorite, String? search}) {
    final query = select(diaryEntries)..orderBy([(d) => OrderingTerm.desc(d.date), (d) => OrderingTerm.desc(d.createdAt)]);
    if (isFavorite != null) {
      query.where((d) => d.isFavorite.equals(isFavorite));
    }
    return query.watch().map((list) {
      var result = list;
      if (tag != null && tag.isNotEmpty) {
        result = result.where((d) => d.tags != null && d.tags!.contains(tag)).toList();
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        result = result.where((d) =>
          (d.title?.toLowerCase().contains(q) ?? false) ||
          d.content.toLowerCase().contains(q) ||
          (d.location?.toLowerCase().contains(q) ?? false) ||
          (d.tags?.toLowerCase().contains(q) ?? false)
        ).toList();
      }
      return result;
    });
  }

  Future<List<DiaryEntry>> getAllDiaryEntries() =>
      (select(diaryEntries)..orderBy([(d) => OrderingTerm.desc(d.date), (d) => OrderingTerm.desc(d.createdAt)])).get();

  Future<DiaryEntry?> getDiaryEntryForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(diaryEntries)
      ..where((d) => d.date.isBiggerOrEqualValue(start) & d.date.isSmallerThanValue(end))
      ..limit(1)
    ).getSingleOrNull();
  }

  Future<List<DiaryEntry>> getOnThisDayEntries(DateTime targetDate) async {
    final all = await getAllDiaryEntries();
    return all.where((e) {
      final eDate = e.date;
      return eDate.month == targetDate.month &&
          eDate.day == targetDate.day &&
          eDate.year != targetDate.year;
    }).toList();
  }

  Future<int> addDiaryEntry(DiaryEntriesCompanion entry) => into(diaryEntries).insert(entry);

  Future<bool> updateDiaryEntry(DiaryEntriesCompanion entry) =>
      (update(diaryEntries)..where((d) => d.id.equals(entry.id.value))).write(entry).then((rows) => rows > 0);

  Future<int> deleteDiaryEntry(int id) => (delete(diaryEntries)..where((d) => d.id.equals(id))).go();

  Future<void> toggleDiaryFavorite(int id, bool favorite) =>
      (update(diaryEntries)..where((d) => d.id.equals(id))).write(DiaryEntriesCompanion(isFavorite: Value(favorite)));

  Future<void> toggleDiaryLock(int id, bool locked) =>
      (update(diaryEntries)..where((d) => d.id.equals(id))).write(DiaryEntriesCompanion(isLocked: Value(locked)));

  Future<int> getDiaryStreak() async {
    final all = await getAllDiaryEntries();
    if (all.isEmpty) return 0;

    final dates = all.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    if (!dates.contains(todayDate) && !dates.contains(yesterdayDate)) {
      return 0;
    }

    int streak = 0;
    DateTime checkDate = dates.contains(todayDate) ? todayDate : yesterdayDate;

    for (final d in dates) {
      if (d == checkDate) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (d.isBefore(checkDate)) {
        break;
      }
    }

    return streak;
  }

  Future<Map<String, dynamic>> getDiaryStats() async {
    final all = await getAllDiaryEntries();
    int totalWords = 0;
    for (final e in all) {
      totalWords += e.wordCount;
    }
    final streak = await getDiaryStreak();
    return {
      'totalEntries': all.length,
      'totalWords': totalWords,
      'streak': streak,
    };
  }
}
