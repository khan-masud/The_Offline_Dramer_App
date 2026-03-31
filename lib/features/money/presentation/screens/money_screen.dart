import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/money_provider.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/money_chart.dart';

class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final statsAsync = ref.watch(monthStatsProvider);
    final filteredTxAsync = ref.watch(filteredTransactionsProvider);
    final budgetAsync = ref.watch(monthBudgetProvider);
    final budgetProgressAsync = ref.watch(budgetProgressProvider);
    final filter = ref.watch(transactionTypeFilterProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Money',
                        style: AppTypography.headingLarge
                            .copyWith(color: theme.colorScheme.onSurface)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.savings_outlined, size: 22),
                    onPressed: () => _showBudgetDialog(context, ref),
                    tooltip: 'Set Budget',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Month selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                        DateTime(selectedMonth.year, selectedMonth.month - 1),
                    visualDensity: VisualDensity.compact,
                  ),
                  GestureDetector(
                    onTap: () {
                      // Reset to current month
                      ref.read(selectedMonthProvider.notifier).state = DateTime.now();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Text(
                        DateFormat('MMMM yyyy').format(selectedMonth),
                        style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                        DateTime(selectedMonth.year, selectedMonth.month + 1),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Balance + Income/Expense cards
                        statsAsync.when(
                          data: (stats) => _BalanceSection(stats: stats),
                          loading: () => const _BalanceSkeleton(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),

                        // Budget progress
                        budgetProgressAsync.when(
                          data: (progress) {
                            if (progress == null) return const SizedBox.shrink();
                            final budget = budgetAsync.valueOrNull;
                            if (budget == null) return const SizedBox.shrink();
                            final spent = statsAsync.valueOrNull?.expense ?? 0;
                            return _BudgetProgressCard(
                              progress: progress,
                              spent: spent,
                              budget: budget.budgetAmount,
                            ).animate().fadeIn(duration: 400.ms);
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),

                        // Category breakdown chart
                        const SizedBox(height: 16),
                        const MoneyChart(),

                        // Filter tabs
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text('Transactions', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
                            const Spacer(),
                            ...TransactionTypeFilter.values.map((f) {
                              final isActive = filter == f;
                              final label = f == TransactionTypeFilter.all
                                  ? 'All'
                                  : f == TransactionTypeFilter.income
                                      ? 'In'
                                      : 'Out';
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: GestureDetector(
                                  onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = f,
                                  child: AnimatedContainer(
                                    duration: 200.ms,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isActive ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                      border: Border.all(
                                        color: isActive ? AppColors.primary : theme.colorScheme.outline,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: isActive ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ]),
                    ),
                  ),

                  // Transaction list
                  filteredTxAsync.when(
                    data: (txList) {
                      if (txList.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _emptyState(context),
                        );
                      }

                      // Group by date
                      final grouped = <String, List<Transaction>>{};
                      for (final tx in txList) {
                        final key = DateFormat('MMM d, yyyy').format(tx.date);
                        grouped.putIfAbsent(key, () => []).add(tx);
                      }

                      final groups = grouped.entries.toList();
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final group = groups[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                                    child: Text(
                                      group.key,
                                      style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                  ...group.value.asMap().entries.map((e) {
                                    return _TransactionTile(
                                      transaction: e.value,
                                      onDelete: () => ref.read(databaseProvider).deleteTransaction(e.value.id),
                                      onEdit: () => _showAddEditSheet(context, ref, transaction: e.value),
                                    ).animate().fadeIn(delay: (50 * e.key).ms, duration: 300.ms);
                                  }),
                                  if (index < groups.length - 1) const SizedBox(height: 8),
                                ],
                              );
                            },
                            childCount: groups.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      child: Center(child: Text('Error: $e')),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'money_fab',
        onPressed: () => _showAddEditSheet(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.warning),
            ),
            const SizedBox(height: 20),
            Text('No transactions yet', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('Tap + to add your first transaction', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, WidgetRef ref, {Transaction? transaction}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(transaction: transaction),
    );
  }

  void _showBudgetDialog(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.read(selectedMonthProvider);
    final monthStr = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
    final currentBudget = ref.read(monthBudgetProvider).valueOrNull;
    final controller = TextEditingController(
      text: currentBudget != null ? currentBudget.budgetAmount.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Monthly Budget — ${DateFormat('MMMM yyyy').format(selectedMonth)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Enter budget amount',
                prefixText: '$currencySymbol ',
              ),
            ),
            if (currentBudget != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  label: const Text('Remove budget', style: TextStyle(color: AppColors.error)),
                  onPressed: () {
                    ref.read(databaseProvider).deleteBudget(monthStr);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null || amount <= 0) return;
              ref.read(databaseProvider).setBudget(monthStr, amount);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ==================== BALANCE SECTION ====================
class _BalanceSection extends StatelessWidget {
  final ({double income, double expense, double balance}) stats;
  const _BalanceSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Total balance
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('Balance', style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(
                '$currencySymbol${_formatAmount(stats.balance)}',
                style: AppTypography.displayLarge.copyWith(
                  color: stats.balance >= 0 ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: 12),
        // Income & Expense row
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, size: 18, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Income', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          Text(
                            '$currencySymbol${_formatAmount(stats.income)}',
                            style: AppTypography.labelLarge.copyWith(color: AppColors.success),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: -0.05),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.error),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expense', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          Text(
                            '$currencySymbol${_formatAmount(stats.expense)}',
                            style: AppTypography.labelLarge.copyWith(color: AppColors.error),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideX(begin: 0.05),
            ),
          ],
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 100000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
  }
}

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Balance', style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('...', style: AppTypography.displayLarge.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ==================== BUDGET PROGRESS ====================
class _BudgetProgressCard extends StatelessWidget {
  final double progress;
  final double spent;
  final double budget;
  const _BudgetProgressCard({required this.progress, required this.spent, required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverBudget = progress > 1.0;
    final isWarning = progress > 0.8 && !isOverBudget;
    final barColor = isOverBudget ? AppColors.error : isWarning ? AppColors.warning : AppColors.success;
    final remaining = budget - spent;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, size: 18, color: barColor),
              const SizedBox(width: 8),
              Text('Monthly Budget', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
              const Spacer(),
              Text(
                '$currencySymbol${budget.toStringAsFixed(0)}',
                style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: theme.colorScheme.outline,
              color: barColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% used',
                style: AppTypography.labelSmall.copyWith(color: barColor),
              ),
              Text(
                isOverBudget
                    ? 'Over by $currencySymbol${(-remaining).toStringAsFixed(0)}'
                    : '$currencySymbol${remaining.toStringAsFixed(0)} remaining',
                style: AppTypography.labelSmall.copyWith(
                  color: isOverBudget ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== TRANSACTION TILE ====================
class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _TransactionTile({required this.transaction, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    final emoji = categoryIcons[transaction.category] ?? '📌';

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          onTap: onEdit,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Emoji avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isIncome ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              // Title & category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      transaction.category,
                      style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '${isIncome ? '+' : '-'}$currencySymbol${transaction.amount.toStringAsFixed(transaction.amount.truncateToDouble() == transaction.amount ? 0 : 2)}',
                style: AppTypography.labelLarge.copyWith(
                  color: isIncome ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
