import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/database/database_provider.dart';

// Provider for calendar month events
final calendarMonthProvider = FutureProvider.family<Map<DateTime, List<Map<String, dynamic>>>, DateTime>(
  (ref, month) {
    final db = ref.watch(databaseProvider);
    return db.getMonthEvents(month.year, month.month);
  },
);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(calendarMonthProvider(_selectedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: false,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Month selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                          _selectedDay = null;
                        }),
                        visualDensity: VisualDensity.compact,
                      ),
                      GestureDetector(
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _selectedMonth = DateTime(now.year, now.month);
                            _selectedDay = DateTime(now.year, now.month, now.day);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            border: Border.all(color: theme.colorScheme.outline),
                          ),
                          child: Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                          _selectedDay = null;
                        }),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // Calendar grid
                eventsAsync.when(
                  data: (events) => _CalendarGrid(
                    month: _selectedMonth,
                    events: events,
                    selectedDay: _selectedDay,
                    onDayTap: (day) => setState(() => _selectedDay = day),
                  ),
                  loading: () => _CalendarGrid(
                    month: _selectedMonth,
                    events: const {},
                    selectedDay: _selectedDay,
                    onDayTap: (day) => setState(() => _selectedDay = day),
                  ),
                  error: (_, __) => _CalendarGrid(
                    month: _selectedMonth,
                    events: const {},
                    selectedDay: _selectedDay,
                    onDayTap: (day) => setState(() => _selectedDay = day),
                  ),
                ),

                const SizedBox(height: 8),
                Divider(height: 1, color: theme.colorScheme.outline),
              ],
            ),
          ),

          // Day events
          eventsAsync.when(
            data: (events) {
              if (_selectedDay == null) {
                return SliverFillRemaining(hasScrollBody: false, child: _noSelection(theme));
              }
              final dayEvents = events[_selectedDay] ?? [];
              if (dayEvents.isEmpty) {
                return SliverFillRemaining(hasScrollBody: false, child: _noDayEvents(theme));
              }
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final event = dayEvents[i];
                      return _EventTile(event: event)
                          .animate().fadeIn(delay: (50 * i).ms, duration: 300.ms);
                    },
                    childCount: dayEvents.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (_, __) => SliverFillRemaining(hasScrollBody: false, child: _noSelection(theme)),
          ),
        ],
      ),
    );
  }

  Widget _noSelection(ThemeData theme) {
    return Center(
      child: Text('Tap a day to see events', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _noDayEvents(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text('No events on this day', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ==================== CALENDAR GRID ====================
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, List<Map<String, dynamic>>> events;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.month,
    required this.events,
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon
    final daysInMonth = lastDay.day;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Build grid cells
    final cells = <Widget>[];

    // Day headers
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (final label in dayLabels) {
      cells.add(Center(
        child: Text(label, style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ));
    }

    // Empty cells before first day
    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isToday = date == todayDate;
      final isSelected = date == selectedDay;
      final dayEvents = events[date] ?? [];
      final hasEvents = dayEvents.isNotEmpty;

      // Get event type colors for dots
      final dotColors = <Color>{};
      for (final e in dayEvents) {
        switch (e['color'] as String?) {
          case 'primary': dotColors.add(AppColors.primary);
          case 'success': dotColors.add(AppColors.success);
          case 'error': dotColors.add(AppColors.error);
          case 'warning': dotColors.add(AppColors.warning);
          case 'purple': dotColors.add(AppColors.purple);
          default: dotColors.add(AppColors.info);
        }
      }

      cells.add(
        GestureDetector(
          onTap: () => onDayTap(date),
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
}

// ==================== EVENT TILE ====================
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
      default: return AppColors.info;
    }
  }

  IconData _getIcon() {
    switch (event['type'] as String?) {
      case 'todo': return event['isCompleted'] == true ? Icons.check_circle_rounded : Icons.circle_outlined;
      case 'transaction': return event['txType'] == 'income' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
      case 'habit': return Icons.trending_up_rounded;
      default: return Icons.circle;
    }
  }

  String _getTypeLabel() {
    switch (event['type'] as String?) {
      case 'todo': return 'Task';
      case 'transaction': return 'Transaction';
      case 'habit': return 'Habit';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getTypeLabel(),
                    style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
