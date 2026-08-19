import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../providers/notification_preferences_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/todo_provider.dart';
import 'todo_timer_dialog.dart';
import 'package:flutter/services.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filter = ref.watch(todoFilterProvider);
    final searchQuery = ref.watch(todoSearchProvider);
    final todosAsync = ref.watch(filteredTodosProvider);
    final todoCountsAsync = ref.watch(todoCountsProvider);
    final counts = todoCountsAsync.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tasks',
                        style: AppTypography.headingLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        counts != null
                            ? '${counts.today} due today • ${counts.completed} completed'
                            : 'Organize your focus & commitments',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Smart Filter Segment Bar ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _SmartFilterTab(
                    label: 'Today',
                    count: counts?.today ?? 0,
                    icon: Icons.wb_sunny_outlined,
                    isActive: filter == TodoFilter.today,
                    activeColor: AppColors.primary,
                    onTap: () => ref.read(todoFilterProvider.notifier).state = TodoFilter.today,
                  ),
                  const SizedBox(width: 8),
                  _SmartFilterTab(
                    label: 'Upcoming',
                    count: counts?.upcoming ?? 0,
                    icon: Icons.calendar_today_outlined,
                    isActive: filter == TodoFilter.upcoming,
                    activeColor: AppColors.info,
                    onTap: () => ref.read(todoFilterProvider.notifier).state = TodoFilter.upcoming,
                  ),
                  const SizedBox(width: 8),
                  _SmartFilterTab(
                    label: 'Overdue',
                    count: counts?.overdue ?? 0,
                    icon: Icons.warning_amber_rounded,
                    isActive: filter == TodoFilter.overdue,
                    activeColor: AppColors.error,
                    isAlert: (counts?.overdue ?? 0) > 0,
                    onTap: () => ref.read(todoFilterProvider.notifier).state = TodoFilter.overdue,
                  ),
                  const SizedBox(width: 8),
                  _SmartFilterTab(
                    label: 'All',
                    count: counts?.all ?? 0,
                    icon: Icons.playlist_add_check_rounded,
                    isActive: filter == TodoFilter.all,
                    activeColor: AppColors.purple,
                    onTap: () => ref.read(todoFilterProvider.notifier).state = TodoFilter.all,
                  ),
                  const SizedBox(width: 8),
                  _SmartFilterTab(
                    label: 'Done',
                    count: counts?.completed ?? 0,
                    icon: Icons.check_circle_outline_rounded,
                    isActive: filter == TodoFilter.completed,
                    activeColor: AppColors.success,
                    onTap: () => ref.read(todoFilterProvider.notifier).state = TodoFilter.completed,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                onChanged: (val) => ref.read(todoSearchProvider.notifier).state = val,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search tasks, tags, descriptions...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            ref.read(todoSearchProvider.notifier).state = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  isDense: true,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Todo List ──
            Expanded(
              child: todosAsync.when(
                data: (allTodos) {
                  final hidden = ref.watch(hiddenItemsProvider);
                  final todos = allTodos.where((t) => !hidden.contains('todo_${t.id}')).toList();

                  if (todos.isEmpty) {
                    return _EmptyState(filter: filter, searchQuery: searchQuery);
                  }

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    physics: const BouncingScrollPhysics(),
                    itemCount: todos.length,
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) {
                      if (searchQuery.isNotEmpty) return;
                      final item = todos[oldIndex];
                      final priority = item.priority;

                      final firstIndex = todos.indexWhere((t) => t.priority == priority);
                      final lastIndex = todos.lastIndexWhere((t) => t.priority == priority);

                      if (newIndex < firstIndex || newIndex > lastIndex) {
                        return;
                      }

                      final updated = List<Todo>.from(todos);
                      final removed = updated.removeAt(oldIndex);
                      updated.insert(newIndex, removed);

                      final db = ref.read(databaseProvider);
                      db.updateTodoSortOrders(
                        updated.asMap().entries.map((e) => (
                          id: e.value.id,
                          sortOrder: e.key,
                        )).toList(),
                      );
                    },
                    itemBuilder: (context, i) {
                      final todo = todos[i];
                      return _TodoCard(
                        key: ValueKey('todo_${todo.id}'),
                        todo: todo,
                        onToggle: () async {
                          HapticFeedback.mediumImpact();
                          final willComplete = !todo.isCompleted;
                          if (willComplete && todo.remindAt != null) {
                            ref.read(notificationServiceProvider).cancelReminder(todo.id);
                          } else if (!willComplete &&
                              todo.remindAt != null &&
                              todo.remindAt!.isAfter(DateTime.now())) {
                            ref.read(notificationServiceProvider).scheduleTodoReminder(
                              id: todo.id,
                              title: 'Todo Reminder',
                              body: todo.title,
                              scheduledDate: todo.remindAt!,
                              priority: todo.priority,
                              dueDate: todo.dueDate,
                              alertMode: ref.read(notificationPreferencesProvider).alertMode,
                            );
                          }
                          await ref.read(databaseProvider).completeTodoWithRecurrence(todo.id, willComplete);
                          ref.read(activityLogProvider.notifier).log(
                            type: 'update',
                            entityType: 'task',
                            entityTitle: todo.title,
                          );
                          if (willComplete && todo.isRecurring && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Task completed! Next occurrence scheduled.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        onDelete: () {
                          final itemKey = 'todo_${todo.id}';
                          final db = ref.read(databaseProvider);
                          final hiddenNotifier = ref.read(hiddenItemsProvider.notifier);
                          final notif = ref.read(notificationServiceProvider);
                          final messenger = ScaffoldMessenger.of(context);

                          hiddenNotifier.update((state) => {...state, itemKey});
                          messenger.clearSnackBars();

                          bool undone = false;
                          final timer = Timer(const Duration(seconds: 3), () async {
                            if (!undone) {
                              await notif.cancelReminder(todo.id);
                              await db.deleteTodo(todo.id);
                              hiddenNotifier.update((state) {
                                final s = {...state};
                                s.remove(itemKey);
                                return s;
                              });
                              ref.read(activityLogProvider.notifier).log(
                                type: 'delete',
                                entityType: 'task',
                                entityTitle: todo.title,
                              );
                            }
                            messenger.hideCurrentSnackBar();
                          });

                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Task deleted'),
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: 'UNDO',
                                onPressed: () {
                                  undone = true;
                                  timer.cancel();
                                  messenger.hideCurrentSnackBar();
                                  hiddenNotifier.update((state) {
                                    final s = {...state};
                                    s.remove(itemKey);
                                    return s;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        onEdit: () => _showAddEditSheet(context, ref, todo: todo),
                        reorderIndex: i,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                        const SizedBox(height: 12),
                        const Text('Could not load tasks'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'todo_fab',
        onPressed: () => _showAddEditSheet(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text(
          'New Task',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, WidgetRef ref, {Todo? todo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditTodoSheet(todo: todo),
    );
  }
}

// ────────────────── MODERN TODO CARD ──────────────────

class _TodoCard extends ConsumerWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final int reorderIndex;

  const _TodoCard({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.reorderIndex,
  });

  Color _priorityColor() {
    switch (todo.priority) {
      case 3:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 1:
        return AppColors.info;
      default:
        return Colors.transparent;
    }
  }

  String _priorityLabel() {
    switch (todo.priority) {
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
        return 'Low';
      default:
        return 'None';
    }
  }

  String _formatRecurrence(String pattern) {
    switch (pattern) {
      case 'daily':
        return 'Daily';
      case 'weekdays':
        return 'Weekdays';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return 'Recurring';
    }
  }

  List<String> _parseTags(String? tagsJson) {
    if (tagsJson == null || tagsJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is List) return decoded.cast<String>();
      return [];
    } catch (_) {
      return [];
    }
  }

  void _showSubtasksSheet(BuildContext context, Todo todo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubTasksQuickSheet(todo: todo),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isOverdue = todo.dueDate != null &&
        todo.dueDate!.isBefore(DateTime.now()) &&
        !todo.isCompleted;

    final subTasksAsync = ref.watch(subTasksProvider(todo.id));
    final subTasks = subTasksAsync.valueOrNull ?? [];
    final totalFocusSeconds = ref.watch(totalFocusTimeProvider(todo.id));
    final todoTags = _parseTags(todo.tags);

    final completedSubTasks = subTasks.where((st) => st.isCompleted == true).length;
    final totalSubTasks = subTasks.length;
    final subtaskProgress = totalSubTasks > 0 ? (completedSubTasks / totalSubTasks) : 0.0;

    final pColor = _priorityColor();

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete task?'),
            content: Text('Delete "${todo.title}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: todo.isCompleted
                ? AppColors.success.withValues(alpha: 0.25)
                : (todo.priority > 0
                    ? pColor.withValues(alpha: isDark ? 0.35 : 0.25)
                    : theme.colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.08)),
            width: todo.priority > 0 && !todo.isCompleted ? 1.3 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit, // Direct Tap to Edit Task
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Checkbox + Title & Priority Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1-Tap Round-Squircle Checkbox
                      GestureDetector(
                        onTap: onToggle,
                        child: Container(
                          margin: const EdgeInsets.only(right: 12, top: 1),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: todo.isCompleted ? AppColors.success : Colors.transparent,
                            border: Border.all(
                              color: todo.isCompleted ? AppColors.success : theme.colorScheme.outline,
                              width: 1.8,
                            ),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: todo.isCompleted
                              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                              : null,
                        ),
                      ),

                      // Title + Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              todo.title,
                              style: AppTypography.bodyMedium.copyWith(
                                color: todo.isCompleted
                                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (todo.description != null && todo.description!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                todo.description!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Priority Flag Badge
                      if (todo.priority > 0 && !todo.isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: pColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _priorityLabel(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: pColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // ── Metadata Badges Strip ──
                  if (todo.dueDate != null ||
                      todo.remindAt != null ||
                      todo.isRecurring ||
                      todoTags.isNotEmpty ||
                      totalSubTasks > 0 ||
                      totalFocusSeconds > 0) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Due Date Badge
                        if (todo.dueDate != null)
                          _MetaBadge(
                            icon: isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today_rounded,
                            label: DateFormat('MMM d, h:mm a').format(todo.dueDate!),
                            color: isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                            isAlert: isOverdue,
                          ),

                        // Reminder Badge
                        if (todo.remindAt != null)
                          _MetaBadge(
                            icon: Icons.notifications_active_outlined,
                            label: DateFormat('MMM d, h:mm a').format(todo.remindAt!),
                            color: AppColors.warning,
                          ),

                        // Subtasks Pill (Tap to open Quick Subtasks Sheet)
                        if (totalSubTasks > 0)
                          _MetaBadge(
                            icon: Icons.checklist_rounded,
                            label: '$completedSubTasks/$totalSubTasks subtasks',
                            color: subtaskProgress == 1.0 ? AppColors.success : AppColors.primary,
                            onTap: () => _showSubtasksSheet(context, todo),
                          ),

                        // Recurrence Badge
                        if (todo.isRecurring && todo.recurringPattern != null)
                          _MetaBadge(
                            icon: Icons.repeat_rounded,
                            label: _formatRecurrence(todo.recurringPattern!),
                            color: AppColors.purple,
                          ),

                        // Focus Time Badge
                        if (totalFocusSeconds > 0)
                          _MetaBadge(
                            icon: Icons.timer_outlined,
                            label: '${(totalFocusSeconds / 60).ceil()}m focus',
                            color: AppColors.warning,
                          ),

                        // Tags Badges
                        ...todoTags.map(
                          (tag) => _MetaBadge(
                            icon: Icons.tag_rounded,
                            label: tag,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // ── Card Action Row ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Focus Timer Launcher
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        color: AppColors.warning,
                        tooltip: 'Start Focus Session',
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => TodoTimerDialog(todo: todo),
                          );
                        },
                      ),
                      // Edit Action
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        color: theme.colorScheme.primary,
                        tooltip: 'Edit Task',
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: onEdit,
                      ),
                      // Delete Action
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: theme.colorScheme.error,
                        tooltip: 'Delete Task',
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete task?'),
                              content: Text('Delete "${todo.title}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    onDelete();
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Drag Reorder Handle
                      ReorderableDragStartListener(
                        index: reorderIndex,
                        child: IconButton(
                          icon: const Icon(Icons.drag_indicator_rounded),
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          tooltip: 'Drag to reorder',
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isAlert;
  final VoidCallback? onTap;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.isAlert = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isAlert ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: isAlert ? 0.4 : 0.18),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: color),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: badge,
        ),
      );
    }
    return badge;
  }
}

// ────────────────── QUICK SUBTASKS MODAL SHEET ──────────────────

class SubTasksQuickSheet extends ConsumerStatefulWidget {
  final Todo todo;

  const SubTasksQuickSheet({super.key, required this.todo});

  @override
  ConsumerState<SubTasksQuickSheet> createState() => _SubTasksQuickSheetState();
}

class _SubTasksQuickSheetState extends ConsumerState<SubTasksQuickSheet> {
  final _newSubTaskController = TextEditingController();

  @override
  void dispose() {
    _newSubTaskController.dispose();
    super.dispose();
  }

  void _addNewSubTask(List<SubTask> currentSubTasks) async {
    final text = _newSubTaskController.text.trim();
    if (text.isEmpty) return;

    final db = ref.read(databaseProvider);
    await db.addSubTask(
      SubTasksCompanion(
        todoId: Value(widget.todo.id),
        title: Value(text),
        isCompleted: const Value(false),
        sortOrder: Value(currentSubTasks.length),
        createdAt: Value(DateTime.now()),
      ),
    );
    _newSubTaskController.clear();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subTasksAsync = ref.watch(subTasksProvider(widget.todo.id));

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 16,
          left: 20,
          right: 20,
        ),
        child: subTasksAsync.when(
          data: (subTasks) {
            final completedCount = subTasks.where((s) => s.isCompleted).length;
            final totalCount = subTasks.length;
            final progress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;
            final isAllDone = totalCount > 0 && completedCount == totalCount;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Bar ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.checklist_rounded, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subtasks Checklist',
                            style: AppTypography.headingMedium.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.todo.title,
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Progress Bar Card ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAllDone
                        ? AppColors.success.withValues(alpha: isDark ? 0.18 : 0.08)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isAllDone
                          ? AppColors.success.withValues(alpha: 0.35)
                          : theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAllDone
                                ? 'All $totalCount subtasks completed!'
                                : '$completedCount of $totalCount completed',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isAllDone ? AppColors.success : theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isAllDone ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAllDone ? AppColors.success : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Subtasks List ──
                if (subTasks.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No subtasks yet. Add one below!',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: subTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final st = subTasks[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: st.isCompleted
                                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: st.isCompleted
                                  ? AppColors.success.withValues(alpha: 0.2)
                                  : theme.colorScheme.outline.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              // 1-Tap Subtask Checkbox
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(databaseProvider).toggleSubTask(st.id, !st.isCompleted);
                                },
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: st.isCompleted ? AppColors.success : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: st.isCompleted ? AppColors.success : theme.colorScheme.outline,
                                      width: 1.6,
                                    ),
                                  ),
                                  child: st.isCompleted
                                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Subtask Title
                              Expanded(
                                child: Text(
                                  st.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: st.isCompleted
                                        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                                        : theme.colorScheme.onSurface,
                                    decoration: st.isCompleted ? TextDecoration.lineThrough : null,
                                    fontWeight: st.isCompleted ? FontWeight.normal : FontWeight.w500,
                                  ),
                                ),
                              ),

                              // Delete Subtask Button
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(databaseProvider).deleteSubTask(st.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Quick Add Subtask Input ──
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubTaskController,
                        style: AppTypography.bodyMedium.copyWith(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Add a new subtask...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addNewSubTask(subTasks),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _addNewSubTask(subTasks),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (_, __) => const Center(child: Text('Could not load subtasks')),
        ),
      ),
    );
  }
}

// ────────────────── ADD / EDIT TASK MODAL SHEET ──────────────────

class AddEditTodoSheet extends ConsumerStatefulWidget {
  final Todo? todo;
  final DateTime? initialDueDate;

  const AddEditTodoSheet({super.key, this.todo, this.initialDueDate});

  @override
  ConsumerState<AddEditTodoSheet> createState() => _AddEditTodoSheetState();
}

class _AddEditTodoSheetState extends ConsumerState<AddEditTodoSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();

  DateTime? _dueDate;
  DateTime? _remindAt;
  int _priority = 0; // 0=None, 1=Low, 2=Medium, 3=High
  String? _category;
  List<String> _tags = [];
  bool _isRecurring = false;
  String? _recurringPattern = 'daily';
  final List<Map<String, dynamic>> _subTasks = [];

  @override
  void initState() {
    super.initState();
    if (widget.todo != null) {
      _titleController.text = widget.todo!.title;
      _descController.text = widget.todo!.description ?? '';
      _dueDate = widget.todo!.dueDate;
      _remindAt = widget.todo!.remindAt;
      _priority = widget.todo!.priority;
      _category = widget.todo!.category;
      _tags = _parseTagsFromJson(widget.todo!.tags);
      _isRecurring = widget.todo!.isRecurring;
      _recurringPattern = widget.todo!.recurringPattern ?? 'daily';
      _loadSubTasks();
    } else if (widget.initialDueDate != null) {
      _dueDate = widget.initialDueDate;
    }
  }

  List<String> _parseTagsFromJson(String? tagsJson) {
    if (tagsJson == null || tagsJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is List) return decoded.cast<String>();
      return [];
    } catch (_) {
      return [];
    }
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) return;
    setState(() => _tags.add(trimmed));
    _tagController.clear();
  }

  void _removeTag(int index) {
    setState(() => _tags.removeAt(index));
  }

  Future<void> _loadSubTasks() async {
    final db = ref.read(databaseProvider);
    final existing = await db.watchSubTasks(widget.todo!.id).first;
    if (mounted) {
      setState(() {
        for (var st in existing) {
          _subTasks.add({
            'title': st.title,
            'isCompleted': st.isCompleted,
            'id': st.id,
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_titleController.text.trim().isEmpty) return;

    if (_tagController.text.trim().isNotEmpty) {
      _addTag(_tagController.text);
    }

    final db = ref.read(databaseProvider);
    final companion = TodosCompanion(
      title: Value(_titleController.text.trim()),
      description: Value(_descController.text.trim()),
      dueDate: Value(_dueDate),
      remindAt: Value(_remindAt),
      priority: Value(_priority),
      category: Value(_category),
      tags: Value(jsonEncode(_tags)),
      isRecurring: Value(_isRecurring),
      recurringPattern: Value(_isRecurring ? (_recurringPattern ?? 'daily') : null),
    );

    int todoId;
    if (widget.todo == null) {
      todoId = await db.addTodo(
        companion.copyWith(
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      ref.read(activityLogProvider.notifier).log(
        type: 'add',
        entityType: 'task',
        entityTitle: _titleController.text.trim(),
      );
    } else {
      todoId = widget.todo!.id;
      await db.updateTodo(
        companion.copyWith(id: Value(todoId), updatedAt: Value(DateTime.now())),
      );
      ref.read(activityLogProvider.notifier).log(
        type: 'update',
        entityType: 'task',
        entityTitle: _titleController.text.trim(),
      );

      final currentSubTasks = await db.watchSubTasks(todoId).first;
      for (var st in currentSubTasks) {
        await db.deleteSubTask(st.id);
      }
    }

    for (int i = 0; i < _subTasks.length; i++) {
      if (_subTasks[i]['title'].trim().isNotEmpty) {
        await db.addSubTask(
          SubTasksCompanion(
            todoId: Value(todoId),
            title: Value(_subTasks[i]['title']),
            isCompleted: Value(_subTasks[i]['isCompleted'] ?? false),
            sortOrder: Value(i),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    }

    if (_remindAt != null) {
      ref.read(notificationServiceProvider).scheduleTodoReminder(
        id: todoId,
        title: 'Todo Reminder',
        body: _titleController.text.trim(),
        scheduledDate: _remindAt!,
        priority: _priority,
        dueDate: _dueDate,
        alertMode: ref.read(notificationPreferencesProvider).alertMode,
      );
    } else {
      ref.read(notificationServiceProvider).cancelReminder(todoId);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _addSubTask() {
    setState(() {
      _subTasks.add({'title': '', 'isCompleted': false});
    });
  }

  void _updateSubTask(int index, String title, bool isCompleted) {
    setState(() {
      _subTasks[index] = {'title': title, 'isCompleted': isCompleted};
    });
  }

  void _removeSubTask(int index) {
    setState(() {
      _subTasks.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 16,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row with Close & Save Buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.todo == null ? 'New Task' : 'Edit Task',
                    style: AppTypography.headingMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title Input Field
              TextField(
                controller: _titleController,
                autofocus: widget.todo == null,
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),

              // Description Input Field
              TextField(
                controller: _descController,
                style: AppTypography.bodyMedium,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Add description or notes...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                    fontSize: 13.5,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),

              // ── Due Date & Reminder Quick Tiles ──
              Row(
                children: [
                  // Due Date Selector
                  Expanded(
                    child: _DateTile(
                      icon: Icons.calendar_today_rounded,
                      color: AppColors.primary,
                      title: _dueDate == null ? 'Set Due Date' : DateFormat('MMM d, h:mm a').format(_dueDate!),
                      isSelected: _dueDate != null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() {
                              _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                      onClear: _dueDate != null ? () => setState(() => _dueDate = null) : null,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Reminder Selector
                  Expanded(
                    child: _DateTile(
                      icon: Icons.notifications_active_outlined,
                      color: AppColors.warning,
                      title: _remindAt == null ? 'Set Reminder' : DateFormat('MMM d, h:mm a').format(_remindAt!),
                      isSelected: _remindAt != null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _remindAt ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() {
                              _remindAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                      onClear: _remindAt != null ? () => setState(() => _remindAt = null) : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Priority Selector ──
              Text(
                'Priority Level',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PriorityChip(
                    label: 'None',
                    color: theme.colorScheme.onSurfaceVariant,
                    isActive: _priority == 0,
                    onTap: () => setState(() => _priority = 0),
                  ),
                  const SizedBox(width: 6),
                  _PriorityChip(
                    label: 'Low',
                    color: AppColors.info,
                    isActive: _priority == 1,
                    onTap: () => setState(() => _priority = 1),
                  ),
                  const SizedBox(width: 6),
                  _PriorityChip(
                    label: 'Medium',
                    color: AppColors.warning,
                    isActive: _priority == 2,
                    onTap: () => setState(() => _priority = 2),
                  ),
                  const SizedBox(width: 6),
                  _PriorityChip(
                    label: 'High',
                    color: AppColors.error,
                    isActive: _priority == 3,
                    onTap: () => setState(() => _priority = 3),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Recurrence Repeater ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isRecurring
                        ? AppColors.purple.withValues(alpha: 0.4)
                        : theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 18,
                              color: _isRecurring ? AppColors.purple : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Repeat Task',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isRecurring,
                          onChanged: (v) {
                            setState(() {
                              _isRecurring = v;
                              if (v && _recurringPattern == null) {
                                _recurringPattern = 'daily';
                              }
                            });
                          },
                          activeThumbColor: AppColors.purple,
                        ),
                      ],
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _RecurrenceChip(
                            label: 'Daily',
                            isActive: _recurringPattern == 'daily',
                            onTap: () => setState(() => _recurringPattern = 'daily'),
                          ),
                          const SizedBox(width: 6),
                          _RecurrenceChip(
                            label: 'Weekdays',
                            isActive: _recurringPattern == 'weekdays',
                            onTap: () => setState(() => _recurringPattern = 'weekdays'),
                          ),
                          const SizedBox(width: 6),
                          _RecurrenceChip(
                            label: 'Weekly',
                            isActive: _recurringPattern == 'weekly',
                            onTap: () => setState(() => _recurringPattern = 'weekly'),
                          ),
                          const SizedBox(width: 6),
                          _RecurrenceChip(
                            label: 'Monthly',
                            isActive: _recurringPattern == 'monthly',
                            onTap: () => setState(() => _recurringPattern = 'monthly'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Subtasks Checklist ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtasks',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSubTask,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (_subTasks.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...List.generate(_subTasks.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        Icon(Icons.drag_indicator_rounded, size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextFormField(
                            initialValue: _subTasks[index]['title'],
                            onChanged: (val) => _updateSubTask(index, val, _subTasks[index]['isCompleted'] ?? false),
                            style: AppTypography.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'Subtask item...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          color: AppColors.error,
                          onPressed: () => _removeSubTask(index),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 14),

              // ── Tags Section ──
              Text(
                'Tags',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              if (_tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_tags.length, (index) {
                    return Chip(
                      label: Text(_tags[index], style: const TextStyle(fontSize: 11.5)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () => _removeTag(index),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Add a tag...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                        ),
                      ),
                      onSubmitted: _addTag,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: () => _addTag(_tagController.text),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),

              // Autocomplete suggestions
              Consumer(
                builder: (context, ref, _) {
                  final usedTagsAsync = ref.watch(usedTagsProvider);
                  return usedTagsAsync.when(
                    data: (usedTags) {
                      final suggestions = usedTags.where((t) => !_tags.contains(t)).take(4).toList();
                      if (suggestions.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Wrap(
                          spacing: 6,
                          children: suggestions.map((tag) {
                            return ActionChip(
                              label: Text(tag, style: const TextStyle(fontSize: 11, color: AppColors.teal)),
                              avatar: const Icon(Icons.add_rounded, size: 12, color: AppColors.teal),
                              onPressed: () => _addTag(tag),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppColors.teal.withValues(alpha: 0.08),
                              side: BorderSide(color: AppColors.teal.withValues(alpha: 0.2)),
                            );
                          }).toList(),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.18 : 0.08)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isSelected ? color : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: isActive ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartFilterTab extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final bool isAlert;
  final VoidCallback onTap;

  const _SmartFilterTab({
    required this.label,
    required this.count,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    this.isAlert = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? activeColor.withValues(alpha: 0.2) : activeColor.withValues(alpha: 0.12))
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? activeColor
                : (isAlert ? AppColors.error.withValues(alpha: 0.5) : theme.colorScheme.outline.withValues(alpha: 0.15)),
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? activeColor : (isAlert ? AppColors.error : theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? activeColor : (isAlert ? AppColors.error : theme.colorScheme.onSurfaceVariant),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (count > 0 || isAlert) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isAlert
                      ? AppColors.error.withValues(alpha: 0.15)
                      : (isActive ? activeColor.withValues(alpha: 0.2) : theme.colorScheme.outline.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAlert ? AppColors.error : (isActive ? activeColor : theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecurrenceChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _RecurrenceChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.purple.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.purple : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.purple : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TodoFilter filter;
  final String searchQuery;

  const _EmptyState({required this.filter, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = searchQuery.isNotEmpty;

    if (isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(height: 14),
            Text(
              'No matching tasks',
              style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching for another keyword or tag',
              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    String title = 'All caught up!';
    String subtitle = 'Tap New Task below to plan your day';
    IconData icon = Icons.task_alt_rounded;
    Color color = AppColors.primary;

    switch (filter) {
      case TodoFilter.today:
        title = 'No tasks due today';
        subtitle = 'Enjoy your day or tap New Task to schedule ahead';
        icon = Icons.wb_sunny_outlined;
        color = AppColors.orange;
        break;
      case TodoFilter.upcoming:
        title = 'No upcoming tasks';
        subtitle = 'No tasks scheduled for the next 7 days';
        icon = Icons.calendar_today_outlined;
        color = AppColors.info;
        break;
      case TodoFilter.overdue:
        title = 'No overdue tasks';
        subtitle = 'Great job! Everything is up to date';
        icon = Icons.check_circle_outline_rounded;
        color = AppColors.success;
        break;
      case TodoFilter.all:
        title = 'No pending tasks';
        subtitle = 'Tap New Task to create a new task';
        icon = Icons.playlist_add_check_rounded;
        color = AppColors.purple;
        break;
      case TodoFilter.completed:
        title = 'No completed tasks';
        subtitle = 'Finished tasks will be neatly archived here';
        icon = Icons.history_rounded;
        color = AppColors.success;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
