import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('More', style: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text('All your tools in one place', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppDimensions.xl),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppDimensions.md,
                  crossAxisSpacing: AppDimensions.md,
                  childAspectRatio: 0.95,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _ModuleCard(icon: Icons.note_alt_outlined, label: 'Notes', color: AppColors.teal, route: '/notes'),
                    _ModuleCard(icon: Icons.link_rounded, label: 'Links', color: AppColors.info, route: '/links'),
                    _ModuleCard(icon: Icons.timer_outlined, label: 'Stopwatch', color: AppColors.orange, route: '/stopwatch'),
                    _ModuleCard(icon: Icons.hourglass_bottom_rounded, label: 'Pomodoro', color: AppColors.error, route: '/pomodoro'),
                    _ModuleCard(icon: Icons.trending_up_rounded, label: 'Habits', color: AppColors.purple, route: '/habits'),
                    _ModuleCard(icon: Icons.calendar_month_rounded, label: 'Calendar', color: AppColors.pink, route: '/calendar'),
                    _ModuleCard(icon: Icons.cake_outlined, label: 'Birthdays', color: AppColors.pink, route: '/birthdays'),
                    _ModuleCard(icon: Icons.contact_phone_outlined, label: 'Contacts', color: AppColors.info, route: '/contacts'),
                    _ModuleCard(icon: Icons.handshake_outlined, label: 'Debts', color: AppColors.orange, route: '/debts'),
                    _ModuleCard(icon: Icons.cloud_upload_outlined, label: 'Backup', color: AppColors.primary, route: '/settings'),
                    _ModuleCard(icon: Icons.settings_outlined, label: 'Settings', color: AppColors.lightTextSecondary, route: '/settings'),
                  ].asMap().entries.map((e) {
                    return e.value.animate().fadeIn(delay: (100 * e.key).ms, duration: 400.ms).scale(
                      begin: const Offset(0.9, 0.9),
                      delay: (100 * e.key).ms,
                      duration: 400.ms,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(route),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
