import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../todo/data/todo_provider.dart';
import '../../../routine/data/routine_provider.dart';
import '../../../habits/data/habits_provider.dart';

class DashboardTimeGraph extends ConsumerWidget {
  const DashboardTimeGraph({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    // Fetch Tasks Data
    final todoStatsAsync = ref.watch(todoStatsProvider);
    double taskPercent = 0.0;
    if (todoStatsAsync.valueOrNull != null) {
      final stats = todoStatsAsync.value!;
      if (stats.total > 0) taskPercent = stats.completed / stats.total;
    }

    // Fetch Routine Data 
    final routinesAsync = ref.watch(todayRoutinesProvider);
    final routineCompsAsync = ref.watch(todayCompletionsProvider);
    double routinePercent = 0.0;
    if (routinesAsync.valueOrNull != null) {
      final total = routinesAsync.value!.length;
      final done = routineCompsAsync.valueOrNull?.length ?? 0;
      if (total > 0) routinePercent = (done / total).clamp(0.0, 1.0);
    }
    
    // Fetch Habits Data
    final habitsAsync = ref.watch(habitsProvider);
    final habitCompsAsync = ref.watch(todayHabitCompletionsProvider);
    double habitPercent = 0.0;
    if (habitsAsync.valueOrNull != null) {
      final total = habitsAsync.value!.length;
      final doneCount = habitCompsAsync.valueOrNull?.map((c) => c.habitId).toSet().length ?? 0;
      if (total > 0) habitPercent = (doneCount / total).clamp(0.0, 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time & Consistency', 
          style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)
        ),
        const SizedBox(height: AppDimensions.md),
        
        AppCard(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Focus Distribution',
                style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    radarBorderData: const BorderSide(color: Colors.transparent),
                    gridBorderData: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
                    tickBorderData: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
                    ticksTextStyle: const TextStyle(color: Colors.transparent),
                    tickCount: 4,
                    getTitle: (index, angle) {
                      switch (index) {
                        case 0:
                          return RadarChartTitle(
                            text: 'Tasks\n${(taskPercent * 100).toInt()}%',
                            positionPercentageOffset: 0.1,
                          );
                        case 1:
                          return RadarChartTitle(
                            text: 'Routine\n${(routinePercent * 100).toInt()}%',
                            positionPercentageOffset: 0.2,
                          );
                        case 2:
                          return RadarChartTitle(
                            text: 'Habits\n${(habitPercent * 100).toInt()}%',
                            positionPercentageOffset: 0.2,
                          );
                        default:
                          return const RadarChartTitle(text: '');
                      }
                    },
                    titleTextStyle: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    dataSets: [
                      RadarDataSet(
                        fillColor: AppColors.primary.withValues(alpha: 0.2),
                        borderColor: AppColors.primary,
                        entryRadius: 4,
                        dataEntries: [
                          RadarEntry(value: taskPercent > 0 ? taskPercent : 0.01),
                          RadarEntry(value: routinePercent > 0 ? routinePercent : 0.01),
                          RadarEntry(value: habitPercent > 0 ? habitPercent : 0.01),
                        ],
                        borderWidth: 2,
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Simple progress bars to supplement
              _buildProgressBar('Tasks Follow-up', taskPercent, AppColors.primary, theme),
              const SizedBox(height: 12),
              _buildProgressBar('Routine Check', routinePercent, AppColors.success, theme),
              const SizedBox(height: 12),
              _buildProgressBar('Habits Kept', habitPercent, AppColors.purple, theme),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildProgressBar(String label, double percent, Color color, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.labelSmall),
            Text('${(percent * 100).toInt()}%', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percent,
          color: color,
          backgroundColor: color.withValues(alpha: 0.1),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
