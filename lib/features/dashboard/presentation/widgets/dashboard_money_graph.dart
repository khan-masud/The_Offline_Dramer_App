import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../money/data/money_provider.dart';

class DashboardMoneyGraph extends ConsumerStatefulWidget {
  const DashboardMoneyGraph({super.key});

  @override
  ConsumerState<DashboardMoneyGraph> createState() => _DashboardMoneyGraphState();
}

class _DashboardMoneyGraphState extends ConsumerState<DashboardMoneyGraph> {
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txAsync = ref.watch(last10DaysTransactionsProvider);
    final categoryAsync = ref.watch(expenseCategoryLast10DaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Money Flows (Last 10 Days)', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
        const SizedBox(height: AppDimensions.md),
        
        // Income vs Expense Bar Chart
        AppCard(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Income vs Expense',
                style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: txAsync.when(
                  data: (txList) => _buildBarChart(txList, theme),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppDimensions.sm),
        
        // Expense by Category Pie Chart
        AppCard(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expense by Category',
                style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: categoryAsync.when(
                  data: (cats) {
                    if (cats.isEmpty) {
                      return Center(
                        child: Text("No expenses in the last 10 days", style: AppTypography.labelMedium),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touchedPieIndex = -1;
                                      return;
                                    }
                                    _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                              sections: List.generate(math.min(5, cats.length), (i) {
                                final isTouched = i == _touchedPieIndex;
                                final radius = isTouched ? 45.0 : 35.0;
                                final cat = cats[i];
                                return PieChartSectionData(
                                  color: _getColor(i),
                                  value: cat.amount,
                                  title: isTouched ? '${cat.amount.toInt()}' : '',
                                  radius: radius,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                );
                              }),
                            ),
                            duration: const Duration(milliseconds: 150), // Optional
                            curve: Curves.linear, // Optional
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: ListView.builder(
                            itemCount: math.min(5, cats.length),
                            itemBuilder: (context, i) {
                              final cat = cats[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12, height: 12,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: _getColor(i)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${cat.emoji} ${cat.category}', 
                                        style: AppTypography.labelSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text('$currencySymbol${cat.amount.toInt()}', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(List txList, ThemeData theme) {
    // Generate dates for the last 10 days
    final now = DateTime.now();
    final List<DateTime> days = List.generate(10, (i) => now.subtract(Duration(days: 9 - i)));
    
    // Group tx by day
    final Map<String, double> incomeMap = {};
    final Map<String, double> expenseMap = {};
    
    final fmt = DateFormat('MM-dd');
    for (var d in days) {
      incomeMap[fmt.format(d)] = 0;
      expenseMap[fmt.format(d)] = 0;
    }
    
    for (var tx in txList) {
      final dateStr = fmt.format(tx.date);
      if (incomeMap.containsKey(dateStr)) {
        if (tx.type == 'income') {
          incomeMap[dateStr] = incomeMap[dateStr]! + tx.amount;
        } else {
          expenseMap[dateStr] = expenseMap[dateStr]! + tx.amount;
        }
      }
    }

    double maxY = 100;
    for (var v in incomeMap.values) {
      if (v > maxY) maxY = v;
    }
    for (var v in expenseMap.values) {
      if (v > maxY) maxY = v;
    }
    
    maxY = maxY * 1.2; // Add some headroom

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isIncome = rodIndex == 0;
              return BarTooltipItem(
                '${isIncome ? 'Income' : 'Expense'}\n$currencySymbol${rod.toY.toInt()}',
                AppTypography.labelMedium.copyWith(color: isIncome ? AppColors.success : AppColors.error),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= 10) return const SizedBox();
                // Show every 2nd day to avoid clutter
                if (value % 2 != 0) return const SizedBox(); 
                final dateStr = fmt.format(days[value.toInt()]);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(dateStr, style: AppTypography.labelSmall.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxY) return const SizedBox();
                return Text(
                  _compactNum(value),
                  style: AppTypography.labelSmall.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(10, (i) {
          final dStr = fmt.format(days[i]);
          final inc = incomeMap[dStr] ?? 0;
          final exp = expenseMap[dStr] ?? 0;
          
          return BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: inc > 0 ? inc : 0.05 * maxY, 
                color: inc > 0 ? AppColors.success : theme.colorScheme.surfaceContainerHighest,
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: exp > 0 ? exp : 0.05 * maxY,
                color: exp > 0 ? AppColors.error : theme.colorScheme.surfaceContainerHighest,
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 500),
    );
  }
  
  String _compactNum(double num) {
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toInt().toString();
  }

  Color _getColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.warning,
      AppColors.teal,
      AppColors.error,
      AppColors.purple,
    ];
    return colors[index % colors.length];
  }
}
