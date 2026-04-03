import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../providers/notification_preferences_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/routine_provider.dart';
import 'routine_timer_dialog.dart';

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
    final todayRoutinesAsync = ref.watch(todayRoutinesProvider);
    final priorityFilter = ref.watch(routinePriorityFilterProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Routines', style: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurface))),
                  TextButton.icon(
                    onPressed: () => _showManageRoutines(context, ref),
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Manage'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 8),
            // Today's header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("Today's Routine", style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 12),
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
                    return _emptyState(context, ref, message: 'No $label routines');
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayRoutines.length,
                    itemBuilder: (ctx, i) => _RoutineSection(
                      routine: displayRoutines[i],
                    )
                        .animate().fadeIn(delay: (100 * i).ms, duration: 400.ms),
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
        heroTag: 'routine_fab',
        onPressed: () => _showAddRoutine(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref, {String message = 'No routines for today'}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.loop_rounded, size: 48, color: AppColors.success),
          ),
          const SizedBox(height: 20),
          Text(message, style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Tap + to create a routine', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
    setState(() {
      _items[index]['title'] = title;
    });
  }

  void _updateItemPriority(int index, int priority) {
    setState(() {
      _items[index]['priority'] = priority;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _addSubTask(int itemIndex) {
    setState(() {
      (_items[itemIndex]['subTasks'] as List<Map<String, dynamic>>).add({
        'title': '',
        'isCompleted': false,
      });
    });
  }

  void _updateSubTask(int itemIndex, int subIndex, String title) {
    setState(() {
      (_items[itemIndex]['subTasks'] as List<Map<String, dynamic>>)[subIndex]['title'] = title;
    });
  }

  void _removeSubTask(int itemIndex, int subIndex) {
    setState(() {
      (_items[itemIndex]['subTasks'] as List<Map<String, dynamic>>).removeAt(subIndex);
    });
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
              isCompleted: Value(false),
              sortOrder: Value(j),
              createdAt: Value(DateTime.now()),
            ),
          );
        }
      }

      final prefs = ref.read(notificationPreferencesProvider);
      final times =
          _reminderTimes.isEmpty ? <TimeOfDay>[prefs.routineReminderTime] : _reminderTimes;
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
        const SnackBar(content: Text('Routine created with tasks and subtasks')),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('New Routine', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(controller: _titleCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Routine name...')),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, decoration: const InputDecoration(hintText: 'Description (optional)...')),
            const SizedBox(height: 16),
            Text('Repeat on', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                final day = e.key + 1;
                final isSelected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected ? _selectedDays.remove(day) : _selectedDays.add(day);
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: isSelected ? AppColors.primary : theme.colorScheme.outline),
                    ),
                    child: Center(
                      child: Text(
                        e.value,
                        style: AppTypography.labelMedium.copyWith(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Routine Priority', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
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
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
              title: Text(
                _reminderTimes.isEmpty
                    ? 'Reminder Times (Optional)'
                    : 'Reminders: ${_reminderTimes.map((t) => t.format(context)).join(', ')}',
                style: AppTypography.bodyMedium,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_alarm_rounded, size: 20),
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
              ),
              onTap: () async {
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
            ),
            if (_reminderTimes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reminderTimes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final time = entry.value;
                  return Chip(
                    label: Text(time.format(context)),
                    onDeleted: () => setState(() => _reminderTimes.removeAt(index)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Routine Tasks', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Task'),
                ),
              ],
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Add tasks with priority and subtasks', style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...List.generate(_items.length, (index) {
                final item = _items[index];
                final subTasks = item['subTasks'] as List<Map<String, dynamic>>;
                final priority = item['priority'] as int? ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
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
                              decoration: const InputDecoration(
                                hintText: 'Task name...',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: AppColors.error,
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _PriorityChip(
                            label: 'None',
                            color: theme.colorScheme.onSurfaceVariant,
                            isActive: priority == 0,
                            onTap: () => _updateItemPriority(index, 0),
                          ),
                          const SizedBox(width: 8),
                          _PriorityChip(
                            label: 'Low',
                            color: AppColors.info,
                            isActive: priority == 1,
                            onTap: () => _updateItemPriority(index, 1),
                          ),
                          const SizedBox(width: 8),
                          _PriorityChip(
                            label: 'Med',
                            color: AppColors.warning,
                            isActive: priority == 2,
                            onTap: () => _updateItemPriority(index, 2),
                          ),
                          const SizedBox(width: 8),
                          _PriorityChip(
                            label: 'High',
                            color: AppColors.error,
                            isActive: priority == 3,
                            onTap: () => _updateItemPriority(index, 3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtasks', style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurface)),
                          TextButton.icon(
                            onPressed: () => _addSubTask(index),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      if (subTasks.isNotEmpty)
                        ...List.generate(subTasks.length, (subIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.subdirectory_arrow_right_rounded, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: subTasks[subIndex]['title'] as String,
                                    onChanged: (v) => _updateSubTask(index, subIndex, v),
                                    decoration: const InputDecoration(
                                      hintText: 'Subtask...',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => _removeSubTask(index, subIndex),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text('Create Routine', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ROUTINE SECTION ====================
class _RoutineSection extends ConsumerWidget {
  final Routine routine;
  const _RoutineSection({required this.routine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(routineItemsProvider(routine.id));
    final completionsAsync = ref.watch(todayCompletionsProvider);
    final priorityLabel = switch (routine.priority) {
      3 => 'High',
      2 => 'Medium',
      1 => 'Low',
      _ => null,
    };
    final priorityColor = switch (routine.priority) {
      3 => AppColors.error,
      2 => AppColors.warning,
      1 => AppColors.info,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: const Icon(Icons.loop_rounded, size: 20, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(routine.title, style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          ref.watch(routineStreakProvider(routine)).when(
                            data: (streak) => streak > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text('🔥 $streak', style: AppTypography.labelSmall.copyWith(color: AppColors.error)),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      if (routine.description != null)
                        Text(routine.description!, style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (priorityLabel != null) ...[
                  _PriorityBadgeSmall(label: priorityLabel, color: priorityColor),
                  const SizedBox(width: 6),
                ],
                // Add item button
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  onPressed: () => _addItem(context, ref),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('No items yet. Tap + to add.', style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  );
                }

                return completionsAsync.when(
                  data: (completions) {
                    final hidden = ref.watch(hiddenItemsProvider);
                    final visibleItems = items.where((i) => !hidden.contains('routine_item_${i.id}')).toList();
                    final completedIds = completions.map((c) => c.routineItemId).toSet();
                    final completed = visibleItems.where((i) => completedIds.contains(i.id)).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: visibleItems.isEmpty ? 0 : completed / visibleItems.length,
                            backgroundColor: theme.colorScheme.outline,
                            color: AppColors.success,
                            minHeight: 6,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('$completed/${visibleItems.length} completed', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                        const SizedBox(height: 4),
                        ...visibleItems.map((item) {
                          final isDone = completedIds.contains(item.id);
                          return Dismissible(
                            key: ValueKey('dismiss_routine_item_${item.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              final itemKey = 'routine_item_${item.id}';
                              final db = ref.read(databaseProvider);
                              final hiddenNotifier = ref.read(hiddenItemsProvider.notifier);
                              final messenger = ScaffoldMessenger.of(context);
                              
                              hiddenNotifier.update((state) => {...state, itemKey});
                              messenger.clearSnackBars();
                              
                              bool undone = false;
                              final timer = Timer(const Duration(seconds: 3), () async {
                                if (!undone) {
                                  await db.deleteRoutineItem(item.id);
                                  hiddenNotifier.update((state) {
                                    final s = {...state};
                                    s.remove(itemKey);
                                    return s;
                                  });
                                  ref.read(activityLogProvider.notifier).log(
                                    type: 'delete',
                                    entityType: 'routine',
                                    entityTitle: 'Task: ${item.title}',
                                  );
                                }
                                messenger.hideCurrentSnackBar();
                              });
                              
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Task "${item.title}" removed from routine'),
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
                            child: _RoutineItemTile(
                              item: item,
                              routine: routine,
                              isDone: isDone,
                              onToggle: () async {
                                final db = ref.read(databaseProvider);
                                if (isDone) {
                                  await db.unmarkRoutineItemCompleted(item.id);
                                } else {
                                  HapticFeedback.lightImpact();
                                  await db.markRoutineItemCompleted(item.id);
                                }
                                ref.read(activityLogProvider.notifier).log(
                                  type: 'update',
                                  entityType: 'routine',
                                  entityTitle: 'Task: ${item.title}',
                                );
                              },
                            ),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 180.ms,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.14) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive ? activeColor : theme.colorScheme.outline,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isActive ? activeColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineItemTile extends ConsumerWidget {
  final RoutineItem item;
  final Routine routine;
  final bool isDone;
  final VoidCallback onToggle;
  const _RoutineItemTile({required this.item, required this.routine, required this.isDone, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final priorityColor = item.priority == 1 ? Colors.green : item.priority == 2 ? Colors.orange : item.priority == 3 ? Colors.red : Colors.transparent;
    final priorityLabel = switch (item.priority) {
      1 => 'Low',
      2 => 'Medium',
      3 => 'High',
      _ => null,
    };
    final subTasksAsync = ref.watch(routineSubTasksProvider(item.id));
    final subTasks = subTasksAsync.valueOrNull ?? [];
    final doneSubTasks = subTasks.where((st) => st.isCompleted).length;

    return InkWell(
      onTap: onToggle,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AddEditRoutineItemSheet(routine: routine, item: item),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? AppColors.success : Colors.transparent,
                    border: Border.all(color: isDone ? AppColors.success : (item.priority > 0 ? priorityColor : theme.colorScheme.onSurfaceVariant), width: 2),
                  ),
                  child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDone ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (priorityLabel != null && !isDone) ...[
                  _PriorityBadgeSmall(
                    label: priorityLabel,
                    color: priorityColor,
                    outlined: false,
                  ),
                  const SizedBox(width: 6),
                ],
                if (item.startTime != null)
                  Text(item.startTime!, style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                IconButton(
                  icon: Icon(Icons.timer_outlined, size: 20, color: theme.colorScheme.primary),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RoutineTimerDialog(item: item),
                    );
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (subTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Subtasks: $doneSubTasks/${subTasks.length}',
                style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              ...subTasks.map(
                (st) => Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Checkbox(
                        value: st.isCompleted,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          ref.read(databaseProvider).toggleRoutineSubTask(st.id, v ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        st.title,
                        style: AppTypography.bodySmall.copyWith(
                          color: st.isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                          decoration: st.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriorityBadgeSmall extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const _PriorityBadgeSmall({
    required this.label,
    required this.color,
    this.outlined = true,
  });

  @override
  Widget build(BuildContext context) {
    final badgeContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag_rounded, size: 9, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );

    if (!outlined) {
      return badgeContent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}


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
        sortOrder: Value(0),
      ));
      ref.read(activityLogProvider.notifier).log(
        type: 'add',
        entityType: 'routine',
        entityTitle: 'Task: ${_titleController.text.trim()}',
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
        entityTitle: 'Task: ${_titleController.text.trim()}',
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
      top: 24, left: 20, right: 20,
    );

    return Container(
      padding: insets,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
                  widget.item == null ? 'New Routine Task' : 'Edit Routine Task',
                  style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: widget.item == null,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtasks', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
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
                      Icon(Icons.drag_indicator_rounded, color: theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _subTasks[index]['title'],
                          onChanged: (val) => _updateSubTask(index, val, _subTasks[index]['isCompleted'] ?? false),
                          style: AppTypography.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Subtask item...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.primary),
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
            ],
            const SizedBox(height: 16),
            Text('Priority', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Save Routine Task',
                  style: AppTypography.labelLarge.copyWith(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
            color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: isActive ? color : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isActive ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ==================== MANAGE ROUTINES ====================
class _ManageRoutinesScreen extends ConsumerWidget {
  const _ManageRoutinesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Routines')),
      body: routinesAsync.when(
        data: (allRoutines) {
          final hidden = ref.watch(hiddenItemsProvider);
          final routines = allRoutines.where((r) => !hidden.contains('routine_${r.id}')).toList();

          if (routines.isEmpty) {
            return Center(
              child: Text('No routines created yet', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routines.length,
            itemBuilder: (ctx, i) {
              final r = routines[i];
              return AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
                          if (r.description != null)
                            Text(r.description!, style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(_formatDays(r.days), style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
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
        error: (e, _) => Center(child: Text('Error: $e')),
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
  final List<Map<String, Object?>> _items = [];
  final Set<int> _originalItemIds = {};
  int _routinePriority = 2;
  bool _isSaving = false;

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
    _loadItems();
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

  Future<void> _loadItems() async {
    final db = ref.read(databaseProvider);
    final items = await db.watchRoutineItems(widget.routine.id).first;
    final loaded = <Map<String, Object?>>[];

    for (final item in items) {
      _originalItemIds.add(item.id);
      final subTasks = await db.watchRoutineSubTasks(item.id).first;
      final normalizedSubTasks = subTasks
          .map<Map<String, Object?>>(
            (st) => Map<String, Object?>.from({
              'id': st.id,
              'title': st.title,
              'isCompleted': st.isCompleted,
            }),
          )
          .toList(growable: true);
      loaded.add(
        Map<String, Object?>.from({
          'id': item.id,
          'tempKey': 'item_${item.id}',
          'title': item.title,
          'priority': item.priority,
          'subTasks': normalizedSubTasks,
        }),
      );
    }

    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(loaded);
    });
  }

  void _addTask() {
    setState(() {
      _items.add(
        Map<String, Object?>.from({
          'tempKey': 'tmp_${DateTime.now().microsecondsSinceEpoch}',
          'title': '',
          'priority': 2,
          'subTasks': <Map<String, Object?>>[],
        }),
      );
    });
  }

  void _removeTask(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _reorderTasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _addSubTask(int taskIndex) {
    setState(() {
      (_items[taskIndex]['subTasks'] as List<Map<String, Object?>>).add(
        Map<String, Object?>.from({
          'title': '',
          'isCompleted': false,
        }),
      );
    });
  }

  void _removeSubTask(int taskIndex, int subIndex) {
    setState(() {
      (_items[taskIndex]['subTasks'] as List<Map<String, Object?>>).removeAt(subIndex);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
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

    final db = ref.read(databaseProvider);
    final notif = ref.read(notificationServiceProvider);
    final prefs = ref.read(notificationPreferencesProvider);

    setState(() => _isSaving = true);

    try {
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
          createdAt: Value(widget.routine.createdAt),
        ),
      );

      final keptItemIds = <int>{};
      final validItems = _items
          .where((item) => (item['title'] as String? ?? '').trim().isNotEmpty)
          .toList();

      for (int i = 0; i < validItems.length; i++) {
        final item = validItems[i];
        final itemTitle = (item['title'] as String).trim();
        final itemPriority = item['priority'] as int? ?? 2;
        int itemId;

        if (item['id'] is int) {
          itemId = item['id'] as int;
          await db.updateRoutineItem(
            RoutineItemsCompanion(
              id: Value(itemId),
              routineId: Value(widget.routine.id),
              title: Value(itemTitle),
              priority: Value(itemPriority),
              sortOrder: Value(i),
            ),
          );
        } else {
          itemId = await db.addRoutineItem(
            RoutineItemsCompanion(
              routineId: Value(widget.routine.id),
              title: Value(itemTitle),
              priority: Value(itemPriority),
              sortOrder: Value(i),
            ),
          );
        }
        keptItemIds.add(itemId);

        final existingSub = await db.watchRoutineSubTasks(itemId).first;
        for (final st in existingSub) {
          await db.deleteRoutineSubTask(st.id);
        }

        final subTasks = item['subTasks'] as List<Map<String, Object?>>;
        for (int s = 0; s < subTasks.length; s++) {
          final subTitle = (subTasks[s]['title'] as String? ?? '').trim();
          if (subTitle.isEmpty) continue;
          await db.addRoutineSubTask(
            RoutineSubTasksCompanion(
              routineItemId: Value(itemId),
              title: Value(subTitle),
              isCompleted: Value(false),
              sortOrder: Value(s),
              createdAt: Value(DateTime.now()),
            ),
          );
        }
      }

      final removed = _originalItemIds.difference(keptItemIds);
      for (final id in removed) {
        await db.deleteRoutineItem(id);
      }

      await notif.cancelRoutineReminders(widget.routine.id);
      final times = _reminderTimes.isEmpty ? <TimeOfDay>[prefs.routineReminderTime] : _reminderTimes;
      await notif.scheduleRoutineReminders(
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

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routine updated')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Edit Routine', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Routine name...')),
            const SizedBox(height: 10),
            TextField(controller: _descCtrl, decoration: const InputDecoration(hintText: 'Description (optional)...')),
            const SizedBox(height: 14),
            Text('Routine Priority', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
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
            const SizedBox(height: 14),
            Text('Repeat on', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((entry) {
                final day = entry.key + 1;
                final isSelected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () => setState(() {
                    isSelected ? _selectedDays.remove(day) : _selectedDays.add(day);
                  }),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: isSelected ? AppColors.primary : theme.colorScheme.outline),
                    ),
                    child: Center(
                      child: Text(
                        entry.value,
                        style: AppTypography.labelMedium.copyWith(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
              title: Text(
                _reminderTimes.isEmpty
                    ? 'Reminder Times (Optional)'
                    : 'Reminders: ${_reminderTimes.map((t) => t.format(context)).join(', ')}',
                style: AppTypography.bodyMedium,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_alarm_rounded),
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (picked == null || !mounted) return;
                  setState(() {
                    final exists = _reminderTimes.any((t) => t.hour == picked.hour && t.minute == picked.minute);
                    if (!exists) {
                      _reminderTimes.add(picked);
                      _reminderTimes.sort(
                        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
                      );
                    }
                  });
                },
              ),
            ),
            if (_reminderTimes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reminderTimes.asMap().entries.map((entry) {
                  return Chip(
                    label: Text(entry.value.format(context)),
                    onDeleted: () => setState(() => _reminderTimes.removeAt(entry.key)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Routine Tasks', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
                TextButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Task'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: _reorderTasks,
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final subTasks = item['subTasks'] as List<Map<String, Object?>>;

                return Container(
                  key: ValueKey(item['tempKey'] ?? 'task_$index'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.drag_indicator_rounded),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: item['title'] as String? ?? '',
                              onChanged: (v) => item['title'] = v,
                              decoration: const InputDecoration(
                                hintText: 'Task title...',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                            onPressed: () => _removeTask(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _PriorityChip(
                            label: 'Low',
                            color: AppColors.info,
                            isActive: (item['priority'] as int? ?? 2) == 1,
                            onTap: () => setState(() => item['priority'] = 1),
                          ),
                          const SizedBox(width: 8),
                          _PriorityChip(
                            label: 'Med',
                            color: AppColors.warning,
                            isActive: (item['priority'] as int? ?? 2) == 2,
                            onTap: () => setState(() => item['priority'] = 2),
                          ),
                          const SizedBox(width: 8),
                          _PriorityChip(
                            label: 'High',
                            color: AppColors.error,
                            isActive: (item['priority'] as int? ?? 2) == 3,
                            onTap: () => setState(() => item['priority'] = 3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtasks', style: AppTypography.labelMedium),
                          TextButton.icon(
                            onPressed: () => _addSubTask(index),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      ...List.generate(subTasks.length, (subIndex) {
                        final sub = subTasks[subIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right_rounded, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextFormField(
                                  initialValue: sub['title'] as String? ?? '',
                                  onChanged: (v) => sub['title'] = v,
                                  decoration: const InputDecoration(
                                    hintText: 'Subtask...',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => _removeSubTask(index, subIndex),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: Text(
                  _isSaving ? 'Saving...' : 'Save Changes',
                  style: AppTypography.labelLarge.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
