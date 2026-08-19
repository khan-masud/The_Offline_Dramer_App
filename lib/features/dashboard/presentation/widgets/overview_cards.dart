import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/main_shell.dart';
import '../../../todo/data/todo_provider.dart';
import '../../../routine/data/routine_provider.dart';
import '../../../money/data/money_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../diary/data/diary_provider.dart';

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
    final diaryAsync = ref.watch(diaryEntriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Overview',
          style: AppTypography.headingSmall.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // ── 2x2 Bento-Grid ──
        Row(
          children: [
            // 1. Tasks Bento Card
            Expanded(
              child: todoStatsAsync.when(
                data: (stats) {
                  final total = stats.total;
                  final completed = stats.completed;
                  final pending = stats.pending;
                  final fraction = total > 0 ? completed / total : 0.0;

                  return _BentoStatCard(
                    title: 'Pending Tasks',
                    value: '$pending',
                    subtitle: '$completed completed',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.primary,
                    progressFraction: fraction,
                    onTap: () => MainShellController.of(context)?.switchTab(1),
                  );
                },
                loading: () => const _BentoLoadingCard(),
                error: (_, __) => const _BentoErrorCard(),
              ),
            ),
            const SizedBox(width: 12),

            // 2. Habits & Routines Bento Card
            Expanded(
              child: _buildRoutineCard(todayRoutinesAsync, completionsAsync, context),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            // 3. Money Spent Bento Card
            Expanded(
              child: todaySpentAsync.when(
                data: (spent) {
                  return _BentoStatCard(
                    title: 'Spent Today',
                    value: '$currencySymbol${spent.toStringAsFixed(0)}',
                    subtitle: spent > 0 ? 'Today\'s outflow' : 'Zero spending',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.warning,
                    progressFraction: null,
                    onTap: () => MainShellController.of(context)?.switchTab(3),
                  );
                },
                loading: () => const _BentoLoadingCard(),
                error: (_, __) => const _BentoErrorCard(),
              ),
            ),
            const SizedBox(width: 12),

            // 4. Notes & Diary Bento Card
            Expanded(
              child: _buildNotesDiaryCard(notesAsync, diaryAsync, context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoutineCard(
    AsyncValue<List<dynamic>> routinesAsync,
    AsyncValue<List<dynamic>> completionsAsync,
    BuildContext context,
  ) {
    return routinesAsync.when(
      data: (routines) {
        return completionsAsync.when(
          data: (completions) {
            final total = routines.length;
            final completed = completions.length;
            final fraction = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

            return _BentoStatCard(
              title: 'Habits & Routines',
              value: '$completed / $total',
              subtitle: total == 0 ? 'No routines' : (completed == total ? 'All completed!' : '${total - completed} remaining'),
              icon: Icons.bolt_rounded,
              color: AppColors.purple,
              progressFraction: fraction,
              onTap: () => MainShellController.of(context)?.switchTab(2),
            );
          },
          loading: () => const _BentoLoadingCard(),
          error: (_, __) => const _BentoErrorCard(),
        );
      },
      loading: () => const _BentoLoadingCard(),
      error: (_, __) => const _BentoErrorCard(),
    );
  }

  Widget _buildNotesDiaryCard(
    AsyncValue<List<dynamic>> notesAsync,
    AsyncValue<List<dynamic>> diaryAsync,
    BuildContext context,
  ) {
    final noteCount = notesAsync.valueOrNull?.length ?? 0;
    final diaryCount = diaryAsync.valueOrNull?.length ?? 0;
    final totalEntries = noteCount + diaryCount;

    return _BentoStatCard(
      title: 'Notes & Diary',
      value: '$totalEntries',
      subtitle: '$diaryCount diary • $noteCount notes',
      icon: Icons.auto_stories_outlined,
      color: AppColors.teal,
      progressFraction: null,
      onTap: () => Navigator.of(context).pushNamed('/diary'),
    );
  }
}

// ────────────────── BENTO STAT CARD ──────────────────

class _BentoStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double? progressFraction;
  final VoidCallback onTap;

  const _BentoStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progressFraction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.22 : 0.14),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Icon + Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title Label
              Text(
                title,
                style: AppTypography.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Large Stat Value
              Text(
                value,
                style: AppTypography.headingMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Optional Linear Progress Track
              if (progressFraction != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoLoadingCard extends StatelessWidget {
  const _BentoLoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _BentoErrorCard extends StatelessWidget {
  const _BentoErrorCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(Icons.error_outline_rounded, size: 20, color: theme.colorScheme.error),
      ),
    );
  }
}
