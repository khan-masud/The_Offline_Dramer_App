import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
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
    final filter = ref.watch(todoFilterProvider);
    final todosAsync = ref.watch(todosProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tasks',
                      style: AppTypography.headingLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Stats chip
                  todosAsync.when(
                    data: (todos) {
                      final pending = todos.where((t) => !t.isCompleted).length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusFull,
                          ),
                        ),
                        child: Text(
                          '$pending pending',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children:
                    TodoFilter.values.map((f) {
                      final isActive = filter == f;
                      final label =
                          f == TodoFilter.all
                              ? 'All'
                              : f == TodoFilter.pending
                              ? 'Pending'
                              : 'Done';
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap:
                              () =>
                                  ref.read(todoFilterProvider.notifier).state =
                                      f,
                          child: AnimatedContainer(
                            duration: 200.ms,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isActive
                                      ? AppColors.primary
                                      : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusFull,
                              ),
                              border: Border.all(
                                color:
                                    isActive
                                        ? AppColors.primary
                                        : theme.colorScheme.outline,
                              ),
                            ),
                            child: Text(
                              label,
                              style: AppTypography.labelMedium.copyWith(
                                color:
                                    isActive
                                        ? Colors.white
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Todo list
            Expanded(
              child: todosAsync.when(
                data: (allTodos) {
                  final hidden = ref.watch(hiddenItemsProvider);
                  final todos = allTodos.where((t) => !hidden.contains('todo_${t.id}')).toList();
                  
                  if (todos.isEmpty) {
                    return _EmptyState(filter: filter);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: todos.length,
                    itemBuilder: (context, i) {
                      final todo = todos[i];
                      return _TodoCard(
                        todo: todo,
                        onToggle: () {
                          HapticFeedback.lightImpact();
                          if (!todo.isCompleted && todo.remindAt != null) {
                            ref.read(notificationServiceProvider).cancelReminder(todo.id);
                          } else if (todo.isCompleted &&
                              todo.remindAt != null &&
                              todo.remindAt!.isAfter(DateTime.now())) {
                            ref.read(notificationServiceProvider).scheduleTodoReminder(
                              id: todo.id,
                              title: 'Todo Reminder',
                              body: todo.title,
                              scheduledDate: todo.remindAt!,
                              alertMode: ref.read(notificationPreferencesProvider).alertMode,
                            );
                          }
                          ref.read(databaseProvider).toggleTodo(todo.id, !todo.isCompleted);
                          ref.read(activityLogProvider.notifier).log(
                            type: 'update',
                            entityType: 'task',
                            entityTitle: todo.title,
                          );
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
                              content: const Text('Todo deleted'),
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
                      ).animate().fadeIn(delay: (50 * i).ms, duration: 300.ms);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'todo_fab',
        onPressed: () => _showAddEditSheet(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, WidgetRef ref, {Todo? todo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditTodoSheet(todo: todo),
    );
  }
}

// ==================== TODO CARD ====================
class _TodoCard extends ConsumerWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TodoCard({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
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
        return AppColors.primary;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOverdue =
        todo.dueDate != null &&
        todo.dueDate!.isBefore(DateTime.now()) &&
        !todo.isCompleted;

    final subTasksAsync = ref.watch(subTasksProvider(todo.id));
    final subTasks = subTasksAsync.valueOrNull ?? [];

    final totalFocusSeconds = ref.watch(totalFocusTimeProvider(todo.id));

    int completedSubTasks =
        subTasks.where((st) => st.isCompleted == true).length;
    int totalSubTasks = subTasks.length;
    double progress =
        totalSubTasks > 0 ? (completedSubTasks / totalSubTasks) : 0.0;

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color:
                  todo.isCompleted
                      ? AppColors.success.withValues(alpha: 0.3)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Priority Indicator Bar
                      if (todo.priority > 0)
                        Container(width: 4, color: _priorityColor()),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Custom Checkbox
                                  GestureDetector(
                                    onTap: onToggle,
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        right: 12,
                                        top: 2,
                                      ),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color:
                                            todo.isCompleted
                                                ? AppColors.success
                                                : theme.colorScheme.surface,
                                        border: Border.all(
                                          color:
                                              todo.isCompleted
                                                  ? AppColors.success
                                                  : theme.colorScheme.outline,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child:
                                          todo.isCompleted
                                              ? const Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                              : null,
                                    ),
                                  ),

                                  // Task Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          todo.title,
                                          style: AppTypography.bodyLarge
                                              .copyWith(
                                                color:
                                                    todo.isCompleted
                                                        ? theme
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                        : theme
                                                            .colorScheme
                                                            .onSurface,
                                                fontWeight: FontWeight.w600,
                                                decoration:
                                                    todo.isCompleted
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                              ),
                                        ),
                                        if (todo.description != null &&
                                            todo.description!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            todo.description!,
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                  decoration:
                                                      todo.isCompleted
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                  height: 1.4,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],

                                        // Tags & Date
                                        if (todo.dueDate != null ||
                                            todo.remindAt != null ||
                                            todo.category != null ||
                                            todo.priority > 0 ||
                                            totalFocusSeconds > 0) ...[
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              if (totalFocusSeconds > 0)
                                                _ModernChip(
                                                  icon: Icons.timer_outlined,
                                                  label:
                                                      '${(totalFocusSeconds / 60).ceil()}m',
                                                  color: AppColors.warning,
                                                ),
                                              if (todo.priority > 0)
                                                _ModernChip(
                                                  icon: Icons.flag_rounded,
                                                  label: _priorityLabel(),
                                                  color: _priorityColor(),
                                                ),
                                              if (todo.category != null)
                                                _ModernChip(
                                                  icon: Icons.folder_outlined,
                                                  label: todo.category!,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              if (todo.dueDate != null)
                                                _ModernChip(
                                                  icon:
                                                      isOverdue
                                                          ? Icons
                                                              .warning_rounded
                                                          : Icons
                                                              .calendar_today_rounded,
                                                  label: DateFormat(
                                                    'MMM d, h:mm a',
                                                  ).format(todo.dueDate!),
                                                  color:
                                                      isOverdue
                                                          ? AppColors.error
                                                          : theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                  isOutlined: true,
                                                ),
                                              if (todo.remindAt != null)
                                                _ModernChip(
                                                  icon: Icons.notifications_active_rounded,
                                                  label: DateFormat(
                                                    'MMM d, h:mm a',
                                                  ).format(todo.remindAt!),
                                                  color: AppColors.warning,
                                                  isOutlined: true,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.timer_outlined),
                                      color: AppColors.warning,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder:
                                              (context) =>
                                                  TodoTimerDialog(todo: todo),
                                        );
                                      },
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      iconSize: 20,
                                      tooltip: 'Start Focus',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded),
                                      color: theme.colorScheme.primary,
                                      onPressed: onEdit,
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      iconSize: 20,
                                      tooltip: 'Edit task',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      color: AppColors.error,
                                      onPressed: onDelete,
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      iconSize: 20,
                                      tooltip: 'Delete task',
                                    ),
                                  ],
                                ),
                              ),

                              // Subtasks Section
                              if (totalSubTasks > 0) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMd,
                                    ),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.account_tree_rounded,
                                            size: 16,
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Subtasks (/)',
                                            style: AppTypography.labelMedium
                                                .copyWith(
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 6,
                                                backgroundColor:
                                                    theme
                                                        .colorScheme
                                                        .outlineVariant,
                                                color:
                                                    progress == 1.0
                                                        ? AppColors.success
                                                        : AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ...List.generate(totalSubTasks, (index) {
                                        final st = subTasks[index];
                                        final isStCompleted = st.isCompleted;
                                        return GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            ref
                                                .read(databaseProvider)
                                                .toggleSubTask(
                                                  st.id,
                                                  !isStCompleted,
                                                );
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8.0,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 2,
                                                  ),
                                                  child: Icon(
                                                    isStCompleted
                                                        ? Icons
                                                            .check_circle_rounded
                                                        : Icons
                                                            .radio_button_unchecked_rounded,
                                                    size: 18,
                                                    color:
                                                        isStCompleted
                                                            ? AppColors.success
                                                            : theme
                                                                .colorScheme
                                                                .outline,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    st.title,
                                                    style: AppTypography.bodyMedium.copyWith(
                                                      color:
                                                          isStCompleted
                                                              ? theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant
                                                              : theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                      decoration:
                                                          isStCompleted
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isOutlined;

  const _ModernChip({
    required this.icon,
    required this.label,
    required this.color,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOutlined ? color.withValues(alpha: 0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEditTodoSheet extends ConsumerStatefulWidget {
  final Todo? todo;

  const _AddEditTodoSheet({this.todo});

  @override
  ConsumerState<_AddEditTodoSheet> createState() => _AddEditTodoSheetState();
}

class _AddEditTodoSheetState extends ConsumerState<_AddEditTodoSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _dueDate;
  DateTime? _remindAt;
  int _priority = 0;
  String? _category;

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

      _loadSubTasks();
    }
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
    super.dispose();
  }

  void _save() async {
    if (_titleController.text.trim().isEmpty) return;

    final db = ref.read(databaseProvider);
    final companion = TodosCompanion(
      title: Value(_titleController.text.trim()),
      description: Value(_descController.text.trim()),
      dueDate: Value(_dueDate),
      remindAt: Value(_remindAt),
      priority: Value(_priority),
      category: Value(_category),
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

      // Delete existing subtasks first to recreate
      final currentSubTasks = await db.watchSubTasks(todoId).first;
      for (var st in currentSubTasks) {
        await db.deleteSubTask(st.id);
      }
    }

    // Save new structured subtasks
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
      _subTasks[index] = {
        'title': title,
        'isCompleted': isCompleted,
      };
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
    final insets = EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,
      top: 24,
      left: 20,
      right: 20,
    );

    return Container(
      padding: insets,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.todo == null ? 'New Task' : 'Edit Task',
                  style: AppTypography.headingMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              autofocus: widget.todo == null,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                hintStyle: AppTypography.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descController,
              style: AppTypography.bodyMedium,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Add details... (optional)',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtasks',
                  style: AppTypography.labelLarge.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addSubTask,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Item'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (_subTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...List.generate(_subTasks.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.drag_indicator_rounded,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _subTasks[index]['title'],
                          onChanged: (val) => _updateSubTask(index, val, _subTasks[index]['isCompleted'] ?? false),
                          style: AppTypography.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Subtask item...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.error,
                        onPressed: () => _removeSubTask(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.calendar_today_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                _dueDate == null
                    ? 'Set Due Date'
                    : DateFormat('MMM d, y • h:mm a').format(_dueDate!),
                style: AppTypography.bodyMedium,
              ),
              trailing:
                  _dueDate != null
                      ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _dueDate = null),
                      )
                      : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (date != null) {
                  if (!context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _dueDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.warning,
              ),
              title: Text(
                _remindAt == null
                    ? 'Set Reminder'
                    : DateFormat('MMM d, y • h:mm a').format(_remindAt!),
                style: AppTypography.bodyMedium,
              ),
              trailing: _remindAt != null
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _remindAt = null),
                    )
                  : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _remindAt ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (date != null) {
                  if (!context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _remindAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
            ),

            const SizedBox(height: 12),
            Text(
              'Priority',
              style: AppTypography.labelLarge.copyWith(
                color: theme.colorScheme.onSurface,
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
                const SizedBox(width: 8),
                _PriorityChip(
                  label: 'Low',
                  color: AppColors.info,
                  isActive: _priority == 1,
                  onTap: () => setState(() => _priority = 1),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  label: 'Med',
                  color: AppColors.warning,
                  isActive: _priority == 2,
                  onTap: () => setState(() => _priority = 2),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  label: 'High',
                  color: AppColors.error,
                  isActive: _priority == 3,
                  onTap: () => setState(() => _priority = 3),
                ),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Save Task',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
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
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: isActive ? color : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color:
                    isActive
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 64,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: AppTypography.headingMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some tasks to get started',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
