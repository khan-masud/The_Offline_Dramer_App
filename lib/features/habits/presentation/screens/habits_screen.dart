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
import '../../data/habits_provider.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final habitsAsync = ref.watch(habitsProvider);
    final completionsAsync = ref.watch(todayHabitCompletionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        centerTitle: false,
      ),
      body: habitsAsync.when(
        data: (habits) {
          if (habits.isEmpty) return _emptyState(context);
          return completionsAsync.when(
            data: (completions) {
              final completedIds = completions.map((c) => c.habitId).toSet();
              final completedCount = habits.where((h) => completedIds.contains(h.id)).length;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Today's progress
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('📊', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Text("Today's Progress", style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
                                const Spacer(),
                                Text(
                                  '$completedCount/${habits.length}',
                                  style: AppTypography.headingSmall.copyWith(
                                    color: completedCount == habits.length ? AppColors.success : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: habits.isEmpty ? 0 : completedCount / habits.length,
                                backgroundColor: theme.colorScheme.outline,
                                color: completedCount == habits.length ? AppColors.success : AppColors.primary,
                                minHeight: 8,
                              ),
                            ),
                            if (completedCount == habits.length && habits.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Text('🎉 All habits done today!', style: AppTypography.labelMedium.copyWith(color: AppColors.success)),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                  ),
                  // Habit list
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final habit = habits[i];
                          final isDone = completedIds.contains(habit.id);
                          return _HabitCard(
                            habit: habit,
                            isDone: isDone,
                            onToggle: () async {
                              final db = ref.read(databaseProvider);
                              if (isDone) {
                                await db.unmarkHabitCompleted(habit.id);
                              } else {
                                await db.markHabitCompleted(habit.id);
                              }
                              // Invalidate streak
                              ref.invalidate(habitStreakProvider(habit.id));
                            },
                            onDelete: () => ref.read(databaseProvider).deleteHabit(habit.id),
                          ).animate().fadeIn(delay: (80 * i).ms, duration: 300.ms);
                        },
                        childCount: habits.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'habits_fab',
        onPressed: () => _showAddHabitSheet(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.trending_up_rounded, size: 48, color: AppColors.purple),
          ),
          const SizedBox(height: 20),
          Text('No habits tracked', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Tap + to create your first habit', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showAddHabitSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddHabitSheet(),
    );
  }
}

// ==================== HABIT CARD ====================
class _HabitCard extends ConsumerWidget {
  final Habit habit;
  final bool isDone;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _HabitCard({
    required this.habit,
    required this.isDone,
    required this.onToggle,
    required this.onDelete,
  });

  Color _getHabitColor() {
    switch (habit.color) {
      case 'success': return AppColors.success;
      case 'error': return AppColors.error;
      case 'warning': return AppColors.warning;
      case 'purple': return AppColors.purple;
      case 'teal': return AppColors.teal;
      case 'orange': return AppColors.orange;
      case 'pink': return AppColors.pink;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streakAsync = ref.watch(habitStreakProvider(habit.id));
    final color = _getHabitColor();

    return Dismissible(
      key: ValueKey(habit.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          onTap: onToggle,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // Emoji + completion indicator
              AnimatedContainer(
                duration: 300.ms,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDone ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: isDone ? color : color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check_rounded, color: color, size: 24)
                      : Text(habit.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              // Title + target
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: AppTypography.bodyLarge.copyWith(
                        color: isDone ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${habit.targetDaysPerWeek}x per week',
                      style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Streak
              streakAsync.when(
                data: (streak) {
                  if (streak == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('$streak', style: AppTypography.labelMedium.copyWith(color: AppColors.warning)),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ADD HABIT SHEET ====================
class _AddHabitSheet extends ConsumerStatefulWidget {
  const _AddHabitSheet();

  @override
  ConsumerState<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends ConsumerState<_AddHabitSheet> {
  final _titleCtrl = TextEditingController();
  String _emoji = '🎯';
  int _targetDays = 7;
  String _color = 'primary';

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.addHabit(HabitsCompanion(
      title: Value(_titleCtrl.text.trim()),
      emoji: Value(_emoji),
      targetDaysPerWeek: Value(_targetDays),
      color: Value(_color),
      createdAt: Value(DateTime.now()),
    ));
    if (mounted) Navigator.pop(context);
  }

  Color _getColor(String name) {
    switch (name) {
      case 'success': return AppColors.success;
      case 'error': return AppColors.error;
      case 'warning': return AppColors.warning;
      case 'purple': return AppColors.purple;
      case 'teal': return AppColors.teal;
      case 'orange': return AppColors.orange;
      case 'pink': return AppColors.pink;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('New Habit', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            // Title  
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Habit name...'),
              style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            // Emoji picker
            Text('Icon', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: habitEmojis.map((e) {
                final isActive = _emoji == e;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isActive ? _getColor(_color).withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: isActive ? _getColor(_color) : theme.colorScheme.outline),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Color picker
            Text('Color', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              children: ['primary', 'success', 'error', 'warning', 'purple', 'teal', 'orange', 'pink'].map((c) {
                final isActive = _color == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _getColor(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? theme.colorScheme.onSurface : Colors.transparent,
                          width: isActive ? 3 : 0,
                        ),
                      ),
                      child: isActive ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Target days
            Text('Goal', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (i) {
                final days = i + 1;
                final isActive = _targetDays == days;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _targetDays = days),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? _getColor(_color).withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          border: Border.all(color: isActive ? _getColor(_color) : theme.colorScheme.outline),
                        ),
                        child: Center(
                          child: Text(
                            '${days}x',
                            style: AppTypography.labelMedium.copyWith(
                              color: isActive ? _getColor(_color) : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _targetDays == 7 ? 'Every day' : '$_targetDays days per week',
                style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Create Habit', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
