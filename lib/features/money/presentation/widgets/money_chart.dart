import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/money_provider.dart';

class MoneyChart extends ConsumerWidget {
  const MoneyChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final breakdownAsync = ref.watch(categoryBreakdownProvider);

    return breakdownAsync.when(
      data: (breakdown) {
        if (breakdown.isEmpty) return const SizedBox.shrink();

        final total = breakdown.fold<double>(0, (sum, e) => sum + e.amount);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spending by Category',
                    style: AppTypography.headingSmall.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$currencySymbol${total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Multi-Segment Horizontal Stacked Bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: breakdown.asMap().entries.map((e) {
                      final ratio = total > 0 ? (e.value.amount / total) : 0.0;
                      return Expanded(
                        flex: (ratio * 1000).round().clamp(1, 1000),
                        child: Container(
                          color: _categoryColor(e.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Category Rows ──
              ...breakdown.asMap().entries.map((e) {
                final percent = total > 0 ? (e.value.amount / total * 100).toStringAsFixed(1) : '0';
                final catColor = _categoryColor(e.key);
                final icon = categoryMaterialIcons[e.value.category] ?? Icons.category_outlined;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 14, color: catColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value.category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '$currencySymbol${e.value.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '$percent%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _categoryColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.warning,
      AppColors.teal,
      AppColors.error,
      AppColors.purple,
      AppColors.orange,
      AppColors.pink,
      AppColors.info,
      AppColors.success,
    ];
    return colors[index % colors.length];
  }
}
