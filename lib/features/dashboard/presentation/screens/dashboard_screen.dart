import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../../todo/data/todo_provider.dart';
import '../../../routine/data/routine_provider.dart';
import '../../../money/data/money_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../../data/weather_provider.dart';
import '../widgets/greeting_header.dart';
import '../widgets/weather_timeline.dart';
import '../widgets/dashboard_insights.dart';
import '../widgets/quick_actions.dart';
import '../widgets/overview_cards.dart';
import '../widgets/recent_activity.dart';
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
    // Invalidate all dashboard-related providers to trigger refresh
    ref.invalidate(activityLogProvider);
    ref.invalidate(todosProvider);
    ref.invalidate(todayRoutinesProvider);
    ref.invalidate(todaySpentProvider);
    ref.invalidate(notesProvider);
    ref.invalidate(weatherProvider);
    // Wait for all providers to settle
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppDimensions.base),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const GreetingHeader()
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: -0.1),
                    const SizedBox(height: AppDimensions.md),
                    const WeatherTimeline()
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 500.ms)
                        .slideY(begin: 0.05),
                    const SizedBox(height: AppDimensions.xl),
                    const OverviewCards()
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 500.ms)
                        .slideY(begin: 0.05),
                    const SizedBox(height: AppDimensions.xl),
                      const DashboardInsights()
                        .animate()
                        .fadeIn(delay: 280.ms, duration: 500.ms)
                        .slideY(begin: 0.05),
                      const SizedBox(height: AppDimensions.xl),
                    const QuickActions()
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 500.ms)
                        .slideY(begin: 0.05),
                    const SizedBox(height: AppDimensions.xl),
                    const RecentActivity()
                        .animate()
                        .fadeIn(delay: 500.ms, duration: 500.ms)
                        .slideY(begin: 0.05),
                    const SizedBox(height: 100),
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
