import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../providers/notification_preferences_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/routine_provider.dart';
import 'routine_timer_dialog.dart';
import 'routine_focus_player_dialog.dart';
import '../widgets/routine_heatmap_sheet.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  List<Routine> _sortAndFilterRoutinesByPriority(
    List<Routine> routines,
    RoutinePriorityFilter filter,
  ) {
    final sorted = [...routines]
      ..sort((a, b) {
        final pr = b.priority.compareTo(a.priority);
        if (pr != 0) return pr;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    return switch (filter) {
      RoutinePriorityFilter.all => sorted,
      RoutinePriorityFilter.high => sorted.where((r) => r.priority == 3).toList(),
      RoutinePriorityFilter.medium => sorted.where((r) => r.priority == 2).toList(),
      RoutinePriorityFilter.low => sorted.where((r) => r.priority == 1).toList(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final todayRoutinesAsync = ref.watch(todayRoutinesProvider);
    final priorityFilter = ref.watch(routinePriorityFilterProvider);
    final completionsAsync = ref.watch(todayCompletionsProvider);

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
                        'Daily Routines',
                        style: AppTypography.headingLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      todayRoutinesAsync.when(
                        data: (routines) {
                          final total = routines.length;
                          final done = completionsAsync.valueOrNull?.length ?? 0;
                          return Text(
                            total > 0
                                ? '$total scheduled today • $done completed'
                                : 'Build healthy daily habits & routines',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          );
                        },
                        loading: () => Text(
                          'Loading routines...',
                          style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),

                  // Header Actions
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _showManageRoutines(context, ref),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        tooltip: 'Manage Routines',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Priority Filter Segment Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _PriorityFilterTab(
                    label: 'All',
                    isActive: priorityFilter == RoutinePriorityFilter.all,
                    onTap: () => ref.read(routinePriorityFilterProvider.notifier).state = RoutinePriorityFilter.all,
                  ),
                  const SizedBox(width: 8),
                  _PriorityFilterTab(
                    label: 'High',
                    isActive: priorityFilter == RoutinePriorityFilter.high,
                    onTap: () => ref.read(routinePriorityFilterProvider.notifier).state = RoutinePriorityFilter.high,
                    activeColor: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  _PriorityFilterTab(
                    label: 'Medium',
                    isActive: priorityFilter == RoutinePriorityFilter.medium,
                    onTap: () => ref.read(routinePriorityFilterProvider.notifier).state = RoutinePriorityFilter.medium,
                    activeColor: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  _PriorityFilterTab(
                    label: 'Low',
                    isActive: priorityFilter == RoutinePriorityFilter.low,
                    onTap: () => ref.read(routinePriorityFilterProvider.notifier).state = RoutinePriorityFilter.low,
                    activeColor: AppColors.info,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Routines List ──
            Expanded(
              child: todayRoutinesAsync.when(
                data: (routines) {
                  final displayRoutines = _sortAndFilterRoutinesByPriority(routines, priorityFilter);
                  if (displayRoutines.isEmpty) {
                    final label = switch (priorityFilter) {
                      RoutinePriorityFilter.all => 'today',
                      RoutinePriorityFilter.high => 'high priority',
                      RoutinePriorityFilter.medium => 'medium priority',
                      RoutinePriorityFilter.low => 'low priority',
                    };
                    return _emptyState(context, ref, message: 'No $label routines scheduled');
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayRoutines.length,
                    itemBuilder: (ctx, i) => _RoutineSection(routine: displayRoutines[i]),
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
                        const Text('Could not load routines'),
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
        heroTag: 'routine_fab',
        onPressed: () => _showAddRoutine(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text(
          'New Routine',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref, {String message = 'No routines for today'}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, size: 44, color: AppColors.purple),
          ),
          const SizedBox(height: 16),
          Text(message, style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            'Tap New Routine below to schedule daily habits',
            style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showAddRoutine(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddRoutineSheet(),
    );
  }

  void _showManageRoutines(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ManageRoutinesScreen()));
  }
}

// ────────────────── ROUTINE SECTION CARD ──────────────────

class _RoutineSection extends ConsumerWidget {
  final Routine routine;
  const _RoutineSection({required this.routine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itemsAsync = ref.watch(routineItemsProvider(routine.id));
    final completionsAsync = ref.watch(todayCompletionsProvider);

    final priorityColor = switch (routine.priority) {
      3 => AppColors.error,
      2 => AppColors.warning,
      1 => AppColors.info,
      _ => theme.colorScheme.outline,
    };

    final priorityLabel = switch (routine.priority) {
      3 => 'High',
      2 => 'Med',
      1 => 'Low',
      _ => null,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: routine.priority > 0
              ? priorityColor.withValues(alpha: isDark ? 0.35 : 0.25)
              : theme.colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.08),
          width: routine.priority > 0 ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, size: 20, color: AppColors.purple),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            routine.title,
                            style: AppTypography.labelLarge.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Streak Pill (No emoji)
                        ref.watch(routineStreakProvider(routine)).when(
                          data: (streak) => streak > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.local_fire_department_rounded, size: 11, color: AppColors.orange),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$streak',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (routine.description != null && routine.description!.isNotEmpty)
                      Text(
                        routine.description!,
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

              // Priority Badge
              if (priorityLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Consistency Heatmap Button
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                tooltip: 'Consistency Heatmap',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => RoutineHeatmapSheet(routine: routine),
                  );
                },
              ),

              // Add Task to Routine Button
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 20),
                tooltip: 'Add Task to Routine',
                visualDensity: VisualDensity.compact,
                onPressed: () => _addItem(context, ref),
              ),
            ],
          ),

          // ── Items & Live Progress ──
          itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'No tasks added yet. Tap + to add.',
                    style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }

              return completionsAsync.when(
                data: (completions) {
                  final hidden = ref.watch(hiddenItemsProvider);
                  final visibleItems = items.where((i) => !hidden.contains('routine_item_${i.id}')).toList();
                  final completedIds = completions.map((c) => c.routineItemId).toSet();
                  final completed = visibleItems.where((i) => completedIds.contains(i.id)).length;
                  final total = visibleItems.length;
                  final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
                  final isAllDone = total > 0 && completed == total;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Progress Bar Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAllDone ? 'All $total tasks done today' : '$completed of $total completed',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isAllDone ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (visibleItems.isNotEmpty && !isAllDone)
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RoutineFocusPlayerDialog(
                                      routine: routine,
                                      items: visibleItems,
                                    ),
                                    fullscreenDialog: true,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.play_circle_fill_rounded, size: 15, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Start Flow',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAllDone ? AppColors.success : AppColors.purple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Item Rows
                      ...visibleItems.map((item) {
                        final isDone = completedIds.contains(item.id);
                        return _RoutineItemTile(
                          item: item,
                          routine: routine,
                          isDone: isDone,
                          onToggle: () async {
                            final db = ref.read(databaseProvider);
                            if (isDone) {
                              await db.unmarkRoutineItemCompleted(item.id);
                            } else {
                              HapticFeedback.mediumImpact();
                              await db.markRoutineItemCompleted(item.id);
                            }
                            ref.read(activityLogProvider.notifier).log(
                              type: 'update',
                              entityType: 'routine',
                              entityTitle: item.title,
                            );
                          },
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _addItem(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditRoutineItemSheet(routine: routine),
    );
  }
}

// ────────────────── ROUTINE ITEM TILE ──────────────────

class _RoutineItemTile extends ConsumerWidget {
  final RoutineItem item;
  final Routine routine;
  final bool isDone;
  final VoidCallback onToggle;

  const _RoutineItemTile({
    required this.item,
    required this.routine,
    required this.isDone,
    required this.onToggle,
  });

  void _showSubtasksSheet(BuildContext context, RoutineItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoutineSubTasksQuickSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subTasksAsync = ref.watch(routineSubTasksProvider(item.id));
    final subTasks = subTasksAsync.valueOrNull ?? [];
    final doneSubTasks = subTasks.where((st) => st.isCompleted).length;
    final totalSubTasks = subTasks.length;

    final itemPriorityColor = switch (item.priority) {
      3 => AppColors.error,
      2 => AppColors.warning,
      1 => AppColors.info,
      _ => Colors.transparent,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDone
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.2 : 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? AppColors.success.withValues(alpha: 0.2)
              : (item.priority > 0
                  ? itemPriorityColor.withValues(alpha: 0.3)
                  : theme.colorScheme.outline.withValues(alpha: 0.08)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _AddEditRoutineItemSheet(routine: routine, item: item),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // 1-Tap Round Squircle Checkbox
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.success : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isDone ? AppColors.success : theme.colorScheme.outline,
                        width: 1.8,
                      ),
                    ),
                    child: isDone ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(width: 10),

                // Title & Subtasks Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                              : theme.colorScheme.onSurface,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (totalSubTasks > 0) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _showSubtasksSheet(context, item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.checklist_rounded, size: 11, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text(
                                  '$doneSubTasks/$totalSubTasks subtasks',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 11, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Timer Action
                IconButton(
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 20, color: AppColors.warning),
                  tooltip: 'Start Focus',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RoutineTimerDialog(item: item),
                    );
                  },
                ),

                // Edit Action
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: theme.colorScheme.primary,
                  tooltip: 'Edit Task',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _AddEditRoutineItemSheet(routine: routine, item: item),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────── ROUTINE SUBTASKS QUICK SHEET ──────────────────

class _RoutineSubTasksQuickSheet extends ConsumerStatefulWidget {
  final RoutineItem item;

  const _RoutineSubTasksQuickSheet({required this.item});

  @override
  ConsumerState<_RoutineSubTasksQuickSheet> createState() => _RoutineSubTasksQuickSheetState();
}

class _RoutineSubTasksQuickSheetState extends ConsumerState<_RoutineSubTasksQuickSheet> {
  final _newSubTaskController = TextEditingController();

  @override
  void dispose() {
    _newSubTaskController.dispose();
    super.dispose();
  }

  void _addNewSubTask(List<RoutineSubTask> currentSubTasks) async {
    final text = _newSubTaskController.text.trim();
    if (text.isEmpty) return;

    final db = ref.read(databaseProvider);
    await db.addRoutineSubTask(
      RoutineSubTasksCompanion(
        routineItemId: Value(widget.item.id),
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
    final subTasksAsync = ref.watch(routineSubTasksProvider(widget.item.id));

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
                // Header Bar
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
                            widget.item.title,
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

                // Progress Bar Card
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
                            isAllDone ? 'All $totalCount subtasks completed!' : '$completedCount of $totalCount completed',
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

                // Subtasks List
                if (subTasks.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No subtasks yet. Add one below!',
                        style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(databaseProvider).toggleRoutineSubTask(st.id, !st.isCompleted);
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
                                  child: st.isCompleted ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                                ),
                              ),
                              const SizedBox(width: 10),
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
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(databaseProvider).deleteRoutineSubTask(st.id);
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

                // Add Subtask Bar
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

// ────────────────── ADD ROUTINE MODAL SHEET ──────────────────

class _AddRoutineSheet extends ConsumerStatefulWidget {
  const _AddRoutineSheet();

  @override
  ConsumerState<_AddRoutineSheet> createState() => _AddRoutineSheetState();
}

class _AddRoutineSheetState extends ConsumerState<_AddRoutineSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<int> _selectedDays = {DateTime.now().weekday};
  final List<Map<String, dynamic>> _items = [];
  final List<TimeOfDay> _reminderTimes = [];
  int _routinePriority = 2;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add({
        'title': '',
        'priority': 0,
        'subTasks': <Map<String, dynamic>>[],
      });
    });
  }

  void _updateItemTitle(int index, String title) {
    setState(() => _items[index]['title'] = title);
  }

  void _updateItemPriority(int index, int priority) {
    setState(() => _items[index]['priority'] = priority);
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routine name is required')),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one day')),
      );
      return;
    }

    final validItems = _items.where((item) => (item['title'] as String).trim().isNotEmpty).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one routine task')),
      );
      return;
    }

    try {
      final db = ref.read(databaseProvider);
      final routineId = await db.addRoutine(
        RoutinesCompanion(
          title: Value(title),
          description: Value(_descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim()),
          priority: Value(_routinePriority),
          days: Value(([..._selectedDays]..sort()).join(',')),
          reminderTime: Value(
            _reminderTimes.isEmpty
                ? null
                : _reminderTimes
                    .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
                    .join(','),
          ),
          createdAt: Value(DateTime.now()),
        ),
      );

      for (int i = 0; i < validItems.length; i++) {
        final itemTitle = (validItems[i]['title'] as String).trim();
        final itemPriority = validItems[i]['priority'] as int? ?? 0;
        final itemId = await db.addRoutineItem(
          RoutineItemsCompanion(
            routineId: Value(routineId),
            title: Value(itemTitle),
            priority: Value(itemPriority),
            sortOrder: Value(i),
          ),
        );

        final subTasks = validItems[i]['subTasks'] as List<Map<String, dynamic>>;
        for (int j = 0; j < subTasks.length; j++) {
          final subTitle = (subTasks[j]['title'] as String?)?.trim() ?? '';
          if (subTitle.isEmpty) continue;
          await db.addRoutineSubTask(
            RoutineSubTasksCompanion(
              routineItemId: Value(itemId),
              title: Value(subTitle),
              isCompleted: const Value(false),
              sortOrder: Value(j),
              createdAt: Value(DateTime.now()),
            ),
          );
        }
      }

      final prefs = ref.read(notificationPreferencesProvider);
      final times = _reminderTimes.isEmpty ? <TimeOfDay>[prefs.routineReminderTime] : _reminderTimes;
      await ref.read(notificationServiceProvider).scheduleRoutineReminders(
        routineId: routineId,
        title: 'Routine: $title',
        body: 'Time to start your routine!',
        daysOfWeek: _selectedDays.toList(),
        reminderTimes: times,
        alertMode: prefs.alertMode,
      );

      ref.read(activityLogProvider.notifier).log(
        type: 'add',
        entityType: 'routine',
        entityTitle: title,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routine created successfully')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save routine')),
      );
    }
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
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Routine',
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

              // Title Input
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Routine name (e.g. Morning Focus, Workout)...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65), fontSize: 14),
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

              // Description Input
              TextField(
                controller: _descCtrl,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Description or purpose (optional)...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65), fontSize: 13.5),
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

              // ── Repeat Days Selector (M T W T F S S) ──
              Text(
                'Repeat on Days',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                  final day = e.key + 1;
                  final isSelected = _selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        isSelected ? _selectedDays.remove(day) : _selectedDays.add(day);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.primary
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : theme.colorScheme.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ── Routine Priority ──
              Text(
                'Routine Priority',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PriorityChip(
                    label: 'Low',
                    color: AppColors.info,
                    isActive: _routinePriority == 1,
                    onTap: () => setState(() => _routinePriority = 1),
                  ),
                  const SizedBox(width: 8),
                  _PriorityChip(
                    label: 'Medium',
                    color: AppColors.warning,
                    isActive: _routinePriority == 2,
                    onTap: () => setState(() => _routinePriority = 2),
                  ),
                  const SizedBox(width: 8),
                  _PriorityChip(
                    label: 'High',
                    color: AppColors.error,
                    isActive: _routinePriority == 3,
                    onTap: () => setState(() => _routinePriority = 3),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Reminder Times ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reminder Times',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time != null && mounted) {
                        setState(() {
                          final already = _reminderTimes.any((t) => t.hour == time.hour && t.minute == time.minute);
                          if (!already) {
                            _reminderTimes.add(time);
                            _reminderTimes.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.add_alarm_rounded, size: 16),
                    label: const Text('Add Time', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              if (_reminderTimes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _reminderTimes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final time = entry.value;
                    return Chip(
                      label: Text(time.format(context), style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () => setState(() => _reminderTimes.removeAt(index)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),

              // ── Routine Tasks Builder ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Routine Tasks',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Task', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Add tasks to complete in this routine',
                    style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  final priority = item['priority'] as int? ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: item['title'] as String,
                                onChanged: (v) => _updateItemTitle(index, v),
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(
                                  hintText: 'Task name...',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: AppColors.error,
                              onPressed: () => _removeItem(index),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _PriorityChip(
                              label: 'None',
                              color: theme.colorScheme.onSurfaceVariant,
                              isActive: priority == 0,
                              onTap: () => _updateItemPriority(index, 0),
                            ),
                            const SizedBox(width: 6),
                            _PriorityChip(
                              label: 'Low',
                              color: AppColors.info,
                              isActive: priority == 1,
                              onTap: () => _updateItemPriority(index, 1),
                            ),
                            const SizedBox(width: 6),
                            _PriorityChip(
                              label: 'Med',
                              color: AppColors.warning,
                              isActive: priority == 2,
                              onTap: () => _updateItemPriority(index, 2),
                            ),
                            const SizedBox(width: 6),
                            _PriorityChip(
                              label: 'High',
                              color: AppColors.error,
                              isActive: priority == 3,
                              onTap: () => _updateItemPriority(index, 3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────── ADD / EDIT SINGLE ROUTINE TASK SHEET ──────────────────

class _AddEditRoutineItemSheet extends ConsumerStatefulWidget {
  final Routine routine;
  final RoutineItem? item;

  const _AddEditRoutineItemSheet({required this.routine, this.item});

  @override
  ConsumerState<_AddEditRoutineItemSheet> createState() => _AddEditRoutineItemSheetState();
}

class _AddEditRoutineItemSheetState extends ConsumerState<_AddEditRoutineItemSheet> {
  final _titleController = TextEditingController();
  int _priority = 0;
  final List<Map<String, dynamic>> _subTasks = [];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleController.text = widget.item!.title;
      _priority = widget.item!.priority;
      _loadSubTasks();
    }
  }

  Future<void> _loadSubTasks() async {
    final db = ref.read(databaseProvider);
    final existing = await db.watchRoutineSubTasks(widget.item!.id).first;
    if (!mounted) return;
    setState(() {
      for (final st in existing) {
        _subTasks.add({
          'title': st.title,
          'isCompleted': st.isCompleted,
          'id': st.id,
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;

    final db = ref.read(databaseProvider);
    int itemId;
    if (widget.item == null) {
      itemId = await db.addRoutineItem(RoutineItemsCompanion(
        routineId: Value(widget.routine.id),
        title: Value(_titleController.text.trim()),
        priority: Value(_priority),
        sortOrder: const Value(0),
      ));
      ref.read(activityLogProvider.notifier).log(
        type: 'add',
        entityType: 'routine',
        entityTitle: _titleController.text.trim(),
      );
    } else {
      itemId = widget.item!.id;
      await db.updateRoutineItem(RoutineItemsCompanion(
        id: Value(itemId),
        routineId: Value(widget.routine.id),
        title: Value(_titleController.text.trim()),
        priority: Value(_priority),
      ));
      ref.read(activityLogProvider.notifier).log(
        type: 'update',
        entityType: 'routine',
        entityTitle: _titleController.text.trim(),
      );

      final existing = await db.watchRoutineSubTasks(itemId).first;
      for (final st in existing) {
        await db.deleteRoutineSubTask(st.id);
      }
    }

    for (int i = 0; i < _subTasks.length; i++) {
      final title = (_subTasks[i]['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      await db.addRoutineSubTask(
        RoutineSubTasksCompanion(
          routineItemId: Value(itemId),
          title: Value(title),
          isCompleted: Value(_subTasks[i]['isCompleted'] ?? false),
          sortOrder: Value(i),
          createdAt: Value(DateTime.now()),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  void _addSubTask() {
    setState(() => _subTasks.add({'title': '', 'isCompleted': false}));
  }

  void _updateSubTask(int index, String title, bool isCompleted) {
    setState(() => _subTasks[index] = {'title': title, 'isCompleted': isCompleted});
  }

  void _removeSubTask(int index) {
    setState(() => _subTasks.removeAt(index));
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.item == null ? 'New Routine Task' : 'Edit Routine Task',
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
              TextField(
                controller: _titleController,
                autofocus: widget.item == null,
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Priority Selector
              Text(
                'Task Priority',
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
                    label: 'Med',
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

              const SizedBox(height: 16),

              // Subtasks
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────── MANAGE ROUTINES SCREEN ──────────────────

class _ManageRoutinesScreen extends ConsumerWidget {
  const _ManageRoutinesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Routines')),
      body: routinesAsync.when(
        data: (allRoutines) {
          final hidden = ref.watch(hiddenItemsProvider);
          final routines = allRoutines.where((r) => !hidden.contains('routine_${r.id}')).toList();

          if (routines.isEmpty) {
            return Center(
              child: Text(
                'No routines created yet',
                style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routines.length,
            itemBuilder: (ctx, i) {
              final r = routines[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: AppTypography.labelLarge.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (r.description != null && r.description!.isNotEmpty)
                            Text(
                              r.description!,
                              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDays(r.days),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showEditRoutineSheet(context, ref, r),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      onPressed: () {
                        final itemKey = 'routine_${r.id}';
                        final db = ref.read(databaseProvider);
                        final hiddenNotifier = ref.read(hiddenItemsProvider.notifier);
                        final notif = ref.read(notificationServiceProvider);
                        final messenger = ScaffoldMessenger.of(context);

                        hiddenNotifier.update((state) => {...state, itemKey});
                        messenger.clearSnackBars();

                        bool undone = false;
                        final timer = Timer(const Duration(seconds: 3), () async {
                          if (!undone) {
                            await notif.cancelRoutineReminders(r.id);
                            await db.deleteRoutine(r.id);
                            hiddenNotifier.update((state) {
                              final s = {...state};
                              s.remove(itemKey);
                              return s;
                            });
                            ref.read(activityLogProvider.notifier).log(
                              type: 'delete',
                              entityType: 'routine',
                              entityTitle: r.title,
                            );
                          }
                          messenger.hideCurrentSnackBar();
                        });

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Routine "${r.title}" deleted'),
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
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load data')),
      ),
    );
  }

  void _showEditRoutineSheet(BuildContext context, WidgetRef ref, Routine routine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditRoutineSheet(routine: routine),
    );
  }

  String _formatDays(String days) {
    const names = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return days.split(',').map((d) => names[int.tryParse(d)] ?? d).join(', ');
  }
}

// ────────────────── EDIT ROUTINE MODAL SHEET ──────────────────

class _EditRoutineSheet extends ConsumerStatefulWidget {
  final Routine routine;

  const _EditRoutineSheet({required this.routine});

  @override
  ConsumerState<_EditRoutineSheet> createState() => _EditRoutineSheetState();
}

class _EditRoutineSheetState extends ConsumerState<_EditRoutineSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final Set<int> _selectedDays;
  final List<TimeOfDay> _reminderTimes = [];
  int _routinePriority = 2;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.routine.title);
    _descCtrl = TextEditingController(text: widget.routine.description ?? '');
    _selectedDays = widget.routine.days
        .split(',')
        .map((d) => int.tryParse(d))
        .whereType<int>()
        .toSet();
    _routinePriority = widget.routine.priority;
    _parseReminderTimes(widget.routine.reminderTime);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _parseReminderTimes(String? serialized) {
    _reminderTimes.clear();
    if (serialized == null || serialized.trim().isEmpty) return;
    for (final token in serialized.split(',')) {
      final parts = token.trim().split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
      _reminderTimes.add(TimeOfDay(hour: hour, minute: minute));
    }
    _reminderTimes.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final db = ref.read(databaseProvider);
    await db.updateRoutine(
      RoutinesCompanion(
        id: Value(widget.routine.id),
        title: Value(title),
        description: Value(_descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim()),
        priority: Value(_routinePriority),
        days: Value(([..._selectedDays]..sort()).join(',')),
        reminderTime: Value(
          _reminderTimes.isEmpty
              ? null
              : _reminderTimes
                  .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
                  .join(','),
        ),
      ),
    );

    final prefs = ref.read(notificationPreferencesProvider);
    final times = _reminderTimes.isEmpty ? <TimeOfDay>[prefs.routineReminderTime] : _reminderTimes;
    await ref.read(notificationServiceProvider).scheduleRoutineReminders(
      routineId: widget.routine.id,
      title: 'Routine: $title',
      body: 'Time to start your routine!',
      daysOfWeek: _selectedDays.toList(),
      reminderTimes: times,
      alertMode: prefs.alertMode,
    );

    ref.read(activityLogProvider.notifier).log(
      type: 'update',
      entityType: 'routine',
      entityTitle: title,
    );

    if (mounted) Navigator.pop(context);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Routine',
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
              TextField(
                controller: _titleCtrl,
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Routine name...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Description (optional)...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),

              // Days
              Text(
                'Repeat on Days',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                  final day = e.key + 1;
                  final isSelected = _selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        isSelected ? _selectedDays.remove(day) : _selectedDays.add(day);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.primary
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : theme.colorScheme.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Priority
              Text(
                'Priority',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PriorityChip(
                    label: 'Low',
                    color: AppColors.info,
                    isActive: _routinePriority == 1,
                    onTap: () => setState(() => _routinePriority = 1),
                  ),
                  const SizedBox(width: 8),
                  _PriorityChip(
                    label: 'Medium',
                    color: AppColors.warning,
                    isActive: _routinePriority == 2,
                    onTap: () => setState(() => _routinePriority = 2),
                  ),
                  const SizedBox(width: 8),
                  _PriorityChip(
                    label: 'High',
                    color: AppColors.error,
                    isActive: _routinePriority == 3,
                    onTap: () => setState(() => _routinePriority = 3),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────── REUSABLE HELPER CHIPS ──────────────────

class _PriorityFilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const _PriorityFilterTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? activeColor.withValues(alpha: 0.2) : activeColor.withValues(alpha: 0.12))
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? activeColor : theme.colorScheme.outline.withValues(alpha: 0.15),
              width: isActive ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
