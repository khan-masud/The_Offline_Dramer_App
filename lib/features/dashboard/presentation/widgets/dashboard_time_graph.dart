import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../todo/data/todo_provider.dart';
import '../../../routine/data/routine_provider.dart';
import '../../../habits/data/habits_provider.dart';

class DashboardTimeGraph extends ConsumerWidget {
  const DashboardTimeGraph({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    // 1. Fetch Tasks Stats
    final todoStatsAsync = ref.watch(todoStatsProvider);
    int taskTotal = 0;
    int taskDone = 0;
    double taskPercent = 0.0;
    if (todoStatsAsync.valueOrNull != null) {
      final stats = todoStatsAsync.value!;
      taskTotal = stats.total;
      taskDone = stats.completed;
      if (taskTotal > 0) taskPercent = (taskDone / taskTotal).clamp(0.0, 1.0);
    }

    // 2. Fetch Routine Stats
    final routinesAsync = ref.watch(todayRoutinesProvider);
    final routineCompsAsync = ref.watch(todayCompletionsProvider);
    int routineTotal = 0;
    int routineDone = 0;
    double routinePercent = 0.0;
    if (routinesAsync.valueOrNull != null) {
      routineTotal = routinesAsync.value!.length;
      routineDone = routineCompsAsync.valueOrNull?.length ?? 0;
      if (routineTotal > 0) routinePercent = (routineDone / routineTotal).clamp(0.0, 1.0);
    }

    // 3. Fetch Habits Stats
    final habitsAsync = ref.watch(habitsProvider);
    final habitCompsAsync = ref.watch(todayHabitCompletionsProvider);
    int habitTotal = 0;
    int habitDone = 0;
    double habitPercent = 0.0;
    if (habitsAsync.valueOrNull != null) {
      habitTotal = habitsAsync.value!.length;
      habitDone = habitCompsAsync.valueOrNull?.map((c) => c.habitId).toSet().length ?? 0;
      if (habitTotal > 0) habitPercent = (habitDone / habitTotal).clamp(0.0, 1.0);
    }

    // Overall Consistency Score
    final overallDenominator = (taskTotal > 0 ? 1 : 0) + (routineTotal > 0 ? 1 : 0) + (habitTotal > 0 ? 1 : 0);
    final overallPercent = overallDenominator > 0
        ? ((taskPercent + routinePercent + habitPercent) / overallDenominator)
        : 0.0;
    final consistencyScore = (overallPercent * 100).toInt();

    // Current week dates (Monday to Sunday)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time & Consistency',
                  style: AppTypography.headingSmall.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Weekly momentum & pillar execution',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),

            // Consistency Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (consistencyScore >= 75
                        ? AppColors.success
                        : (consistencyScore >= 40 ? AppColors.warning : AppColors.primary))
                    .withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (consistencyScore >= 75
                          ? AppColors.success
                          : (consistencyScore >= 40 ? AppColors.warning : AppColors.primary))
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 14,
                    color: consistencyScore >= 75
                        ? AppColors.success
                        : (consistencyScore >= 40 ? AppColors.warning : AppColors.primary),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$consistencyScore% Score',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: consistencyScore >= 75
                          ? AppColors.success
                          : (consistencyScore >= 40 ? AppColors.warning : AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Main Consistency Card ──
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Weekly 7-Day Matrix Strip ──
              Text(
                'Weekly Rhythm (Mon — Sun)',
                style: AppTypography.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: weekDays.map((day) {
                  final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
                  final isPast = day.isBefore(DateTime(now.year, now.month, now.day));

                  return Container(
                    width: 38,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                          : (isPast
                              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday
                            ? AppColors.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.1),
                        width: isToday ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('E').format(day).substring(0, 1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isToday ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? AppColors.primary
                                : (isPast ? AppColors.success.withValues(alpha: 0.6) : Colors.transparent),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),
              Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
              ),
              const SizedBox(height: 14),

              // ── 3 Execution Pillars ──
              _PillarRow(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.primary,
                label: 'Tasks Follow-up',
                countText: taskTotal > 0 ? '$taskDone of $taskTotal' : 'No tasks',
                percent: taskPercent,
              ),
              const SizedBox(height: 12),

              _PillarRow(
                icon: Icons.bolt_rounded,
                color: AppColors.purple,
                label: 'Daily Routines',
                countText: routineTotal > 0 ? '$routineDone of $routineTotal' : 'No routines',
                percent: routinePercent,
              ),
              const SizedBox(height: 12),

              _PillarRow(
                icon: Icons.trending_up_rounded,
                color: AppColors.teal,
                label: 'Habits Kept',
                countText: habitTotal > 0 ? '$habitDone of $habitTotal' : 'No habits',
                percent: habitPercent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PillarRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String countText;
  final double percent;

  const _PillarRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.countText,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentInt = (percent * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              countText,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$percentInt%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 5,
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
