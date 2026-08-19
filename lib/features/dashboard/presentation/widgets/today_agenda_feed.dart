import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/main_shell.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../todo/data/todo_provider.dart';
import '../../../routine/data/routine_provider.dart';
import '../../../birthday/data/birthday_provider.dart';

class TodayAgendaFeed extends ConsumerWidget {
  const TodayAgendaFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    final allTodosAsync = ref.watch(allTodosStreamProvider);
    final routinesAsync = ref.watch(todayRoutinesProvider);
    final completionsAsync = ref.watch(todayCompletionsProvider);
    final birthdaysAsync = ref.watch(birthdaysProvider);

    // Filter today's pending todos (top 3)
    final pendingTodos = allTodosAsync.valueOrNull?.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return true;
          return t.dueDate!.year == now.year &&
              t.dueDate!.month == now.month &&
              t.dueDate!.day == now.day;
        }).take(3).toList() ??
        [];

    // Check if any birthday today
    final todayBirthdays = birthdaysAsync.valueOrNull?.where((b) {
          return b.dateOfBirth.month == now.month && b.dateOfBirth.day == now.day;
        }).toList() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Focus & Agenda",
              style: AppTypography.headingSmall.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => MainShellController.of(context)?.switchTab(1),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Birthday Alert Card (If any today) ──
        if (todayBirthdays.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pink.withValues(alpha: isDark ? 0.18 : 0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.pink.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cake_outlined, color: AppColors.pink, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${todayBirthdays.first.personName}'s Birthday Today!",
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Wish them a wonderful day',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (todayBirthdays.first.phone != null && todayBirthdays.first.phone!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.pink, size: 18),
                    tooltip: 'Send Wish on WhatsApp',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final phone = todayBirthdays.first.phone!.replaceAll(RegExp(r'[^\d+]'), '');
                      final url = Uri.parse(
                        "https://wa.me/$phone?text=Happy%20Birthday%20${Uri.encodeComponent(todayBirthdays.first.personName)}!%20Wishing%20you%20a%20fantastic%20year%20ahead!",
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Actionable Tasks Checklist ──
        if (pendingTodos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All caught up for today!',
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No pending priority tasks remaining.',
                        style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.08),
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
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: pendingTodos.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 52,
                color: theme.colorScheme.outline.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, i) {
                final todo = pendingTodos[i];
                return _InteractiveTaskTile(todo: todo);
              },
            ),
          ),

        const SizedBox(height: 12),

        // ── Habits & Routines Overview Row ──
        routinesAsync.when(
          data: (routines) {
            if (routines.isEmpty) return const SizedBox.shrink();

            final totalRoutines = routines.length;
            final completedCount = completionsAsync.valueOrNull?.length ?? 0;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => MainShellController.of(context)?.switchTab(2),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: isDark ? 0.25 : 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.purple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Routines & Habits",
                              style: AppTypography.labelMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              "$completedCount of $totalRoutines routine items completed",
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ────────────────── INTERACTIVE TASK TILE ──────────────────

class _InteractiveTaskTile extends ConsumerWidget {
  final Todo todo;

  const _InteractiveTaskTile({required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final db = ref.read(databaseProvider);
        await db.toggleTodo(todo.id, !todo.isCompleted);
        ref.invalidate(allTodosStreamProvider);
        ref.invalidate(todoStatsProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Circular Completion Checkbox
            Icon(
              todo.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: todo.isCompleted ? AppColors.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              size: 22,
            ),
            const SizedBox(width: 12),

            // Title & Priority Pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (todo.description != null && todo.description!.isNotEmpty)
                    Text(
                      todo.description!,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Priority Indicator
            if (todo.priority == 2) // High
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'High',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
