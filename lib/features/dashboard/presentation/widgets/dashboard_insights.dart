import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimensions.dart';
import 'dashboard_money_graph.dart';
import 'dashboard_time_graph.dart';

class DashboardInsights extends StatelessWidget {
  const DashboardInsights({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardMoneyGraph(),
        SizedBox(height: AppDimensions.xl),
        DashboardTimeGraph(),
      ],
    );
  }
}
