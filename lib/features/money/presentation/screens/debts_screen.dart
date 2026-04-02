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
import '../../data/money_provider.dart';
import '../../data/debt_provider.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(debtFilterProvider);
    final filteredDebts = ref.watch(filteredDebtsProvider);
    final summaryAsync = ref.watch(debtSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Settled History',
            onPressed: () {
              ref.read(debtFilterProvider.notifier).state =
                  filter == DebtFilter.settled ? DebtFilter.all : DebtFilter.settled;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          summaryAsync.when(
            data: (summary) => _SummarySection(summary: summary)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.05),
            loading: () => const SizedBox(height: 80),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Filter tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isActive: filter == DebtFilter.all,
                  onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.all,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Lent',
                  emoji: '📤',
                  isActive: filter == DebtFilter.given,
                  activeColor: AppColors.error,
                  onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.given,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Borrowed',
                  emoji: '📥',
                  isActive: filter == DebtFilter.taken,
                  activeColor: AppColors.warning,
                  onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.taken,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Settled',
                  emoji: '✅',
                  isActive: filter == DebtFilter.settled,
                  activeColor: AppColors.success,
                  onTap: () => ref.read(debtFilterProvider.notifier).state = DebtFilter.settled,
                ),
              ],
            ),
          ),

          // Debt list
          Expanded(
            child: filteredDebts.when(
              data: (debtList) {
                if (debtList.isEmpty) {
                  return _emptyState(context, filter);
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: debtList.length,
                  itemBuilder: (ctx, i) => _DebtTile(debt: debtList[i])
                      .animate()
                      .fadeIn(delay: (60 * i).ms, duration: 350.ms)
                      .slideX(begin: 0.03),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'debt_fab',
        onPressed: () => _showAddDebtSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Debt', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _emptyState(BuildContext context, DebtFilter filter) {
    final theme = Theme.of(context);
    final isSettled = filter == DebtFilter.settled;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isSettled ? AppColors.success : AppColors.purple).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSettled ? Icons.check_circle_outline_rounded : Icons.handshake_outlined,
              size: 48,
              color: isSettled ? AppColors.success : AppColors.purple,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSettled ? 'No settled debts' : 'No debts yet',
            style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            isSettled ? 'Settled debts will appear here' : 'Tap + to add a debt entry',
            style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
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

// ==================== SUMMARY SECTION ====================
class _SummarySection extends StatelessWidget {
  final ({double totalGiven, double totalTaken, double givenPaid, double takenPaid}) summary;
  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final givenRemaining = summary.totalGiven - summary.givenPaid;
    final takenRemaining = summary.totalTaken - summary.takenPaid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Given (others owe me)
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.error),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Receivable', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currencySymbol${_fmt(givenRemaining)}',
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (summary.totalGiven > 0)
                    Text(
                      'Total $currencySymbol${_fmt(summary.totalGiven)}',
                      style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Taken (I owe others)
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.warning),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Payable', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currencySymbol${_fmt(takenRemaining)}',
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (summary.totalTaken > 0)
                    Text(
                      'Total $currencySymbol${_fmt(summary.totalTaken)}',
                      style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
}

// ==================== FILTER CHIP ====================
class _FilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.emoji,
    required this.isActive,
    this.activeColor = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(color: isActive ? activeColor : theme.colorScheme.outline),
          ),
          child: Center(
            child: Text(
              emoji != null ? '$emoji $label' : label,
              style: AppTypography.labelSmall.copyWith(
                color: isActive ? activeColor : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== DEBT TILE ====================
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
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Debt?'),
              content: Text('Delete debt entry for ${debt.personName}? This will also remove all payment records.'),
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
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isGiven ? AppColors.error : AppColors.warning).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        debt.personName.characters.first.toUpperCase(),
                        style: AppTypography.headingSmall.copyWith(
                          color: isGiven ? AppColors.error : AppColors.warning,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                debt.personName,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (debt.isSettled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                ),
                                child: Text('Settled ✅', style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              isGiven ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 14,
                              color: isGiven ? AppColors.error : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isGiven ? 'Lent' : 'Borrowed',
                              style: AppTypography.labelSmall.copyWith(
                                color: isGiven ? AppColors.error : AppColors.warning,
                              ),
                            ),
                            if (debt.dueDate != null) ...[
                              const SizedBox(width: 10),
                              Icon(
                                Icons.event_rounded,
                                size: 13,
                                color: isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                DateFormat('d MMM').format(debt.dueDate!),
                                style: AppTypography.labelSmall.copyWith(
                                  color: isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currencySymbol${_fmt(debt.amount)}',
                        style: AppTypography.labelLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!debt.isSettled && debt.paidAmount > 0)
                        Text(
                          'Remaining $currencySymbol${_fmt(remaining)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // Progress bar
              if (!debt.isSettled && debt.paidAmount > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.colorScheme.outline,
                    color: AppColors.success,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% পরিশোধ হয়েছে',
                  style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              if (debt.note != null && debt.note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  debt.note!,
                  style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
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

// ==================== DEBT DETAIL SCREEN ====================
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
            body: const Center(child: Text('Debt not found')),
          );
        }

        final isGiven = debt.type == 'given';
        final remaining = debt.amount - debt.paidAmount;
        final progress = debt.amount > 0 ? (debt.paidAmount / debt.amount).clamp(0.0, 1.0) : 0.0;
        final paymentsAsync = ref.watch(debtPaymentsProvider(debtId));

        return Scaffold(
          appBar: AppBar(
            title: Text(debt.personName),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditSheet(context, debt),
              ),
              if (!debt.isSettled)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  tooltip: 'Mark as settled',
                  onPressed: () async {
                    await ref.read(databaseProvider).settleDebt(debtId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Marked as settled ✅')),
                      );
                    }
                  },
                ),
              if (debt.isSettled)
                IconButton(
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: 'Reopen',
                  onPressed: () => ref.read(databaseProvider).unsettleDebt(debtId),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main info card
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Person avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: (isGiven ? AppColors.error : AppColors.warning).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            debt.personName.characters.first.toUpperCase(),
                            style: AppTypography.displayLarge.copyWith(
                              color: isGiven ? AppColors.error : AppColors.warning,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        debt.personName,
                        style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isGiven ? AppColors.error : AppColors.warning).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Text(
                          isGiven ? '📤 Lent (Receivable)' : '📥 Borrowed (Payable)',
                          style: AppTypography.labelMedium.copyWith(
                            color: isGiven ? AppColors.error : AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Amount
                      Text(
                        '$currencySymbol${_fmt(debt.amount)}',
                        style: AppTypography.displayLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (debt.isSettled)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text('✅ সম্পূর্ণ শোধ হয়েছে', style: AppTypography.labelMedium.copyWith(color: AppColors.success)),
                          ),
                        ),
                      if (!debt.isSettled) ...[
                        const SizedBox(height: 16),
                        // Progress
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: theme.colorScheme.outline,
                            color: AppColors.success,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Paid: $currencySymbol${_fmt(debt.paidAmount)}',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.success),
                            ),
                            Text(
                              'Remaining: $currencySymbol${_fmt(remaining)}',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.warning),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                const SizedBox(height: 16),

                // Details row
                Row(
                  children: [
                    if (debt.dueDate != null)
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.event_rounded, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Due Date', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  Text(
                                    DateFormat('d MMM, yyyy').format(debt.dueDate!),
                                    style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurface),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (debt.phone != null && debt.phone!.isNotEmpty) ...[
                      if (debt.dueDate != null) const SizedBox(width: 12),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Phone', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    Text(
                                      debt.phone!,
                                      style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurface),
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
                  ],
                ),

                if (debt.note != null && debt.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            debt.note!,
                            style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Payments section
                Row(
                  children: [
                    Text('পরিশোধের হিসাব', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
                    const Spacer(),
                    if (!debt.isSettled)
                      TextButton.icon(
                        onPressed: () => _showAddPaymentSheet(context, ref, debt),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Payment'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                paymentsAsync.when(
                  data: (payments) {
                    if (payments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No payments recorded yet',
                            style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                                color: AppColors.error.withValues(alpha: 0.9),
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
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
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
                                          '$currencySymbol${_fmt(p.amount)}',
                                          style: AppTypography.bodyLarge.copyWith(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (p.note != null && p.note!.isNotEmpty)
                                          Text(
                                            p.note!,
                                            style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('d MMM, yy').format(p.paidAt),
                                    style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: (60 * e.key).ms, duration: 300.ms);
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          floatingActionButton: !debt.isSettled
              ? FloatingActionButton.extended(
                  heroTag: 'payment_fab',
                  onPressed: () => _showAddPaymentSheet(context, ref, debt),
                  backgroundColor: AppColors.success,
                  icon: const Icon(Icons.payments_outlined, color: Colors.white),
                  label: Text('পরিশোধ', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
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
        body: Center(child: Text('Error: $e')),
      ),
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
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('পরিশোধ যোগ করুন', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(
                'বাকি আছে: $currencySymbol${_fmt(remaining)}',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.warning),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '0',
                  prefixText: '$currencySymbol ',
                  prefixStyle: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              // Quick fill buttons
              Row(
                children: [
                  _QuickAmountChip(
                    label: 'সম্পূর্ণ',
                    onTap: () => amountCtrl.text = remaining.toStringAsFixed(0),
                  ),
                  const SizedBox(width: 8),
                  _QuickAmountChip(
                    label: 'অর্ধেক',
                    onTap: () => amountCtrl.text = (remaining / 2).toStringAsFixed(0),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(hintText: 'Note (optional)...'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('পরিশোধ করুন', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
}

// ==================== QUICK AMOUNT CHIP ====================
class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmountChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
      ),
    );
  }
}

// ==================== ADD/EDIT DEBT SHEET ====================
class _AddEditDebtSheet extends ConsumerStatefulWidget {
  final Debt? debt;
  const _AddEditDebtSheet({this.debt});

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
    _dueDate = widget.debt?.dueDate;
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
    final now = DateTime.now();

    if (isEditing) {
      await db.updateDebt(DebtsCompanion(
        id: Value(widget.debt!.id),
        personName: Value(name),
        amount: Value(amount),
        paidAmount: Value(widget.debt!.paidAmount),
        type: Value(_type),
        note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
        phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
        dueDate: Value(_dueDate),
        isSettled: Value(widget.debt!.isSettled),
        createdAt: Value(widget.debt!.createdAt),
        updatedAt: Value(now),
      ));
    } else {
      await db.addDebt(DebtsCompanion(
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

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'Edit Debt' : 'New Debt',
              style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),

            // Type toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'given'),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _type == 'given' ? AppColors.error.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: _type == 'given' ? AppColors.error : theme.colorScheme.outline,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 20,
                              color: _type == 'given' ? AppColors.error : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 4),
                          Text('📤 Lent', style: AppTypography.labelMedium.copyWith(
                            color: _type == 'given' ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                          )),
                          Text('(Receivable)', style: AppTypography.labelSmall.copyWith(
                            color: _type == 'given' ? AppColors.error.withValues(alpha: 0.7) : theme.colorScheme.outline,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'taken'),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _type == 'taken' ? AppColors.warning.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: _type == 'taken' ? AppColors.warning : theme.colorScheme.outline,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 20,
                              color: _type == 'taken' ? AppColors.warning : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 4),
                          Text('📥 Borrowed', style: AppTypography.labelMedium.copyWith(
                            color: _type == 'taken' ? AppColors.warning : theme.colorScheme.onSurfaceVariant,
                          )),
                          Text('(Payable)', style: AppTypography.labelSmall.copyWith(
                            color: _type == 'taken' ? AppColors.warning.withValues(alpha: 0.7) : theme.colorScheme.outline,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Person name
            TextField(
              controller: _nameCtrl,
              autofocus: !isEditing,
              decoration: const InputDecoration(
                hintText: 'Person\'s name...',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              style: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '$currencySymbol ',
                prefixStyle: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),

            // Phone (optional)
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Phone number (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
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
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (date != null) setState(() => _dueDate = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      _dueDate != null
                          ? DateFormat('EEE, d MMM yyyy').format(_dueDate!)
                          : 'Due date (optional)',
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

            // Note
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(hintText: 'Note (optional)...'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'given' ? AppColors.error : AppColors.warning,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    isEditing ? 'Save Changes' : (_type == 'given' ? '📤 Lent — Save' : '📥 Borrowed — Save'),
                    style: AppTypography.labelLarge.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
