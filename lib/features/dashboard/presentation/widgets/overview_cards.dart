import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/main_shell.dart';
import '../../../todo/data/todo_provider.dart';
import '../../../routine/data/routine_provider.dart';
import '../../../money/data/money_provider.dart';
import '../../../notes/data/notes_provider.dart';

class OverviewCards extends ConsumerWidget {
  const OverviewCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final todoStatsAsync = ref.watch(todoStatsProvider);
    final todayRoutinesAsync = ref.watch(todayRoutinesProvider);
    final completionsAsync = ref.watch(todayCompletionsProvider);
    final todaySpentAsync = ref.watch(todaySpentProvider);
    final notesAsync = ref.watch(notesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today\'s Overview', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: [
            Expanded(
              child: todoStatsAsync.when(
                data: (stats) => _StatCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.primary,
                  iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                  title: 'Tasks',
                  value: '${stats.pending}',
                  subtitle: 'pending',
                  onTap: () => MainShellController.of(context)?.switchTab(1),
                ),
                loading: () => _StatCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.primary,
                  iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                  title: 'Tasks',
                  value: '...',
                  subtitle: 'loading',
                  onTap: () => MainShellController.of(context)?.switchTab(1),
                ),
                error: (e, _) => _StatCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.primary,
                  iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                  title: 'Tasks',
                  value: '!',
                  subtitle: 'error',
                  onTap: () => MainShellController.of(context)?.switchTab(1),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: _buildRoutineCard(todayRoutinesAsync, completionsAsync, ref, context),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: [
            Expanded(
              child: todaySpentAsync.when(
                data: (spent) => _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.warning,
                  iconBgColor: AppColors.warning.withValues(alpha: 0.1),
                  title: 'Spent Today',
                  value: '$currencySymbol${spent.toStringAsFixed(0)}',
                  subtitle: spent > 0 ? 'today' : 'nothing',
                  onTap: () => MainShellController.of(context)?.switchTab(3),
                ),
                loading: () => _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.warning,
                  iconBgColor: AppColors.warning.withValues(alpha: 0.1),
                  title: 'Spent Today',
                  value: '...',
                  subtitle: 'loading',
                  onTap: () => MainShellController.of(context)?.switchTab(3),
                ),
                error: (_, __) => _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.warning,
                  iconBgColor: AppColors.warning.withValues(alpha: 0.1),
                  title: 'Spent Today',
                  value: '!',
                  subtitle: 'error',
                  onTap: () => MainShellController.of(context)?.switchTab(3),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: notesAsync.when(
                data: (notes) => _StatCard(
                  icon: Icons.note_alt_outlined,
                  iconColor: AppColors.teal,
                  iconBgColor: AppColors.teal.withValues(alpha: 0.1),
                  title: 'Notes',
                  value: '${notes.length}',
                  subtitle: notes.isEmpty ? 'none yet' : 'total',
                  onTap: () => Navigator.of(context).pushNamed('/notes'),
                ),
                loading: () => _StatCard(
                  icon: Icons.note_alt_outlined,
                  iconColor: AppColors.teal,
                  iconBgColor: AppColors.teal.withValues(alpha: 0.1),
                  title: 'Notes',
                  value: '...',
                  subtitle: 'loading',
                  onTap: () => Navigator.of(context).pushNamed('/notes'),
                ),
                error: (_, __) => _StatCard(
                  icon: Icons.note_alt_outlined,
                  iconColor: AppColors.teal,
                  iconBgColor: AppColors.teal.withValues(alpha: 0.1),
                  title: 'Notes',
                  value: '!',
                  subtitle: 'error',
                  onTap: () => Navigator.of(context).pushNamed('/notes'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoutineCard(
    AsyncValue<List<dynamic>> routinesAsync,
    AsyncValue<List<dynamic>> completionsAsync,
    WidgetRef ref,
    BuildContext context,
  ) {
    return routinesAsync.when(
      data: (routines) {
        // For simplicity, count total routine items for today and how many are completed
        return completionsAsync.when(
          data: (completions) {
            final totalRoutines = routines.length;
            // We need the actual items count; for dashboard we show routine count
            final completedCount = completions.length;
            return _StatCard(
              icon: Icons.loop_rounded,
              iconColor: AppColors.success,
              iconBgColor: AppColors.success.withValues(alpha: 0.1),
              title: 'Routines',
              value: '$totalRoutines',
              subtitle: '$completedCount items done',
              onTap: () => MainShellController.of(context)?.switchTab(2),
            );
          },
          loading: () => _StatCard(
            icon: Icons.loop_rounded,
            iconColor: AppColors.success,
            iconBgColor: AppColors.success.withValues(alpha: 0.1),
            title: 'Routines',
            value: '...',
            subtitle: 'loading',
            onTap: () => MainShellController.of(context)?.switchTab(2),
          ),
          error: (_, __) => _StatCard(
            icon: Icons.loop_rounded,
            iconColor: AppColors.success,
            iconBgColor: AppColors.success.withValues(alpha: 0.1),
            title: 'Routines',
            value: '!',
            subtitle: 'error',
            onTap: () => MainShellController.of(context)?.switchTab(2),
          ),
        );
      },
      loading: () => _StatCard(
        icon: Icons.loop_rounded,
        iconColor: AppColors.success,
        iconBgColor: AppColors.success.withValues(alpha: 0.1),
        title: 'Routines',
        value: '...',
        subtitle: 'loading',
        onTap: () => MainShellController.of(context)?.switchTab(2),
      ),
      error: (_, __) => _StatCard(
        icon: Icons.loop_rounded,
        iconColor: AppColors.success,
        iconBgColor: AppColors.success.withValues(alpha: 0.1),
        title: 'Routines',
        value: '!',
        subtitle: 'error',
        onTap: () => MainShellController.of(context)?.switchTab(2),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text(title, style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
          Text(subtitle, style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
