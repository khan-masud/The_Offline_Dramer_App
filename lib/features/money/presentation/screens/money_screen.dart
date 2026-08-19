import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/money_provider.dart';
import '../../data/recurring_transaction_service.dart';
import 'debts_screen.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/money_chart.dart';
import '../widgets/category_budget_sheet.dart';
import '../widgets/cashflow_trend_chart.dart';
import '../widgets/manage_wallets_sheet.dart';
import '../../data/money_export_service.dart';

class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(recurringTransactionServiceProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            // ── Header Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _isSearching
                        ? TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search transactions...',
                              hintStyle: TextStyle(
                                fontSize: 13.5,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(99),
                                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(99),
                                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(99),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                              ),
                            ),
                            onChanged: (v) => ref.read(transactionSearchProvider.notifier).state = v,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Money & Cashflow',
                                style: AppTypography.headingLarge.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Track income, expense & budgets',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 20),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchCtrl.clear();
                          ref.read(transactionSearchProvider.notifier).state = '';
                        }
                      });
                    },
                  ),
                  if (!_isSearching) ...[
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined, size: 20),
                      onPressed: () async {
                        final txList = ref.read(monthTransactionsProvider).valueOrNull ?? [];
                        final wallets = ref.read(walletsProvider).valueOrNull ?? [];
                        if (txList.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No transactions to export for this month')),
                          );
                          return;
                        }
                        await MoneyExportService.exportAndShareCsv(
                          transactions: txList,
                          month: selectedMonth,
                          wallets: wallets,
                        );
                      },
                      tooltip: 'Export CSV Statement',
                    ),
                    IconButton(
                      icon: const Icon(Icons.savings_outlined, size: 20),
                      onPressed: () => _showBudgetDialog(context, ref),
                      tooltip: 'Set Monthly Budget',
                    ),
                  ],
                ],
              ),
            ),

            // ── Month Selector Capsule ──
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
                      HapticFeedback.lightImpact();
                      ref.read(selectedMonthProvider.notifier).state = DateTime.now();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.4),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMMM yyyy').format(selectedMonth),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
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
            const SizedBox(height: 8),

            // ── Wallets / Accounts Filter Bar ──
            Consumer(
              builder: (context, ref, _) {
                final walletsAsync = ref.watch(walletsProvider);
                final selectedWalletId = ref.watch(selectedWalletIdProvider);

                return walletsAsync.when(
                  data: (wallets) {
                    if (wallets.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(selectedWalletIdProvider.notifier).state = null;
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: selectedWalletId == null
                                    ? AppColors.primary
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: selectedWalletId == null
                                      ? AppColors.primary
                                      : theme.colorScheme.outline.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                'All Wallets',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: selectedWalletId == null ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selectedWalletId == null ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          ...wallets.map((w) {
                            final isSelected = selectedWalletId == w.id;
                            final wIcon = getWalletIcon(w.icon);
                            final wColor = getWalletColor(w.color);

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(selectedWalletIdProvider.notifier).state = w.id;
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? wColor
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isSelected
                                        ? wColor
                                        : theme.colorScheme.outline.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      wIcon,
                                      size: 12,
                                      color: isSelected ? Colors.white : wColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      w.name,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          // Add / Manage Custom Wallets Button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const ManageWalletsSheet(),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 13, color: theme.colorScheme.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Wallets',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 10),

            // ── Scrollable Body ──
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
                        const SizedBox(height: 14),

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
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const CategoryBudgetSheet(),
                                );
                              },
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 14),
                        _QuickActionsSection(
                          onWalletsTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const ManageWalletsSheet(),
                            );
                          },
                          onCalculatorTap: () => _showCalculatorDialog(context),
                          onDebtToolsTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DebtsScreen()),
                          ),
                          onCategoryBudgetsTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const CategoryBudgetSheet(),
                            );
                          },
                        ),

                        // Category breakdown chart
                        const SizedBox(height: 14),
                        const MoneyChart(),

                        // 6-Month Cashflow Trend
                        const SizedBox(height: 14),
                        const CashflowTrendChart(),

                        // Filter tabs
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              'Transactions',
                              style: AppTypography.headingSmall.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    ref.read(transactionTypeFilterProvider.notifier).state = f;
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.primary
                                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isActive ? AppColors.primary : theme.colorScheme.outline.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isActive ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ]),
                    ),
                  ),

                  // ── Transaction List ──
                  filteredTxAsync.when(
                    data: (allTxList) {
                      final hidden = ref.watch(hiddenItemsProvider);
                      final txList = allTxList.where((t) => !hidden.contains('tx_${t.id}')).toList();

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
                                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                                    child: Text(
                                      group.key,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  ...group.value.map((tx) {
                                    return _TransactionTile(
                                      transaction: tx,
                                      onDelete: () {
                                        final itemKey = 'tx_${tx.id}';
                                        final db = ref.read(databaseProvider);
                                        final hiddenNotifier = ref.read(hiddenItemsProvider.notifier);
                                        final messenger = ScaffoldMessenger.of(context);

                                        hiddenNotifier.update((state) => {...state, itemKey});
                                        messenger.clearSnackBars();

                                        bool undone = false;
                                        final timer = Timer(const Duration(seconds: 3), () async {
                                          if (!undone) {
                                            await db.deleteTransaction(tx.id);
                                            hiddenNotifier.update((state) {
                                              final s = {...state};
                                              s.remove(itemKey);
                                              return s;
                                            });
                                            ref.read(activityLogProvider.notifier).log(
                                              type: 'delete',
                                              entityType: 'transaction',
                                              entityTitle: tx.title,
                                            );
                                          }
                                          messenger.hideCurrentSnackBar();
                                        });

                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: const Text('Transaction deleted'),
                                            duration: const Duration(seconds: 3),
                                            action: SnackBarAction(
                                              label: 'UNDO',
                                              onPressed: () {
                                                undone = true;
                                                timer.cancel();
                                                messenger.hideCurrentSnackBar();
                                                hiddenNotifier.update((state) {
                                                  final s = {...state};
                                                  s.remove(itemKey);
                                                  return s;
                                                });
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      onEdit: () => _showAddEditSheet(context, ref, transaction: tx),
                                    );
                                  }),
                                  if (index < groups.length - 1) const SizedBox(height: 6),
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
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                              const SizedBox(height: 12),
                              const Text('Could not load transactions'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'money_fab',
        onPressed: () => _showAddEditSheet(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text(
          'New Transaction',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap New Transaction below to record income or expense',
              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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

  void _showCalculatorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CalculatorDialog(),
    );
  }
}

// ────────────────── QUICK ACTIONS SECTION ──────────────────

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onWalletsTap;
  final VoidCallback onCalculatorTap;
  final VoidCallback onDebtToolsTap;
  final VoidCallback onCategoryBudgetsTap;

  const _QuickActionsSection({
    required this.onWalletsTap,
    required this.onCalculatorTap,
    required this.onDebtToolsTap,
    required this.onCategoryBudgetsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Financial Tools',
                style: AppTypography.labelLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  label: 'Wallets',
                  subtitle: 'Accounts',
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.primary,
                  onTap: onWalletsTap,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _QuickActionTile(
                  label: 'Debts',
                  subtitle: 'Ledger',
                  icon: Icons.handshake_outlined,
                  iconColor: AppColors.warning,
                  onTap: onDebtToolsTap,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _QuickActionTile(
                  label: 'Budgets',
                  subtitle: 'Limits',
                  icon: Icons.pie_chart_outline_rounded,
                  iconColor: AppColors.teal,
                  onTap: onCategoryBudgetsTap,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _QuickActionTile(
                  label: 'Calc',
                  subtitle: 'Math',
                  icon: Icons.calculate_outlined,
                  iconColor: AppColors.purple,
                  onTap: onCalculatorTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────── BALANCE OVERVIEW HERO SECTION ──────────────────

class _BalanceSection extends StatelessWidget {
  final ({double income, double expense, double balance}) stats;
  const _BalanceSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPositive = stats.balance >= 0;

    return Column(
      children: [
        // ── Net Balance Hero Card ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPositive
                  ? AppColors.success.withValues(alpha: isDark ? 0.3 : 0.2)
                  : AppColors.error.withValues(alpha: isDark ? 0.3 : 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Net Monthly Balance',
                style: AppTypography.labelMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${isPositive ? '+' : ''}$currencySymbol${_formatAmount(stats.balance)}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isPositive ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Income & Expense Dual Tiles ──
        Row(
          children: [
            // Income Tile
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: isDark ? 0.25 : 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.success),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Income',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '+$currencySymbol${_formatAmount(stats.income)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Expense Tile
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: isDark ? 0.25 : 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.error),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expense',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '-$currencySymbol${_formatAmount(stats.expense)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
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

// ────────────────── BUDGET PROGRESS CARD ──────────────────

class _BudgetProgressCard extends StatelessWidget {
  final double progress;
  final double spent;
  final double budget;
  final VoidCallback? onTap;

  const _BudgetProgressCard({
    required this.progress,
    required this.spent,
    required this.budget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOverBudget = progress > 1.0;
    final isWarning = progress > 0.8 && !isOverBudget;
    final barColor = isOverBudget ? AppColors.error : isWarning ? AppColors.warning : AppColors.primary;
    final remaining = budget - spent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: barColor.withValues(alpha: isDark ? 0.35 : 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.savings_outlined, size: 18, color: barColor),
                  const SizedBox(width: 8),
                  Text(
                    'Monthly Budget',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$currencySymbol${budget.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% used',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                  Text(
                    isOverBudget
                        ? 'Over by $currencySymbol${(-remaining).toStringAsFixed(0)}'
                        : '$currencySymbol${remaining.toStringAsFixed(0)} remaining',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isOverBudget ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────── TRANSACTION TILE (100% EMOJI-FREE) ──────────────────

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TransactionTile({
    required this.transaction,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIncome = transaction.type == 'income';
    final icon = categoryMaterialIcons[transaction.category] ?? Icons.category_outlined;
    final accentColor = isIncome ? AppColors.success : AppColors.error;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.07),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onEdit();
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Outline Category Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(icon, size: 18, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Category / Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              transaction.category,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                              Text(' • ', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                              Flexible(
                                child: Text(
                                  transaction.note!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Amount
                  Text(
                    '${isIncome ? '+' : '-'}$currencySymbol${transaction.amount.toStringAsFixed(transaction.amount.truncateToDouble() == transaction.amount ? 0 : 2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────── CALCULATOR DIALOG ──────────────────

class _CalculatorDialog extends StatefulWidget {
  const _CalculatorDialog();

  @override
  State<_CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<_CalculatorDialog> {
  static final List<String> _history = [];
  String _expression = '';
  String _result = '0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Calculator',
                  style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _expression.isEmpty ? '0' : _expression,
                    style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _result,
                    style: AppTypography.headingLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Keypad
            ...[
              ['C', '(', ')', '/'],
              ['7', '8', '9', '*'],
              ['4', '5', '6', '-'],
              ['1', '2', '3', '+'],
              ['0', '.', '⌫', '='],
            ].map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: row.map((k) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _CalcButton(
                          label: k,
                          filled: k == '=',
                          onTap: () => _onKey(k),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onKey(String k) {
    setState(() {
      if (k == 'C') {
        _expression = '';
        _result = '0';
      } else if (k == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _evalLive();
        }
      } else if (k == '=') {
        _evalFinal();
      } else {
        _expression += k;
        _evalLive();
      }
    });
  }

  void _evalLive() {
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }
    final r = _calculate(_expression);
    if (r != null) {
      _result = r.toStringAsFixed(r.truncateToDouble() == r ? 0 : 2);
    }
  }

  void _evalFinal() {
    final r = _calculate(_expression);
    if (r != null) {
      final res = r.toStringAsFixed(r.truncateToDouble() == r ? 0 : 2);
      _history.insert(0, '$_expression = $res');
      _expression = res;
      _result = res;
    }
  }

  double? _calculate(String exp) {
    try {
      final tokens = _tokenize(exp);
      if (tokens.isEmpty) return null;
      final postfix = _toPostfix(tokens);
      return _evalPostfix(postfix);
    } catch (_) {
      return null;
    }
  }

  List<String> _tokenize(String exp) {
    final tokens = <String>[];
    var buf = '';
    for (int i = 0; i < exp.length; i++) {
      final ch = exp[i];
      if ('0123456789.'.contains(ch)) {
        buf += ch;
      } else if ('+-*/()'.contains(ch)) {
        if (buf.isNotEmpty) {
          tokens.add(buf);
          buf = '';
        }
        tokens.add(ch);
      }
    }
    if (buf.isNotEmpty) tokens.add(buf);
    return tokens;
  }

  List<String> _toPostfix(List<String> tokens) {
    final output = <String>[];
    final opStack = <String>[];
    final prec = {'+': 1, '-': 1, '*': 2, '/': 2};

    for (final token in tokens) {
      if (double.tryParse(token) != null) {
        output.add(token);
        continue;
      }
      while (opStack.isNotEmpty && (prec[opStack.last] ?? 0) >= (prec[token] ?? 0)) {
        output.add(opStack.removeLast());
      }
      opStack.add(token);
    }

    while (opStack.isNotEmpty) {
      output.add(opStack.removeLast());
    }
    return output;
  }

  double? _evalPostfix(List<String> postfix) {
    final stack = <double>[];
    for (final token in postfix) {
      final n = double.tryParse(token);
      if (n != null) {
        stack.add(n);
        continue;
      }

      if (stack.length < 2) return null;
      final b = stack.removeLast();
      final a = stack.removeLast();
      switch (token) {
        case '+':
          stack.add(a + b);
          break;
        case '-':
          stack.add(a - b);
          break;
        case '*':
          stack.add(a * b);
          break;
        case '/':
          if (b == 0) return null;
          stack.add(a / b);
          break;
        default:
          return null;
      }
    }
    return stack.length == 1 ? stack.single : null;
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _CalcButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: filled ? AppColors.primary : theme.colorScheme.surface,
          border: Border.all(
            color: filled ? AppColors.primary : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: filled ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
