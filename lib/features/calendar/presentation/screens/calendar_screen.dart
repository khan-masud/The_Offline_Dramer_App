import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/database/database_provider.dart';
import '../../../todo/presentation/screens/todo_screen.dart' show AddEditTodoSheet;

// ────────────────── PROVIDERS ──────────────────

final calendarMonthProvider = FutureProvider.family<Map<DateTime, List<Map<String, dynamic>>>, DateTime>(
  (ref, month) {
    final db = ref.watch(databaseProvider);
    return db.getMonthEvents(month.year, month.month);
  },
);

final calendarDayEventsProvider = FutureProvider.family<List<Map<String, dynamic>>, DateTime>(
  (ref, day) {
    final db = ref.watch(databaseProvider);
    return db.getDayEvents(day);
  },
);

enum EventFilter { all, todo, transaction, habit, routine, focus, debt, birthday }

final calendarFilterProvider = StateProvider<EventFilter>((ref) => EventFilter.all);

// ────────────────── SCREEN ──────────────────

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(calendarMonthProvider(_selectedMonth));
    final filter = ref.watch(calendarFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today_rounded, size: 18),
            label: const Text('Today'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Month selector ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
                  GestureDetector(
                    onTap: _goToToday,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: AppTypography.labelLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),

          // ── Calendar grid ──
          SliverToBoxAdapter(
            child: eventsAsync.when(
              data: (events) => _CalendarGrid(
                month: _selectedMonth,
                events: events,
                selectedDay: _selectedDay,
                onDayTap: (day) => setState(() => _selectedDay = day),
                onDayLongPress: (day) => _addTodoForDate(day),
              ),
              loading: () => _CalendarGrid(
                month: _selectedMonth,
                events: const {},
                selectedDay: _selectedDay,
                onDayTap: (day) => setState(() => _selectedDay = day),
                onDayLongPress: (day) => _addTodoForDate(day),
              ),
              error: (_, __) => _CalendarGrid(
                month: _selectedMonth,
                events: const {},
                selectedDay: _selectedDay,
                onDayTap: (day) => setState(() => _selectedDay = day),
                onDayLongPress: (day) => _addTodoForDate(day),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Filter chips ──
          if (_selectedDay != null)
            SliverToBoxAdapter(
              child: _FilterChips(selected: filter),
            ),

          // ── Selected day header + Add Todo button ──
          if (_selectedDay != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMM d').format(_selectedDay!),
                        style: AppTypography.labelLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    _AddTodoButton(
                      selectedDay: _selectedDay!,
                      onAdded: () {
                        ref.invalidate(calendarMonthProvider(_selectedMonth));
                        ref.invalidate(calendarDayEventsProvider(_selectedDay!));
                      },
                    ),
                  ],
                ),
              ),
            ),

          // ── Day events ──
          if (_selectedDay != null)
            _DayEventsList(
              selectedDay: _selectedDay!,
              filter: filter,
            )
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Tap a day to see events',
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addTodoForDate(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditTodoSheet(initialDueDate: date),
    ).then((_) {
      ref.invalidate(calendarMonthProvider(_selectedMonth));
      if (_selectedDay != null) {
        ref.invalidate(calendarDayEventsProvider(_selectedDay!));
      }
    });
  }
}

// ────────────────── FILTER CHIPS ──────────────────

class _FilterChips extends ConsumerWidget {
  final EventFilter selected;
  const _FilterChips({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      (EventFilter.all, 'All', Icons.select_all_rounded, AppColors.primary),
      (EventFilter.todo, 'Tasks', Icons.check_circle_outline, AppColors.primary),
      (EventFilter.transaction, 'Money', Icons.account_balance_wallet_outlined, AppColors.success),
      (EventFilter.habit, 'Habits', Icons.trending_up_rounded, AppColors.purple),
      (EventFilter.routine, 'Routines', Icons.repeat_rounded, AppColors.warning),
      (EventFilter.focus, 'Timer', Icons.timer_outlined, Colors.teal),
      (EventFilter.debt, 'Debts', Icons.money_rounded, AppColors.error),
      (EventFilter.birthday, 'Birthdays', Icons.cake_rounded, Colors.pink),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (filter, label, icon, color) = items[i];
          final isActive = selected == filter;
          return FilterChip(
            label: Text(label, style: AppTypography.labelSmall.copyWith(
              color: isActive ? Colors.white : color,
              fontWeight: FontWeight.w600,
            )),
            avatar: Icon(icon, size: 14, color: isActive ? Colors.white : color),
            selected: isActive,
            onSelected: (_) => ref.read(calendarFilterProvider.notifier).state = filter,
            selectedColor: color,
            backgroundColor: color.withValues(alpha: 0.08),
            side: BorderSide(color: isActive ? color : color.withValues(alpha: 0.2)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

// ────────────────── ADD TODO BUTTON ──────────────────

class _AddTodoButton extends StatelessWidget {
  final DateTime selectedDay;
  final VoidCallback onAdded;
  const _AddTodoButton({required this.selectedDay, required this.onAdded});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddEditTodoSheet(initialDueDate: selectedDay),
        ).then((_) => onAdded());
      },
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Add Task'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppColors.primary,
      ),
    );
  }
}

// ────────────────── DAY EVENTS LIST ──────────────────

class _DayEventsList extends ConsumerWidget {
  final DateTime selectedDay;
  final EventFilter filter;
  const _DayEventsList({required this.selectedDay, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(calendarDayEventsProvider(selectedDay));

    return eventsAsync.when(
      data: (allEvents) {
        final events = filter == EventFilter.all
            ? allEvents
            : allEvents.where((e) => e['type'] == filter.name).toList();

        if (events.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.event_available_rounded,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  filter == EventFilter.all
                      ? 'No events on this day'
                      : 'No ${filter.name} events',
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Long-press a day to add a task',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        // Group events by type
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final e in events) {
          final type = e['type'] as String;
          grouped.putIfAbsent(type, () => []).add(e);
        }

        final sectionOrder = ['todo', 'birthday', 'transaction', 'debt', 'habit', 'routine', 'focus'];

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                int runningIndex = 0;
                String? currentType;
                int itemsBeforeCurrentSection = 0;

                for (final type in sectionOrder) {
                  if (!grouped.containsKey(type)) continue;
                  if (runningIndex + grouped[type]!.length > i) {
                    currentType = type;
                    itemsBeforeCurrentSection = runningIndex;
                    break;
                  }
                  runningIndex += grouped[type]!.length;
                }

                if (currentType == null) return null;
                final localIndex = i - itemsBeforeCurrentSection;
                final event = grouped[currentType]![localIndex];
                final isFirstInSection = localIndex == 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFirstInSection) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          _sectionTitle(currentType),
                          style: AppTypography.labelSmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    _EventTile(event: event)
                        .animate()
                        .fadeIn(delay: (30 * i).ms, duration: 250.ms),
                  ],
                );
              },
              childCount: events.length,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SliverFillRemaining(
        child: Center(child: Text('Could not load events')),
      ),
    );
  }

  String _sectionTitle(String type) {
    switch (type) {
      case 'todo': return '📋 Tasks';
      case 'transaction': return '💰 Transactions';
      case 'habit': return '✅ Habits';
      case 'routine': return '🔄 Routines';
      case 'focus': return '⏱ Timer';
      case 'debt': return '💳 Debts';
      case 'birthday': return '🎂 Birthdays';
      default: return type.toUpperCase();
    }
  }
}

// ────────────────── CALENDAR GRID ──────────────────

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, List<Map<String, dynamic>>> events;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onDayLongPress;

  const _CalendarGrid({
    required this.month,
    required this.events,
    required this.selectedDay,
    required this.onDayTap,
    required this.onDayLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (final label in dayLabels) {
      cells.add(Center(
        child: Text(label, style: AppTypography.labelSmall.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        )),
      ));
    }

    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isToday = date == todayDate;
      final isSelected = date == selectedDay;
      final dayEvents = events[date] ?? [];
      final hasEvents = dayEvents.isNotEmpty;

      final dotColors = <Color>{};
      for (final e in dayEvents) {
        dotColors.add(_dotColor(e['color'] as String?));
      }

      cells.add(
        GestureDetector(
          onTap: () => onDayTap(date),
          onLongPress: () => onDayLongPress(date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? AppColors.primary
                            : theme.colorScheme.onSurface,
                    fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (hasEvents) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dotColors.take(3).map((c) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.8) : c,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.1,
        children: cells,
      ),
    );
  }

  Color _dotColor(String? colorName) {
    switch (colorName) {
      case 'primary': return AppColors.primary;
      case 'success': return AppColors.success;
      case 'error': return AppColors.error;
      case 'warning': return AppColors.warning;
      case 'purple': return AppColors.purple;
      case 'teal': return Colors.teal;
      case 'pink': return Colors.pink;
      default: return AppColors.info;
    }
  }
}

// ────────────────── EVENT TILE ──────────────────

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventTile({required this.event});

  Color _getColor() {
    switch (event['color'] as String?) {
      case 'primary': return AppColors.primary;
      case 'success': return AppColors.success;
      case 'error': return AppColors.error;
      case 'warning': return AppColors.warning;
      case 'purple': return AppColors.purple;
      case 'teal': return Colors.teal;
      case 'pink': return Colors.pink;
      default: return AppColors.info;
    }
  }

  IconData _getIcon() {
    switch (event['type'] as String?) {
      case 'todo': return event['isCompleted'] == true
          ? Icons.check_circle_rounded
          : Icons.circle_outlined;
      case 'transaction':
        return event['txType'] == 'income'
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;
      case 'habit': return Icons.trending_up_rounded;
      case 'routine': return Icons.repeat_rounded;
      case 'focus': return Icons.timer_outlined;
      case 'debt': return event['isSettled'] == true
          ? Icons.check_circle_rounded
          : Icons.money_rounded;
      case 'birthday': return Icons.cake_rounded;
      default: return Icons.circle;
    }
  }

  String _getTypeLabel() {
    switch (event['type'] as String?) {
      case 'todo': return 'Task';
      case 'transaction': return 'Transaction';
      case 'habit': return 'Habit';
      case 'routine': return 'Routine';
      case 'focus': return 'Focus Session';
      case 'debt': return 'Debt';
      case 'birthday': return 'Birthday';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(_getIcon(), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] as String? ?? '',
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      decoration: event['isCompleted'] == true
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getTypeLabel(),
                    style: AppTypography.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (event['type'] == 'todo' && (event['priority'] as int? ?? 0) > 0)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: event['priority'] == 3
                      ? AppColors.error
                      : event['priority'] == 2
                          ? AppColors.warning
                          : AppColors.info,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
