import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../money/data/money_provider.dart';

class DashboardMoneyGraph extends ConsumerStatefulWidget {
  const DashboardMoneyGraph({super.key});

  @override
  ConsumerState<DashboardMoneyGraph> createState() => _DashboardMoneyGraphState();
}

class _DashboardMoneyGraphState extends ConsumerState<DashboardMoneyGraph> {
  int _selectedFilter = 0; // 0 = All (Income & Expense), 1 = Expense only, 2 = Income only

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txAsync = ref.watch(last10DaysTransactionsProvider);
    final categoryAsync = ref.watch(expenseCategoryLast10DaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Bar ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Cash Flow',
                  style: AppTypography.headingSmall.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last 10 days income & expenses',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),

            // View Mode Filter
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _FilterButton(
                    label: 'Both',
                    isSelected: _selectedFilter == 0,
                    onTap: () => setState(() => _selectedFilter = 0),
                  ),
                  _FilterButton(
                    label: 'Exp',
                    isSelected: _selectedFilter == 1,
                    onTap: () => setState(() => _selectedFilter = 1),
                  ),
                  _FilterButton(
                    label: 'Inc',
                    isSelected: _selectedFilter == 2,
                    onTap: () => setState(() => _selectedFilter = 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Main Chart Card ──
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary Metrics Strip ──
              txAsync.when(
                data: (txList) {
                  double totalIncome = 0;
                  double totalExpense = 0;
                  for (final tx in txList) {
                    if (tx.type == 'income') {
                      totalIncome += tx.amount;
                    } else {
                      totalExpense += tx.amount;
                    }
                  }
                  final netCashflow = totalIncome - totalExpense;

                  return Row(
                    children: [
                      // Income Pill
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.arrow_downward_rounded, size: 12, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Income',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF6EE7B7) : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$currencySymbol${totalIncome.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Expense Pill
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: isDark ? 0.18 : 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.error),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Expense',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$currencySymbol${totalExpense.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Net Pill
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Net',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${netCashflow >= 0 ? '+' : ''}$currencySymbol${netCashflow.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: netCashflow >= 0 ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // ── Smooth Spline Curved Line Area Chart ──
              SizedBox(
                height: 170,
                child: txAsync.when(
                  data: (txList) => _buildSmoothLineChart(txList, theme),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Text(
                      'No transaction history',
                      style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),

              // ── Top Category Spend Progress Bars ──
              categoryAsync.when(
                data: (cats) {
                  if (cats.isEmpty) return const SizedBox.shrink();

                  final topCats = cats.take(3).toList();
                  double maxCat = topCats.fold<double>(0, (prev, e) => prev + e.amount);
                  if (maxCat == 0) maxCat = 1;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Top Outflows',
                        style: AppTypography.labelSmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...topCats.map((cat) {
                        final percent = (cat.amount / maxCat).clamp(0.0, 1.0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    cat.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '$currencySymbol${cat.amount.toInt()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 4,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmoothLineChart(List txList, ThemeData theme) {
    final now = DateTime.now();
    final List<DateTime> days = List.generate(10, (i) => now.subtract(Duration(days: 9 - i)));

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
    maxY = maxY * 1.25;

    final incomeSpots = List.generate(10, (i) {
      final dStr = fmt.format(days[i]);
      return FlSpot(i.toDouble(), incomeMap[dStr] ?? 0);
    });

    final expenseSpots = List.generate(10, (i) {
      final dStr = fmt.format(days[i]);
      return FlSpot(i.toDouble(), expenseMap[dStr] ?? 0);
    });

    final showExpense = _selectedFilter == 0 || _selectedFilter == 1;
    final showIncome = _selectedFilter == 0 || _selectedFilter == 2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isIncomeSpot = spot.barIndex == 0 && showIncome;
                return LineTooltipItem(
                  '${isIncomeSpot ? 'Income' : 'Expense'}: $currencySymbol${spot.y.toInt()}',
                  TextStyle(
                    color: isIncomeSpot ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value >= maxY * 0.95) return const SizedBox();
                return Text(
                  _compactNum(value),
                  style: TextStyle(
                    fontSize: 9.5,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= 10 || idx % 3 != 0) return const SizedBox();
                final d = days[idx];
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    DateFormat('d MMM').format(d),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Income Line
          if (showIncome)
            LineChartBarData(
              spots: incomeSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.success,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.success.withValues(alpha: 0.25),
                    AppColors.success.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),

          // Expense Line
          if (showExpense)
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.error,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.error.withValues(alpha: 0.22),
                    AppColors.error.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  String _compactNum(double num) {
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toInt().toString();
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
