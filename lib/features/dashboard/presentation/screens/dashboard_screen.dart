import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../todo/data/todo_provider.dart';
import '../../../routine/data/routine_provider.dart';
import '../../../money/data/money_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../diary/data/diary_provider.dart';
import '../../../../providers/dashboard_preferences_provider.dart';
import '../../data/weather_provider.dart';
import '../../data/daily_info_provider.dart';
import '../widgets/greeting_header.dart';
import '../widgets/weather_timeline.dart';
import '../widgets/daily_mindset_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/overview_cards.dart';
import '../widgets/today_agenda_feed.dart';
import '../widgets/dashboard_insights.dart';
import '../../../../core/services/update_checker.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
    });
  }

  Future<void> _onRefresh() async {
    // Invalidate all dashboard-related providers to trigger fresh load
    ref.invalidate(allTodosStreamProvider);
    ref.invalidate(todoStatsProvider);
    ref.invalidate(todayRoutinesProvider);
    ref.invalidate(todayCompletionsProvider);
    ref.invalidate(todaySpentProvider);
    ref.invalidate(notesProvider);
    ref.invalidate(diaryEntriesProvider);
    ref.invalidate(dailyInfoProvider);
    ref.invalidate(weatherProvider);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final dashboardPrefs = ref.watch(dashboardPreferencesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  AppDimensions.base,
                  AppDimensions.base,
                  AppDimensions.xl,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. Executive Greeting & Productivity Pulse Header
                    const GreetingHeader()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.06),

                    // 2. Weather Timeline (Optional / Preference)
                    if (dashboardPrefs.showWeather) ...[
                      const SizedBox(height: 14),
                      const WeatherTimeline()
                          .animate()
                          .fadeIn(delay: 80.ms, duration: 400.ms)
                          .slideY(begin: 0.04),
                    ],

                    // 3. Daily Motivation & Historical Echoes Switcher Card
                    if (dashboardPrefs.showDailyMotivation || dashboardPrefs.showDailyEvents) ...[
                      const SizedBox(height: 14),
                      const DailyMindsetCard()
                          .animate()
                          .fadeIn(delay: 140.ms, duration: 400.ms)
                          .slideY(begin: 0.04),
                    ],

                    const SizedBox(height: 18),

                    // 4. Quick Action Dock
                    const QuickActions()
                        .animate()
                        .fadeIn(delay: 180.ms, duration: 400.ms)
                        .slideY(begin: 0.04),

                    const SizedBox(height: 18),

                    // 5. Bento-Grid Daily Overview Cards
                    const OverviewCards()
                        .animate()
                        .fadeIn(delay: 220.ms, duration: 400.ms)
                        .slideY(begin: 0.04),

                    const SizedBox(height: 18),

                    // 6. Actionable Today Agenda & Focus Checklist
                    const TodayAgendaFeed()
                        .animate()
                        .fadeIn(delay: 260.ms, duration: 400.ms)
                        .slideY(begin: 0.04),

                    const SizedBox(height: 18),

                    // 7. Financial & Time Insights Analytics
                    const DashboardInsights()
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms)
                        .slideY(begin: 0.04),

                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
