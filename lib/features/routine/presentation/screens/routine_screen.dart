import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/routine_provider.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final todayRoutinesAsync = ref.watch(todayRoutinesProvider);

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
                  if (routines.isEmpty) return _emptyState(context, ref);
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: routines.length,
                    itemBuilder: (ctx, i) => _RoutineSection(routine: routines[i])
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

  Widget _emptyState(BuildContext context, WidgetRef ref) {
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
          Text('No routines for today', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Tap + to create a routine', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showAddRoutine(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final selectedDays = <int>{DateTime.now().weekday};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          return Container(
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('New Routine', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Routine name...')),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'Description (optional)...')),
                  const SizedBox(height: 16),
                  Text('Repeat on', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                      final day = e.key + 1;
                      final isSelected = selectedDays.contains(day);
                      return GestureDetector(
                        onTap: () => setSheetState(() {
                          isSelected ? selectedDays.remove(day) : selectedDays.add(day);
                        }),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            border: Border.all(color: isSelected ? AppColors.primary : theme.colorScheme.outline),
                          ),
                          child: Center(
                            child: Text(e.value, style: AppTypography.labelMedium.copyWith(
                              color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                            )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Routine name is required')),
                          );
                          return;
                        }
                        if (selectedDays.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Select at least one day')),
                          );
                          return;
                        }

                        try {
                          final db = ref.read(databaseProvider);
                          await db.addRoutine(RoutinesCompanion(
                            title: Value(titleCtrl.text.trim()),
                            description: Value(descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim()),
                            days: Value(([...selectedDays]..sort()).join(',')),
                            createdAt: Value(DateTime.now()),
                          ));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Routine saved')),
                            );
                          }
                        } catch (_) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Failed to save routine')),
                            );
                          }
                        }
                      },
                      child: Text('Create Routine', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showManageRoutines(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ManageRoutinesScreen()));
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
                      Text(routine.title, style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
                      if (routine.description != null)
                        Text(routine.description!, style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
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
                    final completedIds = completions.map((c) => c.routineItemId).toSet();
                    final completed = items.where((i) => completedIds.contains(i.id)).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: items.isEmpty ? 0 : completed / items.length,
                            backgroundColor: theme.colorScheme.outline,
                            color: AppColors.success,
                            minHeight: 6,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('$completed/${items.length} completed', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                        const SizedBox(height: 4),
                        ...items.map((item) {
                          final isDone = completedIds.contains(item.id);
                          return _RoutineItemTile(
                            item: item,
                            isDone: isDone,
                            onToggle: () async {
                              final db = ref.read(databaseProvider);
                              if (isDone) {
                                await db.unmarkRoutineItemCompleted(item.id);
                              } else {
                                await db.markRoutineItemCompleted(item.id);
                              }
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
      ),
    );
  }

  void _addItem(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Routine Item'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Item name...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final db = ref.read(databaseProvider);
              await db.addRoutineItem(RoutineItemsCompanion(
                routineId: Value(routine.id),
                title: Value(ctrl.text.trim()),
                sortOrder: Value(0),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _RoutineItemTile extends StatelessWidget {
  final RoutineItem item;
  final bool isDone;
  final VoidCallback onToggle;
  const _RoutineItemTile({required this.item, required this.isDone, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppColors.success : Colors.transparent,
                border: Border.all(color: isDone ? AppColors.success : theme.colorScheme.onSurfaceVariant, width: 2),
              ),
              child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDone ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (item.startTime != null)
              Text(item.startTime!, style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
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
        data: (routines) {
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
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      onPressed: () => ref.read(databaseProvider).deleteRoutine(r.id),
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

  String _formatDays(String days) {
    const names = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return days.split(',').map((d) => names[int.tryParse(d)] ?? d).join(', ');
  }
}
