import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/money_provider.dart';

class MoneyChart extends ConsumerWidget {
  const MoneyChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final breakdownAsync = ref.watch(categoryBreakdownProvider);

    return breakdownAsync.when(
      data: (breakdown) {
        if (breakdown.isEmpty) return const SizedBox.shrink();

        final total = breakdown.fold<double>(0, (sum, e) => sum + e.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by Category',
                style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),

            // Stacked bar
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The horizontal bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: breakdown.asMap().entries.map((e) {
                          final ratio = e.value.amount / total;
                          return Expanded(
                            flex: (ratio * 1000).round().clamp(1, 1000),
                            child: Container(
                              color: _categoryColor(e.key),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ).animate().scaleX(begin: 0, alignment: Alignment.centerLeft, duration: 600.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: 14),

                  // Legend
                  ...breakdown.asMap().entries.map((e) {
                    final percent = (e.value.amount / total * 100).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              color: _categoryColor(e.key),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(e.value.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.value.category,
                              style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
                            ),
                          ),
                          Text(
                            '$currencySymbol${e.value.amount.toStringAsFixed(0)}',
                            style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 42,
                            child: Text(
                              '$percent%',
                              textAlign: TextAlign.right,
                              style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (100 * e.key).ms, duration: 300.ms);
                  }),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _categoryColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.purple,
      AppColors.teal,
      AppColors.orange,
      AppColors.pink,
      AppColors.info,
    ];
    return colors[index % colors.length];
  }
}
