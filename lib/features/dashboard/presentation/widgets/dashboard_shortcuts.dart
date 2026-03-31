import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

class DashboardShortcuts extends StatelessWidget {
  const DashboardShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore App', 
          style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)
        ),
        const SizedBox(height: AppDimensions.md),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: AppDimensions.sm,
          crossAxisSpacing: AppDimensions.sm,
          childAspectRatio: 1.1,
          children: [
            _ShortcutItem(
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).pushNamed('/calendar'),
            ),
            _ShortcutItem(
              icon: Icons.track_changes_outlined,
              label: 'Habits',
              color: AppColors.purple,
              onTap: () => Navigator.of(context).pushNamed('/habits'),
            ),
            _ShortcutItem(
              icon: Icons.self_improvement_outlined,
              label: 'Pomodoro',
              color: AppColors.error,
              onTap: () => Navigator.of(context).pushNamed('/pomodoro'),
            ),
            _ShortcutItem(
              icon: Icons.manage_accounts_outlined,
              label: 'Profile',
              color: AppColors.info,
              onTap: () => Navigator.of(context).pushNamed('/settings'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurface, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
