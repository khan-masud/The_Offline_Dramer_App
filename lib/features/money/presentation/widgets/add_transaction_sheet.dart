import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/money_provider.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? transaction;
  const AddTransactionSheet({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  String _type = 'expense';
  String _category = 'Food';
  DateTime _date = DateTime.now();

  bool get isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.transaction?.amount.toStringAsFixed(
        widget.transaction!.amount.truncateToDouble() == widget.transaction!.amount ? 0 : 2,
      ) ?? '',
    );
    _titleCtrl = TextEditingController(text: widget.transaction?.title ?? '');
    _noteCtrl = TextEditingController(text: widget.transaction?.note ?? '');
    _type = widget.transaction?.type ?? 'expense';
    _category = widget.transaction?.category ?? 'Food';
    _date = widget.transaction?.date ?? DateTime.now();
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
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    if (_titleCtrl.text.trim().isEmpty) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    if (isEditing) {
      await db.updateTransaction(TransactionsCompanion(
        id: Value(widget.transaction!.id),
        amount: Value(amount),
        type: Value(_type),
        title: Value(_titleCtrl.text.trim()),
        category: Value(_category),
        note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
        date: Value(_date),
        createdAt: Value(widget.transaction!.createdAt),
      ));
    } else {
      await db.addTransaction(TransactionsCompanion(
        amount: Value(amount),
        type: Value(_type),
        title: Value(_titleCtrl.text.trim()),
        category: Value(_category),
        note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
        date: Value(_date),
        createdAt: Value(now),
      ));
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Ensure current category is valid for the selected type
    if (!_categories.contains(_category)) {
      _category = _categories.first;
    }

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
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'Edit Transaction' : 'New Transaction',
              style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),

            // Type toggle (Income / Expense)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _type = 'income'; }),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'income' ? AppColors.success.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: _type == 'income' ? AppColors.success : theme.colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 18,
                            color: _type == 'income' ? AppColors.success : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text('Income', style: AppTypography.labelLarge.copyWith(
                            color: _type == 'income' ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _type = 'expense'; }),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'expense' ? AppColors.error.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: _type == 'expense' ? AppColors.error : theme.colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 18,
                            color: _type == 'expense' ? AppColors.error : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text('Expense', style: AppTypography.labelLarge.copyWith(
                            color: _type == 'expense' ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountCtrl,
              autofocus: !isEditing,
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

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Transaction title...'),
              style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),

            // Category
            Text('Category', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isActive = _category == cat;
                final emoji = categoryIcons[cat] ?? '📌';
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (_type == 'income' ? AppColors.success : AppColors.error).withValues(alpha: 0.15) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      border: Border.all(
                        color: isActive
                            ? (_type == 'income' ? AppColors.success : AppColors.error)
                            : theme.colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(cat, style: AppTypography.labelMedium.copyWith(
                          color: isActive
                              ? (_type == 'income' ? AppColors.success : AppColors.error)
                              : theme.colorScheme.onSurfaceVariant,
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date picker
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEE, MMM d, yyyy').format(_date),
                      style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
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
              style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 24),

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'income' ? AppColors.success : AppColors.primary,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    isEditing ? 'Save Changes' : (_type == 'income' ? 'Add Income' : 'Add Expense'),
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
