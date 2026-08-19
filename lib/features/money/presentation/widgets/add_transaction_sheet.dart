import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/money_provider.dart';
import 'manage_wallets_sheet.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? transaction;
  final DateTime? initialDate;
  const AddTransactionSheet({super.key, this.transaction, this.initialDate});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  String _type = 'expense';
  String _category = 'Food';
  late DateTime _date;
  int? _walletId;
  bool _isRecurring = false;
  String _recurringPattern = 'monthly';
  final List<String> _recurringOptions = ['daily', 'weekly', 'monthly', 'yearly'];
  bool _isSaving = false;

  bool get isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _date = widget.transaction?.date ?? widget.initialDate ?? DateTime.now();
    _amountCtrl = TextEditingController(
      text: widget.transaction?.amount.toStringAsFixed(
            widget.transaction!.amount.truncateToDouble() == widget.transaction!.amount ? 0 : 2,
          ) ??
          '',
    );
    _titleCtrl = TextEditingController(text: widget.transaction?.title ?? '');
    _noteCtrl = TextEditingController(text: widget.transaction?.note ?? '');
    _type = widget.transaction?.type ?? 'expense';
    _category = widget.transaction?.category ?? 'Food';
    _walletId = widget.transaction?.walletId;
    _isRecurring = widget.transaction?.isRecurring ?? false;
    _recurringPattern = widget.transaction?.recurringPattern ?? 'monthly';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories => _type == 'expense' ? expenseCategories : incomeCategories;

  Future<void> _save() async {
    if (_isSaving) return;

    final amountText = _amountCtrl.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
      }
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a title')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    try {
      if (isEditing) {
        await db.updateTransaction(TransactionsCompanion(
          id: Value(widget.transaction!.id),
          amount: Value(amount),
          type: Value(_type),
          title: Value(_titleCtrl.text.trim()),
          category: Value(_category),
          note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
          date: Value(_date),
          walletId: Value(_walletId),
          isRecurring: Value(_isRecurring),
          recurringPattern: Value(_isRecurring ? _recurringPattern : null),
          createdAt: Value(widget.transaction!.createdAt),
        ));
        ref.read(activityLogProvider.notifier).log(
          type: 'update',
          entityType: 'transaction',
          entityTitle: _titleCtrl.text.trim(),
        );
      } else {
        await db.addTransaction(TransactionsCompanion(
          amount: Value(amount),
          type: Value(_type),
          title: Value(_titleCtrl.text.trim()),
          category: Value(_category),
          note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
          date: Value(_date),
          walletId: Value(_walletId),
          isRecurring: Value(_isRecurring),
          recurringPattern: Value(_isRecurring ? _recurringPattern : null),
          createdAt: Value(now),
        ));
        ref.read(activityLogProvider.notifier).log(
          type: 'add',
          entityType: 'transaction',
          entityTitle: _titleCtrl.text.trim(),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (!isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete "${widget.transaction!.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await db.deleteTransaction(widget.transaction!.id);
    ref.read(activityLogProvider.notifier).log(
      type: 'delete',
      entityType: 'transaction',
      entityTitle: widget.transaction!.title,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    if (!_categories.contains(_category)) {
      _category = _categories.first;
    }

    final isIncome = _type == 'income';
    final accentColor = isIncome ? AppColors.success : AppColors.error;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: bottomInset + 20,
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
              // ── Header Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Transaction' : 'New Transaction',
                    style: AppTypography.headingMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (isEditing) ...[
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                          onPressed: _delete,
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                      ],
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Type Toggle (Expense / Income) ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _type = 'expense');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isIncome ? AppColors.error : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isIncome
                                ? [
                                    BoxShadow(
                                      color: AppColors.error.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: !isIncome ? Colors.white : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Expense',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: !isIncome ? FontWeight.bold : FontWeight.w500,
                                  color: !isIncome ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _type = 'income');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isIncome ? AppColors.success : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isIncome
                                ? [
                                    BoxShadow(
                                      color: AppColors.success.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: isIncome ? Colors.white : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Income',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isIncome ? FontWeight.bold : FontWeight.w500,
                                  color: isIncome ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Hero Amount Input ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$currencySymbol ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _amountCtrl,
                        autofocus: !isEditing,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 24,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Title Input
              TextField(
                controller: _titleCtrl,
                style: AppTypography.bodyMedium.copyWith(fontSize: 14.5, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Transaction title (e.g. Grocery, Lunch, Salary)...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65), fontSize: 13.5),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: accentColor, width: 1.2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              // ── Category Pills Strip (100% Emoji-Free) ──
              Text(
                'Category',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _categories.map((cat) {
                  final isActive = _category == cat;
                  final icon = categoryMaterialIcons[cat] ?? Icons.category_outlined;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _category = cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? accentColor.withValues(alpha: isDark ? 0.22 : 0.12)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive ? accentColor : theme.colorScheme.outline.withValues(alpha: 0.15),
                          width: isActive ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: isActive ? accentColor : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                              color: isActive ? accentColor : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ── Account / Wallet Selector ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Account / Wallet',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AddEditWalletSheet(),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Wallet', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Consumer(
                builder: (context, ref, _) {
                  final walletsAsync = ref.watch(walletsProvider);
                  return walletsAsync.when(
                    data: (wallets) {
                      if (wallets.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...wallets.map((w) {
                            final isSelected = _walletId == w.id;
                            final wIcon = getWalletIcon(w.icon);
                            final wColor = getWalletColor(w.color);

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _walletId = isSelected ? null : w.id);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? wColor.withValues(alpha: isDark ? 0.22 : 0.12)
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? wColor : theme.colorScheme.outline.withValues(alpha: 0.15),
                                    width: isSelected ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      wIcon,
                                      size: 13,
                                      color: isSelected ? wColor : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      w.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? wColor : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ── Date Selector ──
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) setState(() => _date = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEE, MMM d, yyyy').format(_date),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.edit_calendar_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Recurring Transaction ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isRecurring
                        ? AppColors.purple.withValues(alpha: 0.4)
                        : theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 18,
                              color: _isRecurring ? AppColors.purple : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recurring Transaction',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isRecurring,
                          onChanged: (v) {
                            HapticFeedback.lightImpact();
                            setState(() => _isRecurring = v);
                          },
                          activeThumbColor: AppColors.purple,
                        ),
                      ],
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: _recurringOptions.map((opt) {
                          final isActive = _recurringPattern == opt;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _recurringPattern = opt),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.purple.withValues(alpha: 0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isActive ? AppColors.purple : theme.colorScheme.outline.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    opt[0].toUpperCase() + opt.substring(1),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      color: isActive ? AppColors.purple : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Note Input
              TextField(
                controller: _noteCtrl,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Note or remarks (optional)...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65), fontSize: 13),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
