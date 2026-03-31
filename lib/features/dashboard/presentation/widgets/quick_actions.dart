import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/main_shell.dart';
import '../../../notes/presentation/screens/note_editor_screen.dart';
import '../../../money/presentation/widgets/add_transaction_sheet.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
        const SizedBox(height: AppDimensions.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _ActionChip(
                icon: Icons.add_task_rounded,
                label: 'Add Task',
                color: AppColors.primary,
                onTap: () {
                  MainShellController.of(context)?.switchTab(1);
                },
              ),
              const SizedBox(width: AppDimensions.sm),
              _ActionChip(
                icon: Icons.receipt_long_outlined,
                label: 'Add Expense',
                color: AppColors.warning,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddTransactionSheet(),
                  );
                },
              ),
              const SizedBox(width: AppDimensions.sm),
              _ActionChip(
                icon: Icons.note_add_outlined,
                label: 'New Note',
                color: AppColors.success,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                  );
                },
              ),
              const SizedBox(width: AppDimensions.sm),
              _ActionChip(
                icon: Icons.timer_outlined,
                label: 'Start Timer',
                color: AppColors.purple,
                onTap: () {
                  Navigator.of(context).pushNamed('/stopwatch');
                },
              ),
              const SizedBox(width: AppDimensions.sm),
              _ActionChip(
                icon: Icons.link_rounded,
                label: 'Save Link',
                color: AppColors.teal,
                onTap: () {
                  Navigator.of(context).pushNamed('/links');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(color: theme.colorScheme.outline, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(label, style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
