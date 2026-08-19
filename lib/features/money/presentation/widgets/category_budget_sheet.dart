import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/money_provider.dart';

class CategoryBudgetSheet extends ConsumerWidget {
  const CategoryBudgetSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthStr = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
    final progressListAsync = ref.watch(categoryBudgetProgressListProvider);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 16,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Budgets',
                        style: AppTypography.headingMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMMM yyyy').format(selectedMonth),
                        style: AppTypography.labelSmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category budget list
              progressListAsync.when(
                data: (progressList) {
                  if (progressList.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.savings_outlined, size: 36, color: AppColors.teal),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Category Budgets Set',
                              style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set monthly spending limits for Food, Transport, Bills, etc.',
                              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: progressList.length,
                    itemBuilder: (context, index) {
                      final item = progressList[index];
                      final isOver = item.alertLevel == 'exceeded';
                      final isWarning = item.alertLevel == 'warning';
                      final color = isOver
                          ? AppColors.error
                          : (isWarning ? AppColors.warning : AppColors.primary);
                      final icon = categoryMaterialIcons[item.category] ?? Icons.category_outlined;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isOver
                                ? AppColors.error.withValues(alpha: 0.35)
                                : theme.colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(icon, size: 16, color: color),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$currencySymbol${item.spentAmount.toStringAsFixed(0)} / $currencySymbol${item.budgetAmount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showEditCategoryBudgetDialog(
                                      context, ref, monthStr, item.category, item.budgetAmount),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: item.progress.clamp(0.0, 1.0),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 5,
                              ),
                            ),
                            if (isOver) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.error),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Over budget by $currencySymbol${(item.spentAmount - item.budgetAmount).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error loading budgets: $e')),
              ),

              const SizedBox(height: 14),

              // Add Category Budget Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddCategoryBudgetDialog(context, ref, monthStr),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Category Budget Limit', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryBudgetDialog(BuildContext context, WidgetRef ref, String monthStr) {
    String selectedCat = expenseCategories.first;
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Set Category Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedCat,
                items: expenseCategories.map((c) {
                  final icon = categoryMaterialIcons[c] ?? Icons.category_outlined;
                  return DropdownMenuItem(
                    value: c,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => selectedCat = v);
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Monthly Limit',
                  prefixText: '$currencySymbol ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                ref.read(databaseProvider).setCategoryBudget(monthStr, selectedCat, amount);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    String monthStr,
    String category,
    double currentBudget,
  ) {
    final amountCtrl = TextEditingController(text: currentBudget.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $category Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monthly Limit',
                prefixText: '$currencySymbol ',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                label: const Text('Remove limit', style: TextStyle(color: AppColors.error)),
                onPressed: () {
                  ref.read(databaseProvider).deleteCategoryBudget(monthStr, category);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) return;
              ref.read(databaseProvider).setCategoryBudget(monthStr, category, amount);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
