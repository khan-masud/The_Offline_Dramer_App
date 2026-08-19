import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../data/routine_provider.dart';

class RoutineHeatmapSheet extends ConsumerStatefulWidget {
  final Routine routine;

  const RoutineHeatmapSheet({super.key, required this.routine});

  @override
  ConsumerState<RoutineHeatmapSheet> createState() => _RoutineHeatmapSheetState();
}

class _RoutineHeatmapSheetState extends ConsumerState<RoutineHeatmapSheet> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  Color _getCellColor(double rate, bool isDark) {
    if (rate == 0.0) {
      return isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    } else if (rate < 0.4) {
      return AppColors.success.withValues(alpha: 0.25);
    } else if (rate < 0.8) {
      return AppColors.success.withValues(alpha: 0.6);
    } else {
      return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final heatmapAsync = ref.watch(
      routineMonthlyHeatmapProvider((
        routineId: widget.routine.id,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      )),
    );

    final streakAsync = ref.watch(routineStreakProvider(widget.routine));
    final streak = streakAsync.valueOrNull ?? 0;

    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstDayWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday; // 1=Mon, 7=Sun

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.routine.title,
                      style: AppTypography.headingMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Consistency Heatmap',
                      style: AppTypography.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Streak & Summary Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_fire_department_rounded, color: AppColors.orange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Streak', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          Text('$streak Days', style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                        ],
                      ),
                    ],
                  ),
                  heatmapAsync.maybeWhen(
                    data: (rates) {
                      final completedDays = rates.values.where((r) => r >= 0.99).length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Perfect Days', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          Text('$completedDays / $daysInMonth', style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Month Navigation Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _previousMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _nextMonth,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Day-of-week headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
                return SizedBox(
                  width: 36,
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 8),

            // Heatmap Calendar Grid
            heatmapAsync.when(
              data: (rates) {
                final totalSlots = ((daysInMonth + firstDayWeekday - 1) / 7).ceil() * 7;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: totalSlots,
                  itemBuilder: (context, index) {
                    final dayNumber = index - (firstDayWeekday - 2);
                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const SizedBox.shrink();
                    }

                    final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber);
                    final rate = rates[date] ?? 0.0;
                    final isToday = DateUtils.isSameDay(date, DateTime.now());
                    final cellColor = _getCellColor(rate, isDark);

                    return Container(
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: AppColors.primary, width: 2)
                            : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday || rate > 0.5 ? FontWeight.bold : FontWeight.normal,
                            color: rate >= 0.8
                                ? Colors.white
                                : (isToday ? AppColors.primary : theme.colorScheme.onSurface),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error loading history: $e')),
            ),

            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Less', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(width: 6),
                ...[0.0, 0.3, 0.6, 1.0].map((r) => Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _getCellColor(r, isDark),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
                const SizedBox(width: 6),
                Text('More', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
