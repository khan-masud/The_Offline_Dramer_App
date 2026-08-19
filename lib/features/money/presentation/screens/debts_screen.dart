import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../providers/notification_preferences_provider.dart';
import '../widgets/debt_share_reminder_sheet.dart';
import '../../data/money_provider.dart';
import '../../data/debt_provider.dart';

// ============================================================================
// DEBTS SCREEN - Modern Professional Ledger
// ============================================================================
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(debtFilterProvider);
    final filteredDebts = ref.watch(filteredDebtsProvider);
    final summaryAsync = ref.watch(debtSummaryProvider);
    final allDebtsAsync = ref.watch(allDebtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Manager'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              filter == DebtFilter.settled ? Icons.account_balance_wallet_rounded : Icons.history_rounded,
              color: filter == DebtFilter.settled ? AppColors.success : null,
            ),
            tooltip: filter == DebtFilter.settled ? 'Show Active Debts' : 'Settled History',
            onPressed: () {
              ref.read(debtFilterProvider.notifier).state =
                  filter == DebtFilter.settled ? DebtFilter.all : DebtFilter.settled;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Summary Overview
          summaryAsync.when(
            data: (summary) => _SummarySection(summary: summary)
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: -0.04),
            loading: () => const SizedBox(height: 100),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Modern Filter Pills with Badges
          allDebtsAsync.when(
            data: (allDebts) {
              final activeCount = allDebts.where((d) => !d.isSettled).length;
              final lentCount = allDebts.where((d) => d.type == 'given' && !d.isSettled).length;
              final borrowedCount = allDebts.where((d) => d.type == 'taken' && !d.isSettled).length;
              final now = DateTime.now();
              final startOfToday = DateTime(now.year, now.month, now.day);
              final overdueCount = allDebts.where((d) => !d.isSettled && d.dueDate != null && d.dueDate!.isBefore(startOfToday)).length;
              final settledCount = allDebts.where((d) => d.isSettled).length;

              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _FilterTabPill(
                        label: 'Active',
                        icon: Icons.all_inbox_rounded,
                        count: activeCount,
                        isActive: filter == DebtFilter.all,
                        activeColor: theme.colorScheme.primary,
                        onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.all,
                      ),
                      _FilterTabPill(
                        label: 'Lent',
                        icon: Icons.arrow_outward_rounded,
                        count: lentCount,
                        isActive: filter == DebtFilter.given,
                        activeColor: AppColors.error,
                        onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.given,
                      ),
                      _FilterTabPill(
                        label: 'Borrowed',
                        icon: Icons.south_west_rounded,
                        count: borrowedCount,
                        isActive: filter == DebtFilter.taken,
                        activeColor: AppColors.warning,
                        onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.taken,
                      ),
                      _FilterTabPill(
                        label: 'Overdue',
                        icon: Icons.warning_amber_rounded,
                        count: overdueCount,
                        isAlert: overdueCount > 0,
                        isActive: filter == DebtFilter.overdue,
                        activeColor: AppColors.error,
                        onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.overdue,
                      ),
                      _FilterTabPill(
                        label: 'Settled',
                        icon: Icons.check_circle_outline_rounded,
                        count: settledCount,
                        isActive: filter == DebtFilter.settled,
                        activeColor: AppColors.success,
                        onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.settled,
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(height: 44),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Debt List
          Expanded(
            child: filteredDebts.when(
              data: (debtList) {
                if (debtList.isEmpty) {
                  return _emptyState(context, filter);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 90),
                  physics: const BouncingScrollPhysics(),
                  itemCount: debtList.length,
                  itemBuilder: (ctx, i) => _DebtTile(debt: debtList[i])
                      .animate()
                      .fadeIn(delay: (40 * i).ms, duration: 300.ms)
                      .slideY(begin: 0.03),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      const Text('Could not load debts'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'debt_fab',
        onPressed: () => _showAddDebtSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'New Debt',
          style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, DebtFilter filter) {
    final theme = Theme.of(context);
    final isSettled = filter == DebtFilter.settled;
    final isLent = filter == DebtFilter.given;
    final isBorrowed = filter == DebtFilter.taken;
    final isOverdue = filter == DebtFilter.overdue;

    String title = 'No active debts';
    String subtitle = 'Tap + New Debt to record money lent or borrowed';
    IconData icon = Icons.account_balance_wallet_outlined;
    Color color = AppColors.primary;

    if (isSettled) {
      title = 'No settled debts';
      subtitle = 'Settled and repaid debts will appear in this archive';
      icon = Icons.check_circle_outline_rounded;
      color = AppColors.success;
    } else if (isOverdue) {
      title = 'No overdue debts';
      subtitle = 'All your debts and receivables are within their due dates!';
      icon = Icons.verified_rounded;
      color = AppColors.success;
    } else if (isLent) {
      title = 'No money lent';
      subtitle = 'Record money you have lent to others';
      icon = Icons.arrow_upward_rounded;
      color = AppColors.error;
    } else if (isBorrowed) {
      title = 'No borrowed debts';
      subtitle = 'Record loans or money you have borrowed from others';
      icon = Icons.arrow_downward_rounded;
      color = AppColors.warning;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDebtSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddEditDebtSheet(),
    );
  }
}

// ============================================================================
// SUMMARY SECTION - Clean Fintech Balance Duo Card
// ============================================================================
class _SummarySection extends StatelessWidget {
  final ({double totalGiven, double totalTaken, double givenPaid, double takenPaid, int overdueCount, double overdueAmount}) summary;
  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final givenRemaining = summary.totalGiven - summary.givenPaid;
    final takenRemaining = summary.totalTaken - summary.takenPaid;
    final netBalance = givenRemaining - takenRemaining;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              // Lent / Receivable
              Expanded(
                child: _SummaryCard(
                  title: 'To Receive',
                  subtitle: 'You Lent',
                  amount: givenRemaining,
                  totalAmount: summary.totalGiven,
                  icon: Icons.north_east_rounded,
                  accentColor: AppColors.error,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              // Borrowed / Payable
              Expanded(
                child: _SummaryCard(
                  title: 'To Pay',
                  subtitle: 'You Borrowed',
                  amount: takenRemaining,
                  totalAmount: summary.totalTaken,
                  icon: Icons.south_west_rounded,
                  accentColor: AppColors.warning,
                  theme: theme,
                ),
              ),
            ],
          ),
          if (summary.totalGiven > 0 || summary.totalTaken > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        netBalance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 16,
                        color: netBalance >= 0 ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Net Balance:',
                        style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Text(
                    '${netBalance >= 0 ? '+' : '-'}$currencySymbol${_fmt(netBalance.abs())}',
                    style: AppTypography.labelLarge.copyWith(
                      color: netBalance >= 0 ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (summary.overdueCount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text(
                    '${summary.overdueCount} Overdue debt${summary.overdueCount > 1 ? 's' : ''} ($currencySymbol${_fmt(summary.overdueAmount)})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final double totalAmount;
  final IconData icon;
  final Color accentColor;
  final ThemeData theme;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.totalAmount,
    required this.icon,
    required this.accentColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$currencySymbol${_fmt(amount)}',
            style: AppTypography.headingMedium.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            totalAmount > 0 ? 'Total $currencySymbol${_fmt(totalAmount)}' : subtitle,
            style: AppTypography.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
}

// ============================================================================
// FILTER TAB PILL
// ============================================================================
class _FilterTabPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final int count;
  final bool isActive;
  final bool isAlert;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterTabPill({
    required this.label,
    this.icon,
    required this.count,
    required this.isActive,
    this.isAlert = false,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveActiveColor = isAlert ? AppColors.error : activeColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                  ? effectiveActiveColor.withValues(alpha: 0.22)
                  : effectiveActiveColor.withValues(alpha: 0.12))
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? effectiveActiveColor
                : (isAlert
                    ? AppColors.error.withValues(alpha: 0.45)
                    : theme.colorScheme.outline.withValues(alpha: 0.2)),
            width: isActive ? 1.4 : 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? effectiveActiveColor
                    : (isAlert ? AppColors.error : theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isActive
                    ? effectiveActiveColor
                    : (isAlert ? AppColors.error : theme.colorScheme.onSurfaceVariant),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count > 0 || isAlert) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isAlert
                      ? AppColors.error.withValues(alpha: 0.15)
                      : (isActive
                          ? effectiveActiveColor.withValues(alpha: 0.2)
                          : theme.colorScheme.outline.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? effectiveActiveColor
                        : (isAlert ? AppColors.error : theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DEBT CARD TILE - Modern Fintech Card
// ============================================================================
class _DebtTile extends ConsumerWidget {
  final Debt debt;
  const _DebtTile({required this.debt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isGiven = debt.type == 'given';
    final remaining = debt.amount - debt.paidAmount;
    final progress = debt.amount > 0 ? (debt.paidAmount / debt.amount).clamp(0.0, 1.0) : 0.0;
    final isOverdue = debt.dueDate != null && debt.dueDate!.isBefore(DateTime.now()) && !debt.isSettled;
    final accentColor = isGiven ? AppColors.error : AppColors.warning;

    final nameInitials = debt.personName.trim().isNotEmpty
        ? debt.personName.trim().split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join()
        : 'D';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('debt_${debt.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
              SizedBox(width: 6),
              Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Debt?'),
              content: Text('Delete debt record for "${debt.personName}"? All payment records will also be removed.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => ref.read(databaseProvider).deleteDebt(debt.id),
        child: AppCard(
          onTap: () => _showDebtDetail(context, ref),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Initial Avatar with directional badge
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (debt.isSettled ? AppColors.success : accentColor).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (debt.isSettled ? AppColors.success : accentColor).withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            nameInitials,
                            style: AppTypography.labelLarge.copyWith(
                              color: debt.isSettled ? AppColors.success : accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            debt.isSettled
                                ? Icons.check_circle_rounded
                                : (isGiven ? Icons.north_east_rounded : Icons.south_west_rounded),
                            size: 12,
                            color: debt.isSettled ? AppColors.success : accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Name and status info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                debt.personName,
                                style: AppTypography.labelLarge.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (debt.linkedToWallet)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 14,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // Direction badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (debt.isSettled ? AppColors.success : accentColor).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                debt.isSettled ? 'Settled' : (isGiven ? 'Lent' : 'Borrowed'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: debt.isSettled ? AppColors.success : accentColor,
                                ),
                              ),
                            ),
                            if (debt.dueDate != null && !debt.isSettled) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_outlined,
                                      size: 10,
                                      color: isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isOverdue
                                          ? 'Overdue (${DateFormat('d MMM').format(debt.dueDate!)})'
                                          : DateFormat('d MMM').format(debt.dueDate!),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                                        color: isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Amount block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currencySymbol${_fmt(debt.amount)}',
                        style: AppTypography.labelLarge.copyWith(
                          color: debt.isSettled ? AppColors.success : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (!debt.isSettled && debt.paidAmount > 0)
                        Text(
                          'Due: $currencySymbol${_fmt(remaining)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Repayment Progress Bar
              if (!debt.isSettled && debt.paidAmount > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                          color: AppColors.success,
                          minHeight: 4.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% paid',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              if (debt.note != null && debt.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  debt.note!.trim(),
                  style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Quick Actions Row (Share Reminder & Quick Settle)
              if (!debt.isSettled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _shareReminder(context, debt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share_outlined, size: 13, color: theme.colorScheme.primary),
                            const SizedBox(width: 5),
                            Text(
                              'Share Reminder',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _quickSettle(context, ref, debt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, size: 13, color: AppColors.success),
                            const SizedBox(width: 4),
                            const Text(
                              'Settle',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _shareReminder(BuildContext context, Debt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DebtShareReminderSheet(debt: debt),
    );
  }

  void _quickSettle(BuildContext context, WidgetRef ref, Debt debt) {
    final remaining = debt.amount - debt.paidAmount;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settle Debt?'),
        content: Text('Mark entire debt for "${debt.personName}" as fully settled (Remaining $currencySymbol${_fmt(remaining)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              if (debt.linkedToWallet) {
                await db.settleDebtWithWallet(debt.id);
              } else {
                await db.settleDebt(debt.id);
              }
              await NotificationService().cancelDebtReminders(debt.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm Settle'),
          ),
        ],
      ),
    );
  }

  void _showDebtDetail(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _DebtDetailScreen(debtId: debt.id)),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
}

// ============================================================================
// DEBT DETAIL SCREEN - Modern Fintech Ledger Detail
// ============================================================================
class _DebtDetailScreen extends ConsumerWidget {
  final int debtId;
  const _DebtDetailScreen({required this.debtId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final debtsAsync = ref.watch(allDebtsProvider);

    return debtsAsync.when(
      data: (debts) {
        final debt = debts.where((d) => d.id == debtId).firstOrNull;
        if (debt == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Details')),
            body: const Center(child: Text('Debt record not found')),
          );
        }

        final isGiven = debt.type == 'given';
        final remaining = debt.amount - debt.paidAmount;
        final progress = debt.amount > 0 ? (debt.paidAmount / debt.amount).clamp(0.0, 1.0) : 0.0;
        final paymentsAsync = ref.watch(debtPaymentsProvider(debtId));
        final accentColor = isGiven ? AppColors.error : AppColors.warning;

        final nameInitials = debt.personName.trim().isNotEmpty
            ? debt.personName.trim().split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join()
            : 'D';

        return Scaffold(
          appBar: AppBar(
            title: Text(debt.personName),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Reminder',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => DebtShareReminderSheet(debt: debt),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Debt',
                onPressed: () => _showEditSheet(context, debt),
              ),
              if (!debt.isSettled)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  tooltip: 'Mark as Fully Settled',
                  onPressed: () async {
                    final db = ref.read(databaseProvider);
                    if (debt.linkedToWallet) {
                      await db.settleDebtWithWallet(debtId);
                    } else {
                      await db.settleDebt(debtId);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debt marked as settled')),
                      );
                    }
                  },
                ),
              if (debt.isSettled)
                IconButton(
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: 'Reopen Debt',
                  onPressed: () async {
                    final db = ref.read(databaseProvider);
                    if (debt.linkedToWallet && debt.settlementTransactionId != null) {
                      await db.unsettleDebtWithWallet(debtId);
                    } else {
                      await db.unsettleDebt(debtId);
                    }
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Ledger Card
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar & Direction Badge
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: (debt.isSettled ? AppColors.success : accentColor).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (debt.isSettled ? AppColors.success : accentColor).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                nameInitials,
                                style: AppTypography.headingMedium.copyWith(
                                  color: debt.isSettled ? AppColors.success : accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  debt.personName,
                                  style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (debt.isSettled ? AppColors.success : accentColor).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        debt.isSettled
                                            ? 'Fully Settled'
                                            : (isGiven ? 'Lent (Receivable)' : 'Borrowed (Payable)'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: debt.isSettled ? AppColors.success : accentColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Large Formatted Amount
                      Text(
                        '$currencySymbol${_fmt(debt.amount)}',
                        style: AppTypography.displayLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 34,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        debt.isSettled
                            ? 'All accounts cleared'
                            : (remaining > 0 ? 'Remaining Balance: $currencySymbol${_fmt(remaining)}' : 'Fully Paid'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: debt.isSettled ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3-Metric Bar
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _DetailMetricColumn(
                              label: 'Total',
                              value: '$currencySymbol${_fmt(debt.amount)}',
                              color: theme.colorScheme.onSurface,
                            ),
                            _metricDivider(theme),
                            _DetailMetricColumn(
                              label: 'Paid',
                              value: '$currencySymbol${_fmt(debt.paidAmount)}',
                              color: AppColors.success,
                            ),
                            _metricDivider(theme),
                            _DetailMetricColumn(
                              label: 'Remaining',
                              value: '$currencySymbol${_fmt(remaining)}',
                              color: accentColor,
                            ),
                          ],
                        ),
                      ),

                      // Progress Bar
                      if (!debt.isSettled) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                            color: AppColors.success,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}% Repaid',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04),

                const SizedBox(height: 16),

                // Meta Info Grid
                Row(
                  children: [
                    if (debt.dueDate != null)
                      Expanded(
                        child: _MetaInfoCard(
                          icon: Icons.calendar_today_rounded,
                          iconColor: theme.colorScheme.primary,
                          title: 'Due Date',
                          value: DateFormat('d MMM, yyyy').format(debt.dueDate!),
                        ),
                      ),
                    if (debt.phone != null && debt.phone!.trim().isNotEmpty) ...[
                      if (debt.dueDate != null) const SizedBox(width: 10),
                      Expanded(
                        child: _MetaInfoCard(
                          icon: Icons.phone_outlined,
                          iconColor: AppColors.teal,
                          title: 'Phone Number',
                          value: debt.phone!.trim(),
                        ),
                      ),
                    ],
                  ],
                ),

                if (debt.linkedToWallet) ...[
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Linked to Wallet', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                'Initial debt and repayments synchronize with your wallet transactions',
                                style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (debt.note != null && debt.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            debt.note!.trim(),
                            style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Payment History Ledger
                Row(
                  children: [
                    Text(
                      'Payment History',
                      style: AppTypography.headingSmall.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (!debt.isSettled)
                      TextButton.icon(
                        onPressed: () => _showAddPaymentSheet(context, ref, debt),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Payment'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                paymentsAsync.when(
                  data: (payments) {
                    if (payments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 36, color: theme.colorScheme.outline),
                              const SizedBox(height: 8),
                              Text(
                                'No payment records yet',
                                style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: payments.asMap().entries.map((e) {
                        final p = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey('payment_${p.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                            ),
                            onDismissed: (_) => ref.read(databaseProvider).deleteDebtPayment(p.id, debtId),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.payments_outlined, size: 18, color: AppColors.success),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '+$currencySymbol${_fmt(p.amount)}',
                                          style: AppTypography.labelLarge.copyWith(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (p.note != null && p.note!.trim().isNotEmpty)
                                          Text(
                                            p.note!.trim(),
                                            style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('d MMM yyyy').format(p.paidAt),
                                    style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: (40 * e.key).ms, duration: 250.ms);
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          floatingActionButton: !debt.isSettled
              ? FloatingActionButton.extended(
                  heroTag: 'payment_fab',
                  onPressed: () => _showAddPaymentSheet(context, ref, debt),
                  backgroundColor: AppColors.success,
                  icon: const Icon(Icons.payments_outlined, color: Colors.white),
                  label: Text(
                    'Record Payment',
                    style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                )
              : null,
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                const Text('Could not load debt details'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 28,
      color: theme.colorScheme.outline.withValues(alpha: 0.25),
    );
  }

  void _showEditSheet(BuildContext context, Debt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditDebtSheet(debt: debt),
    );
  }

  void _showAddPaymentSheet(BuildContext context, WidgetRef ref, Debt debt) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final remaining = debt.amount - debt.paidAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Record Payment',
                  style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Outstanding: $currencySymbol${_fmt(remaining)}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  style: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: '$currencySymbol ',
                    prefixStyle: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 12),
                // Quick Amount Fillers
                Row(
                  children: [
                    _QuickAmountChip(
                      label: 'Full (100%)',
                      onTap: () => amountCtrl.text = remaining.toStringAsFixed(remaining.truncateToDouble() == remaining ? 0 : 2),
                    ),
                    const SizedBox(width: 8),
                    _QuickAmountChip(
                      label: 'Half (50%)',
                      onTap: () => amountCtrl.text = (remaining / 2).toStringAsFixed((remaining / 2).truncateToDouble() == (remaining / 2) ? 0 : 2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Payment note (optional)...',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      await ref.read(databaseProvider).addDebtPayment(
                        DebtPaymentsCompanion(
                          debtId: Value(debt.id),
                          amount: Value(amount),
                          note: Value(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
                          paidAt: Value(DateTime.now()),
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    child: Text(
                      'Confirm Payment',
                      style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
}

class _DetailMetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailMetricColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _MetaInfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text(
                  value,
                  style: AppTypography.labelMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QUICK AMOUNT CHIP
// ============================================================================
class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmountChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

Future<void> showAddEditDebtModal(BuildContext context, {Debt? debt, DateTime? initialDueDate}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddEditDebtSheet(debt: debt, initialDueDate: initialDueDate),
  );
}

// ============================================================================
// ADD / EDIT DEBT SHEET - Modern Form
// ============================================================================
class _AddEditDebtSheet extends ConsumerStatefulWidget {
  final Debt? debt;
  final DateTime? initialDueDate;
  const _AddEditDebtSheet({this.debt, this.initialDueDate});

  @override
  ConsumerState<_AddEditDebtSheet> createState() => _AddEditDebtSheetState();
}

class _AddEditDebtSheetState extends ConsumerState<_AddEditDebtSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _phoneCtrl;
  String _type = 'given';
  DateTime? _dueDate;
  bool _linkToWallet = false;

  bool get isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.debt?.personName ?? '');
    _amountCtrl = TextEditingController(
      text: widget.debt != null
          ? widget.debt!.amount.toStringAsFixed(widget.debt!.amount.truncateToDouble() == widget.debt!.amount ? 0 : 2)
          : '',
    );
    _noteCtrl = TextEditingController(text: widget.debt?.note ?? '');
    _phoneCtrl = TextEditingController(text: widget.debt?.phone ?? '');
    _type = widget.debt?.type ?? 'given';
    _dueDate = widget.debt?.dueDate ?? widget.initialDueDate;
    _linkToWallet = widget.debt?.linkedToWallet ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) return;

    final db = ref.read(databaseProvider);
    final notifService = NotificationService();
    final now = DateTime.now();
    int targetDebtId;

    if (isEditing) {
      targetDebtId = widget.debt!.id;
      await db.updateDebt(DebtsCompanion(
        id: Value(targetDebtId),
        personName: Value(name),
        amount: Value(amount),
        paidAmount: Value(widget.debt!.paidAmount),
        type: Value(_type),
        note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
        phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
        dueDate: Value(_dueDate),
        linkedToWallet: Value(_linkToWallet),
        isSettled: Value(widget.debt!.isSettled),
        createdAt: Value(widget.debt!.createdAt),
        updatedAt: Value(now),
      ));
    } else {
      if (_linkToWallet) {
        targetDebtId = await db.addDebtWithWallet(DebtsCompanion(
          personName: Value(name),
          amount: Value(amount),
          type: Value(_type),
          note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
          phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
          dueDate: Value(_dueDate),
          linkedToWallet: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      } else {
        targetDebtId = await db.addDebt(DebtsCompanion(
          personName: Value(name),
          amount: Value(amount),
          type: Value(_type),
          note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
          phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
          dueDate: Value(_dueDate),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      }
    }

    // Schedule or Cancel Local Due Date Notification
    if (_dueDate != null && !(widget.debt?.isSettled ?? false)) {
      final notifPrefs = ref.read(notificationPreferencesProvider);
      await notifService.scheduleDebtDueReminder(
        debtId: targetDebtId,
        personName: name,
        amount: amount,
        type: _type,
        dueDate: _dueDate!,
        enableReminders: notifPrefs.enableDebtReminders,
        reminderTime: notifPrefs.debtReminderTime,
        remindDayBefore: notifPrefs.debtRemindDayBefore,
        alertMode: notifPrefs.alertMode,
      );
    } else {
      await notifService.cancelDebtReminders(targetDebtId);
    }

    if (mounted) Navigator.pop(context);
  }

  void _pickContact(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final contacts = await db.select(db.contactEntries).get();

    if (!context.mounted) return;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved contacts found. Add contacts in Birthday/Contacts section.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text('Select Contact', style: AppTypography.headingSmall),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (ctx, i) {
                  final c = contacts[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : 'C')),
                    title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.phone),
                    onTap: () {
                      setState(() {
                        _nameCtrl.text = c.displayName;
                        _phoneCtrl.text = c.phone;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isGiven = _type == 'given';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEditing ? 'Edit Debt Record' : 'New Debt Record',
                style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Segmented Type Selector
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'given'),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isGiven ? AppColors.error.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isGiven ? AppColors.error : theme.colorScheme.outline.withValues(alpha: 0.4),
                            width: isGiven ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.north_east_rounded, size: 18, color: isGiven ? AppColors.error : theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lent',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: isGiven ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'You will receive',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isGiven ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'taken'),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isGiven ? AppColors.warning.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isGiven ? AppColors.warning : theme.colorScheme.outline.withValues(alpha: 0.4),
                            width: !isGiven ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.south_west_rounded, size: 18, color: !isGiven ? AppColors.warning : theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Borrowed',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: !isGiven ? AppColors.warning : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'You need to pay',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: !isGiven ? AppColors.warning : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Person Name with Contacts picker
              TextField(
                controller: _nameCtrl,
                autofocus: !isEditing,
                decoration: InputDecoration(
                  labelText: 'Person Name',
                  hintText: 'e.g. John Doe',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contacts_rounded),
                    tooltip: 'Pick from Contacts',
                    onPressed: () => _pickContact(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Amount
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0',
                  prefixText: '$currencySymbol ',
                  prefixStyle: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),

              // Wallet Link Switch Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _linkToWallet
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _linkToWallet ? AppColors.primary.withValues(alpha: 0.3) : theme.colorScheme.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 20,
                      color: _linkToWallet ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Link to Wallet',
                            style: AppTypography.labelLarge.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            isGiven
                                ? 'Amount will be deducted from your wallet balance'
                                : 'Amount will be credited to your wallet balance',
                            style: AppTypography.labelSmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _linkToWallet,
                      onChanged: (v) => setState(() => _linkToWallet = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Due date
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (date != null) setState(() => _dueDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(
                        _dueDate != null
                            ? DateFormat('EEE, d MMM yyyy').format(_dueDate!)
                            : 'Set Due Date (Optional)',
                        style: AppTypography.bodyMedium.copyWith(
                          color: _dueDate != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _dueDate = null),
                          child: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Phone Number
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: 'e.g. +1 234 567 8900',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Note
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  hintText: 'Additional details...',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 22),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isGiven ? AppColors.error : AppColors.warning,
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : (isGiven ? 'Save Lent Debt' : 'Save Borrowed Debt'),
                    style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
