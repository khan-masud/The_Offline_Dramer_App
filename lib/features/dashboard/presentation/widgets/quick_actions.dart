import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../todo/presentation/screens/todo_screen.dart' show AddEditTodoSheet;
import '../../../money/presentation/widgets/add_transaction_sheet.dart';
import '../../../notes/presentation/screens/note_editor_screen.dart';
import '../../../diary/presentation/screens/diary_editor_screen.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTypography.headingSmall.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // + Task
              _ActionTile(
                icon: Icons.add_task_rounded,
                label: 'Add Task',
                color: AppColors.primary,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddEditTodoSheet(),
                  );
                },
              ),
              const SizedBox(width: 10),

              // + Expense
              _ActionTile(
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
              const SizedBox(width: 10),

              // + Diary
              _ActionTile(
                icon: Icons.menu_book_rounded,
                label: 'Write Diary',
                color: AppColors.purple,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DiaryEditorScreen()),
                  );
                },
              ),
              const SizedBox(width: 10),

              // + Note
              _ActionTile(
                icon: Icons.note_add_outlined,
                label: 'New Note',
                color: AppColors.teal,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                  );
                },
              ),
              const SizedBox(width: 10),

              // ⏱ Focus Timer
              _ActionTile(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Focus Timer',
                color: AppColors.error,
                onTap: () {
                  Navigator.of(context).pushNamed('/pomodoro');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.25 : 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
