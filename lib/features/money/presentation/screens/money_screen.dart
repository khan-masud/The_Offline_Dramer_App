import 'dart:async';
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
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/money_provider.dart';
import '../../data/recurring_transaction_service.dart';
import 'debts_screen.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/money_chart.dart';

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
                    child: _isSearching
                        ? TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search transactions...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(99)),
                            ),
                            onChanged: (v) => ref.read(transactionSearchProvider.notifier).state = v,
                          )
                        : Text('Money',
                            style: AppTypography.headingLarge
                                .copyWith(color: theme.colorScheme.onSurface)),
                  ),
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 22),
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
                  if (!_isSearching)
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

                        const SizedBox(height: 14),
                        _QuickActionsSection(
                          onCalculatorTap: () => _showCalculatorDialog(context),
                          onDebtToolsTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DebtsScreen()),
                          ),
                        ).animate().fadeIn(delay: 120.ms, duration: 320.ms),

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
                                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                                    child: Text(
                                      group.key,
                                      style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                  ...group.value.asMap().entries.map((e) {
                                    return _TransactionTile(
                                      transaction: e.value,
                                      onDelete: () {
                                        final itemKey = 'tx_${e.value.id}';
                                        final db = ref.read(databaseProvider);
                                        final hiddenNotifier = ref.read(hiddenItemsProvider.notifier);
                                        final messenger = ScaffoldMessenger.of(context);
                                        
                                        hiddenNotifier.update((state) => {...state, itemKey});
                                        messenger.clearSnackBars();
                                        
                                        bool undone = false;
                                        final timer = Timer(const Duration(seconds: 3), () async {
                                          if (!undone) {
                                            await db.deleteTransaction(e.value.id);
                                            hiddenNotifier.update((state) {
                                              final s = {...state};
                                              s.remove(itemKey);
                                              return s;
                                            });
                                            ref.read(activityLogProvider.notifier).log(
                                              type: 'delete',
                                              entityType: 'transaction',
                                              entityTitle: e.value.title,
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

  void _showCalculatorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CalculatorDialog(),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onCalculatorTap;
  final VoidCallback onDebtToolsTap;

  const _QuickActionsSection({
    required this.onCalculatorTap,
    required this.onDebtToolsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Quick Actions',
                style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  label: 'Calculator',
                  subtitle: 'Quick math',
                  icon: Icons.calculate_rounded,
                  iconColor: AppColors.primary,
                  onTap: onCalculatorTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  label: 'My Debts',
                  subtitle: 'Manage debts',
                  icon: Icons.handshake_outlined,
                  iconColor: AppColors.warning,
                  onTap: onDebtToolsTap,
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _expression.isEmpty ? '0' : _expression,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _result,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 110),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'History',
                          style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurface),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(_history.clear),
                          child: Text(
                            'Clear',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final entry = _history[_history.length - 1 - index];
                          return InkWell(
                            onTap: () {
                              final parts = entry.split('=');
                              if (parts.length != 2) return;
                              setState(() {
                                _expression = parts.first.trim();
                                _result = parts.last.trim();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                entry,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            _calcRow(['C', 'DEL', '/', '*']),
            const SizedBox(height: 8),
            _calcRow(['7', '8', '9', '-']),
            const SizedBox(height: 8),
            _calcRow(['4', '5', '6', '+']),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(flex: 2, child: _CalcButton(label: '0', onTap: () => _onTap('0'))),
                const SizedBox(width: 8),
                Expanded(child: _CalcButton(label: '.', onTap: () => _onTap('.'))),
                const SizedBox(width: 8),
                Expanded(
                  child: _CalcButton(
                    label: '=',
                    onTap: () => _onTap('='),
                    filled: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcRow(List<String> labels) {
    return Row(
      children: labels
          .asMap()
          .entries
          .map(
            (entry) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: entry.key == labels.length - 1 ? 0 : 8),
                child: _CalcButton(
                  label: entry.value,
                  onTap: () => _onTap(entry.value),
                  filled: entry.value == 'C',
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _onTap(String value) {
    setState(() {
      if (value == 'C') {
        _expression = '';
        _result = '0';
        return;
      }

      if (value == 'DEL') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        _result = _expression.isEmpty ? '0' : _result;
        return;
      }

      if (value == '=') {
        final originalExpression = _expression;
        final computed = _tryEvaluate(_expression);
        _result = computed ?? 'Error';
        if (computed != null) {
          final line = '$originalExpression = $computed';
          if (originalExpression.isNotEmpty) {
            _history.remove(line);
            _history.add(line);
            if (_history.length > 8) {
              _history.removeAt(0);
            }
          }
          _expression = computed;
        }
        return;
      }

      final operators = {'+', '-', '*', '/'};
      if (operators.contains(value)) {
        if (_expression.isEmpty && value != '-') return;
        if (_expression.isNotEmpty && operators.contains(_expression[_expression.length - 1])) {
          _expression = _expression.substring(0, _expression.length - 1) + value;
        } else {
          _expression += value;
        }
      } else {
        _expression += value;
      }

      final preview = _tryEvaluate(_expression);
      if (preview != null) {
        _result = preview;
      }
    });
  }

  String? _tryEvaluate(String expression) {
    if (expression.trim().isEmpty) return '0';
    final normalized = expression;
    final tokens = _tokenize(normalized);
    if (tokens.isEmpty) return null;
    final postfix = _toPostfix(tokens);
    if (postfix.isEmpty) return null;
    final value = _evalPostfix(postfix);
    if (value == null || value.isNaN || value.isInfinite) return null;
    if ((value - value.roundToDouble()).abs() < 0.0000001) {
      return value.round().toString();
    }
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  List<String> _tokenize(String input) {
    final out = <String>[];
    final number = StringBuffer();
    final operators = {'+', '-', '*', '/'};

    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      final prev = i > 0 ? input[i - 1] : '';
      final isUnaryMinus = ch == '-' && (i == 0 || operators.contains(prev));

      if ((ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) || ch == '.' || isUnaryMinus) {
        number.write(ch);
      } else if (operators.contains(ch)) {
        if (number.isNotEmpty) {
          out.add(number.toString());
          number.clear();
        }
        out.add(ch);
      } else {
        return <String>[];
      }
    }

    if (number.isNotEmpty) {
      out.add(number.toString());
    }
    return out;
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
            color: filled ? AppColors.primary : theme.colorScheme.outline,
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
