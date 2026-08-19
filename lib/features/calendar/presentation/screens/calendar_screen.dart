import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../todo/presentation/screens/todo_screen.dart' show AddEditTodoSheet;
import '../../../money/presentation/widgets/add_transaction_sheet.dart';
import '../../../money/presentation/screens/debts_screen.dart' show showAddEditDebtModal;
import '../../../money/presentation/widgets/debt_share_reminder_sheet.dart';
import '../../../diary/presentation/screens/diary_editor_screen.dart';
import '../../../diary/presentation/screens/diary_preview_screen.dart';

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

enum EventFilter { all, todo, diary, transaction, habit, routine, focus, debt, birthday }
enum DayEventLayout { grouped, timeline }

final calendarFilterProvider = StateProvider<EventFilter>((ref) => EventFilter.all);
final dayEventLayoutProvider = StateProvider<DayEventLayout>((ref) => DayEventLayout.grouped);

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

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(calendarMonthProvider(_selectedMonth));
    final filter = ref.watch(calendarFilterProvider);
    final layout = ref.watch(dayEventLayoutProvider);

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
          // Day Layout Switcher (Grouped vs Timeline)
          PopupMenuButton<DayEventLayout>(
            icon: Icon(layout == DayEventLayout.grouped ? Icons.category_outlined : Icons.timeline_rounded),
            tooltip: 'Layout Mode',
            initialValue: layout,
            onSelected: (l) => ref.read(dayEventLayoutProvider.notifier).state = l,
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: DayEventLayout.grouped,
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Grouped by Module'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: DayEventLayout.timeline,
                child: Row(
                  children: [
                    Icon(Icons.timeline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Chronological Timeline'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -250) {
            _nextMonth(); // Swipe Left -> Next Month
          } else if (details.primaryVelocity! > 250) {
            _prevMonth(); // Swipe Right -> Prev Month
          }
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Month selector ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _prevMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                    GestureDetector(
                      onTap: _goToToday,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth),
                              style: AppTypography.labelLarge.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _nextMonth,
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
                  onDayLongPress: (day) => _showQuickAddOptions(day),
                ),
                loading: () => _CalendarGrid(
                  month: _selectedMonth,
                  events: const {},
                  selectedDay: _selectedDay,
                  onDayTap: (day) => setState(() => _selectedDay = day),
                  onDayLongPress: (day) => _showQuickAddOptions(day),
                ),
                error: (_, __) => _CalendarGrid(
                  month: _selectedMonth,
                  events: const {},
                  selectedDay: _selectedDay,
                  onDayTap: (day) => setState(() => _selectedDay = day),
                  onDayLongPress: (day) => _showQuickAddOptions(day),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Filter chips ──
            if (_selectedDay != null)
              SliverToBoxAdapter(
                child: _FilterChips(selected: filter),
              ),

            // ── Selected day header + Add Action button ──
            if (_selectedDay != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(_selectedDay!),
                        style: AppTypography.labelLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: () => _showQuickAddOptions(_selectedDay!),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Event', style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
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
                layout: layout,
                onRefresh: () {
                  ref.invalidate(calendarMonthProvider(_selectedMonth));
                  ref.invalidate(calendarDayEventsProvider(_selectedDay!));
                },
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
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab',
        onPressed: () => _showQuickAddOptions(_selectedDay ?? DateTime.now()),
        tooltip: 'Quick Add Event',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showQuickAddOptions(DateTime date) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Add for ${DateFormat('MMM d, yyyy').format(date)}',
              style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary),
              ),
              title: const Text('New Task / Todo', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Add a task with due date set to this day'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddEditTodoSheet(initialDueDate: date),
                ).then((_) => _refreshCalendar());
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.purple),
              ),
              title: const Text('New Diary Entry', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Write your daily diary and personal notes for this day'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DiaryEditorScreen(initialDate: date)),
                ).then((_) => _refreshCalendar());
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.success),
              ),
              title: const Text('New Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Record income or expense for this day'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddTransactionSheet(initialDate: date),
                ).then((_) => _refreshCalendar());
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.payments_outlined, color: AppColors.error),
              ),
              title: const Text('New Debt / Loan', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Record money lent or borrowed with due date'),
              onTap: () {
                Navigator.pop(ctx);
                showAddEditDebtModal(context, initialDueDate: date).then((_) => _refreshCalendar());
              },
            ),
          ],
        ),
      ),
    );
  }

  void _refreshCalendar() {
    ref.invalidate(calendarMonthProvider(_selectedMonth));
    if (_selectedDay != null) {
      ref.invalidate(calendarDayEventsProvider(_selectedDay!));
    }
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
      (EventFilter.diary, 'Diary', Icons.menu_book_rounded, AppColors.purple),
      (EventFilter.transaction, 'Money', Icons.account_balance_wallet_outlined, AppColors.success),
      (EventFilter.habit, 'Habits', Icons.trending_up_rounded, AppColors.purple),
      (EventFilter.routine, 'Routines', Icons.repeat_rounded, AppColors.warning),
      (EventFilter.focus, 'Timer', Icons.timer_outlined, Colors.teal),
      (EventFilter.debt, 'Debts', Icons.money_rounded, AppColors.error),
      (EventFilter.birthday, 'Birthdays', Icons.cake_rounded, Colors.pink),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (filter, label, icon, color) = items[i];
          final isActive = selected == filter;
          return GestureDetector(
            onTap: () => ref.read(calendarFilterProvider.notifier).state = filter,
            child: AnimatedContainer(
              duration: 180.ms,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.16) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: isActive ? 1.4 : 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: isActive ? color : Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────── DAY EVENTS LIST ──────────────────

class _DayEventsList extends ConsumerWidget {
  final DateTime selectedDay;
  final EventFilter filter;
  final DayEventLayout layout;
  final VoidCallback onRefresh;

  const _DayEventsList({
    required this.selectedDay,
    required this.filter,
    required this.layout,
    required this.onRefresh,
  });

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
                const SizedBox(height: 30),
                Icon(
                  Icons.event_available_rounded,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  filter == EventFilter.all ? 'No events on this day' : 'No ${filter.name} events',
                  style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Add Event" to schedule tasks or records',
                  style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                ),
              ],
            ),
          );
        }

        // 1. TIMELINE LAYOUT
        if (layout == DayEventLayout.timeline) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final event = events[i];
                  return _InteractiveEventTile(
                    event: event,
                    onRefresh: onRefresh,
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
                },
                childCount: events.length,
              ),
            ),
          );
        }

        // 2. GROUPED BY MODULE
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final e in events) {
          final type = e['type'] as String;
          grouped.putIfAbsent(type, () => []).add(e);
        }

        final sectionOrder = ['todo', 'diary', 'birthday', 'transaction', 'debt', 'habit', 'routine', 'focus'];

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          _sectionTitle(currentType),
                          style: AppTypography.labelSmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    _InteractiveEventTile(
                      event: event,
                      onRefresh: onRefresh,
                    ).animate().fadeIn(duration: 200.ms),
                  ],
                );
              },
              childCount: events.length,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SliverFillRemaining(child: Center(child: Text('Could not load events'))),
    );
  }

  String _sectionTitle(String type) {
    switch (type) {
      case 'todo': return '📋 Tasks';
      case 'diary': return '📔 Diary';
      case 'transaction': return '💰 Money & Transactions';
      case 'habit': return '✅ Habits';
      case 'routine': return '🔄 Routines';
      case 'focus': return '⏱ Timer & Focus';
      case 'debt': return '💳 Debts & Loans';
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
          fontWeight: FontWeight.w600,
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
      final overflowCount = dayEvents.length > 3 ? dayEvents.length - 3 : 0;

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
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !isSelected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.2)
                  : null,
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
                    children: [
                      ...dotColors.take(3).map((c) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withValues(alpha: 0.9) : c,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),
                      if (overflowCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 1),
                          child: Text(
                            '+$overflowCount',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
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
        childAspectRatio: 1.15,
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

// ────────────────── INTERACTIVE EVENT TILE ──────────────────

class _InteractiveEventTile extends ConsumerWidget {
  final Map<String, dynamic> event;
  final VoidCallback onRefresh;

  const _InteractiveEventTile({
    required this.event,
    required this.onRefresh,
  });

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
      case 'todo': return event['isCompleted'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded;
      case 'diary': return Icons.auto_stories_outlined;
      case 'transaction': return event['txType'] == 'income' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
      case 'habit': return Icons.trending_up_rounded;
      case 'routine': return Icons.repeat_rounded;
      case 'focus': return Icons.timer_outlined;
      case 'debt': return Icons.payments_outlined;
      case 'birthday': return Icons.cake_rounded;
      default: return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _getColor();
    final type = event['type'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => _handleEventTap(context, ref),
        child: Row(
          children: [
            // Left interactive indicator / checkbox
            if (type == 'todo')
              GestureDetector(
                onTap: () async {
                  final id = event['id'] as int?;
                  if (id != null) {
                    final isComp = event['isCompleted'] == true;
                    await ref.read(databaseProvider).updateTodo(
                          TodosCompanion(
                            id: Value(id),
                            isCompleted: Value(!isComp),
                          ),
                        );
                    onRefresh();
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (event['isCompleted'] == true ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    event['isCompleted'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: event['isCompleted'] == true ? AppColors.success : AppColors.primary,
                  ),
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getIcon(), size: 16, color: color),
              ),

            const SizedBox(width: 12),

            // Center: Title + Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] as String? ?? '',
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      decoration: event['isCompleted'] == true ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatSubtitle(),
                    style: AppTypography.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Right: Trailing details or action
            if (type == 'transaction' && event['amount'] != null)
              Text(
                '${event['txType'] == 'income' ? '+' : '-'}৳${(event['amount'] as num).toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: event['txType'] == 'income' ? AppColors.success : AppColors.error,
                ),
              )
            else if (type == 'debt' && event['amount'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '৳${(event['amount'] as num).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: event['isSettled'] == true ? AppColors.success : AppColors.error,
                    ),
                  ),
                  Text(
                    event['isSettled'] == true ? 'Settled' : 'Pending',
                    style: TextStyle(fontSize: 10, color: event['isSettled'] == true ? AppColors.success : AppColors.error),
                  ),
                ],
              )
            else if (type == 'birthday')
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 16, color: Colors.pink),
                tooltip: 'Send Birthday Wish',
                onPressed: () => _launchBirthdayWish(event['phone'] as String?),
              ),
          ],
        ),
      ),
    );
  }

  String _formatSubtitle() {
    final type = event['type'] as String;
    switch (type) {
      case 'todo':
        return event['description'] != null && (event['description'] as String).isNotEmpty
            ? event['description'] as String
            : 'Task Due';
      case 'diary':
        return 'Diary Entry • ${event['wordCount'] ?? 0} words';
      case 'transaction':
        return event['category'] != null ? '${event['category']}' : 'Transaction';
      case 'habit':
        return 'Habit Completed';
      case 'routine':
        return 'Routine Completed';
      case 'focus':
        return 'Session Recorded';
      case 'debt':
        return '${event['personName'] ?? 'Debt Record'}';
      case 'birthday':
        return 'Birthday Celebration';
      default:
        return type;
    }
  }

  void _handleEventTap(BuildContext context, WidgetRef ref) async {
    final type = event['type'] as String;
    final id = event['id'] as int?;

    if (type == 'todo' && id != null) {
      final db = ref.read(databaseProvider);
      final todo = await (db.select(db.todos)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (todo != null && context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddEditTodoSheet(todo: todo),
        ).then((_) => onRefresh());
      }
    } else if (type == 'diary' && id != null) {
      final db = ref.read(databaseProvider);
      final entry = await (db.select(db.diaryEntries)..where((d) => d.id.equals(id))).getSingleOrNull();
      if (entry != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DiaryPreviewScreen(entry: entry)),
        ).then((_) => onRefresh());
      }
    } else if (type == 'debt' && id != null) {
      final db = ref.read(databaseProvider);
      final debt = await (db.select(db.debts)..where((d) => d.id.equals(id))).getSingleOrNull();
      if (debt != null && context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DebtShareReminderSheet(debt: debt),
        ).then((_) => onRefresh());
      }
    }
  }

  void _launchBirthdayWish(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent("Happy Birthday! Wishing you a wonderful year ahead! 🎂🎉")}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
