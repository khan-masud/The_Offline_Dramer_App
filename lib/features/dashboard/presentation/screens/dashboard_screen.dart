import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../widgets/greeting_header.dart';
import '../widgets/weather_timeline.dart';
import '../widgets/dashboard_insights.dart';
import '../widgets/quick_actions.dart';
import '../widgets/overview_cards.dart';
import '../widgets/recent_activity.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
    );
  }
}
