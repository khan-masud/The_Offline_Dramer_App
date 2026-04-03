import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/providers/activity_log_provider.dart';

// Provider that merges DB-based activity with the activity log
final recentActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final activityLog = ref.watch(activityLogProvider);
  return activityLog.take(8).map((entry) {
    return {
      'type': entry.entityType,
      'title': entry.displayTitle,
      'time': entry.timestamp,
      'icon': entry.icon,
    };
  }).toList();
});

class RecentActivity extends ConsumerWidget {
  const RecentActivity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activityAsync = ref.watch(recentActivityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: AppTypography.headingSmall.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        activityAsync.when(
          data: (activities) {
            if (activities.isEmpty) return _emptyState(theme);
            return AppCard(
              padding: const EdgeInsets.all(0),
              child: Column(
                children:
                    activities.asMap().entries.map((e) {
                      final a = e.value;
                      final isFirst = e.key == 0;
                      final isLast = e.key == activities.length - 1;
                      return Column(
                        children: [
                          if (!isFirst)
                            Divider(
                              height: 1,
                              color: theme.colorScheme.outline,
                            ),
                          _ActivityItem(
                            icon: _getIcon(a['icon'] as String),
                            iconColor: _getColor(a['icon'] as String),
                            title: a['title'] as String,
                            subtitle: _getSubtitle(a['type'] as String),
                            time: _formatTime(a['time'] as DateTime),
                            isFirst: isFirst,
                            isLast: isLast,
                          ),
                        ],
                      );
                    }).toList(),
              ),
            );
          },
          loading:
              () => AppCard(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: const Center(child: CircularProgressIndicator()),
              ),
          error: (_, __) => _emptyState(theme),
        ),
      ],
    );
  }

  Widget _emptyState(ThemeData theme) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'No recent activity yet',
              style: AppTypography.bodyLarge.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String icon) {
    switch (icon) {
      case 'add_task':
        return Icons.add_task_rounded;
      case 'note':
        return Icons.note_alt_outlined;
      case 'income':
        return Icons.arrow_downward_rounded;
      case 'expense':
        return Icons.arrow_upward_rounded;
      case 'update':
        return Icons.edit_rounded;
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'routine':
        return Icons.replay_rounded;
      case 'habit':
        return Icons.trending_up_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.circle;
    }
  }

  Color _getColor(String icon) {
    switch (icon) {
      case 'add_task':
        return AppColors.primary;
      case 'note':
        return AppColors.teal;
      case 'income':
        return AppColors.success;
      case 'expense':
        return AppColors.error;
      case 'update':
        return AppColors.info;
      case 'delete':
        return AppColors.error;
      case 'routine':
        return AppColors.purple;
      case 'habit':
        return AppColors.orange;
      case 'link':
        return AppColors.purple;
      default:
        return AppColors.info;
    }
  }

  String _getSubtitle(String type) {
    switch (type) {
      case 'task':
        return 'Task';
      case 'note':
        return 'Note';
      case 'transaction':
        return 'Transaction';
      case 'routine':
        return 'Routine';
      case 'habit':
        return 'Habit';
      case 'link':
        return 'Link';
      default:
        return '';
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}';
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isFirst;
  final bool isLast;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.base,
        right: AppDimensions.base,
        top: isFirst ? AppDimensions.base : AppDimensions.md,
        bottom: isLast ? AppDimensions.base : AppDimensions.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: AppTypography.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
