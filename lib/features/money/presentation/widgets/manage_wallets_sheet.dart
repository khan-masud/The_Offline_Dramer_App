import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/money_provider.dart';

class ManageWalletsSheet extends ConsumerWidget {
  const ManageWalletsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final walletsAsync = ref.watch(walletsProvider);
    final balancesAsync = ref.watch(walletBalancesProvider);

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
              // ── Header Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallets & Accounts',
                        style: AppTypography.headingMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage your cash, bank & digital wallets',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
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

              // ── Wallets List ──
              walletsAsync.when(
                data: (wallets) {
                  if (wallets.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet_outlined, size: 36, color: AppColors.primary),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Wallets Added',
                              style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add your first wallet below',
                              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final balances = balancesAsync.valueOrNull ?? {};

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: wallets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final balance = balances[wallet.id] ?? wallet.initialBalance;
                      final walletIcon = getWalletIcon(wallet.icon);
                      final walletColor = getWalletColor(wallet.color);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Custom Wallet Icon Badge
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: walletColor.withValues(alpha: isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(walletIcon, size: 20, color: walletColor),
                            ),
                            const SizedBox(width: 12),

                            // Name & Initial Balance
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wallet.name,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Initial: $currencySymbol${wallet.initialBalance.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Computed Balance
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$currencySymbol${balance.toStringAsFixed(balance.truncateToDouble() == balance ? 0 : 2)}',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: balance >= 0 ? AppColors.success : AppColors.error,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Current Balance',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),

                            // Edit Action
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Edit Wallet',
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => AddEditWalletSheet(wallet: wallet),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error loading wallets: $e')),
              ),

              const SizedBox(height: 16),

              // ── Add New Wallet Button ──
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const AddEditWalletSheet(),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Add Custom Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

// ────────────────── ADD / EDIT WALLET SHEET ──────────────────

class AddEditWalletSheet extends ConsumerStatefulWidget {
  final Wallet? wallet;
  const AddEditWalletSheet({super.key, this.wallet});

  @override
  ConsumerState<AddEditWalletSheet> createState() => _AddEditWalletSheetState();
}

class _AddEditWalletSheetState extends ConsumerState<AddEditWalletSheet> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  String _selectedIcon = 'account_balance_wallet_rounded';
  String _selectedColor = 'primary';
  bool _isSaving = false;

  bool get isEditing => widget.wallet != null;

  static const List<({String key, String label, IconData icon})> _iconOptions = [
    (key: 'account_balance_wallet_rounded', label: 'Wallet', icon: Icons.account_balance_wallet_outlined),
    (key: 'payments_rounded', label: 'Cash', icon: Icons.payments_outlined),
    (key: 'account_balance_rounded', label: 'Bank', icon: Icons.account_balance_outlined),
    (key: 'phone_android_rounded', label: 'Mobile', icon: Icons.phone_android_outlined),
    (key: 'credit_card_rounded', label: 'Card', icon: Icons.credit_card_outlined),
    (key: 'savings_rounded', label: 'Savings', icon: Icons.savings_outlined),
    (key: 'currency_exchange_rounded', label: 'Exchange', icon: Icons.currency_exchange_rounded),
    (key: 'paid_outlined', label: 'Money', icon: Icons.paid_outlined),
  ];

  static const List<({String key, String label, Color color})> _colorOptions = [
    (key: 'primary', label: 'Indigo', color: Color(0xFF6366F1)),
    (key: 'green', label: 'Emerald', color: Color(0xFF10B981)),
    (key: 'blue', label: 'Sky', color: Color(0xFF0EA5E9)),
    (key: 'pink', label: 'bKash Pink', color: Color(0xFFEC4899)),
    (key: 'orange', label: 'Nagad Orange', color: Color(0xFFF97316)),
    (key: 'purple', label: 'Purple', color: Color(0xFF8B5CF6)),
    (key: 'teal', label: 'Teal', color: Color(0xFF14B8A6)),
    (key: 'amber', label: 'Amber', color: Color(0xFFF59E0B)),
  ];

  static const List<({String name, String icon, String color})> _presets = [
    (name: 'Cash', icon: 'payments_rounded', color: 'green'),
    (name: 'Bank Account', icon: 'account_balance_rounded', color: 'blue'),
    (name: 'bKash', icon: 'phone_android_rounded', color: 'pink'),
    (name: 'Nagad', icon: 'phone_android_rounded', color: 'orange'),
    (name: 'Rocket', icon: 'phone_android_rounded', color: 'purple'),
    (name: 'Credit Card', icon: 'credit_card_rounded', color: 'teal'),
    (name: 'Savings', icon: 'savings_rounded', color: 'amber'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.wallet != null) {
      _nameCtrl.text = widget.wallet!.name;
      _balanceCtrl.text = widget.wallet!.initialBalance.toStringAsFixed(
        widget.wallet!.initialBalance.truncateToDouble() == widget.wallet!.initialBalance ? 0 : 2,
      );
      _selectedIcon = widget.wallet!.icon;
      _selectedColor = widget.wallet!.color;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a wallet name')),
      );
      return;
    }

    final initialBalance = double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    try {
      if (isEditing) {
        await db.updateWallet(WalletsCompanion(
          id: Value(widget.wallet!.id),
          name: Value(name),
          icon: Value(_selectedIcon),
          color: Value(_selectedColor),
          initialBalance: Value(initialBalance),
          createdAt: Value(widget.wallet!.createdAt),
        ));
        ref.read(activityLogProvider.notifier).log(
          type: 'update',
          entityType: 'wallet',
          entityTitle: name,
        );
      } else {
        await db.addWallet(WalletsCompanion(
          name: Value(name),
          icon: Value(_selectedIcon),
          color: Value(_selectedColor),
          initialBalance: Value(initialBalance),
          createdAt: Value(DateTime.now()),
        ));
        ref.read(activityLogProvider.notifier).log(
          type: 'add',
          entityType: 'wallet',
          entityTitle: name,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving wallet: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (!isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Wallet?'),
        content: Text(
          'Are you sure you want to delete "${widget.wallet!.name}"? Existing transactions linked to this wallet will remain intact.',
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
    await db.deleteWallet(widget.wallet!.id);
    ref.read(activityLogProvider.notifier).log(
      type: 'delete',
      entityType: 'wallet',
      entityTitle: widget.wallet!.name,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeThemeColor = getWalletColor(_selectedColor);

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
              // ── Header Row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Wallet' : 'New Custom Wallet',
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
                          tooltip: 'Delete Wallet',
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
                          backgroundColor: activeThemeColor,
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

              // ── Quick Presets (Only on New) ──
              if (!isEditing) ...[
                Text(
                  'Quick Presets',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: _presets.map((p) {
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _nameCtrl.text = p.name;
                            _selectedIcon = p.icon;
                            _selectedColor = p.color;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.4),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(getWalletIcon(p.icon), size: 12, color: getWalletColor(p.color)),
                              const SizedBox(width: 4),
                              Text(p.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Wallet Name Input ──
              TextField(
                controller: _nameCtrl,
                autofocus: !isEditing,
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Wallet / Account Name',
                  hintText: 'e.g. City Bank, Upay, Savings, Petty Cash...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: activeThemeColor, width: 1.2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // ── Initial Balance Input ──
              TextField(
                controller: _balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Starting Balance',
                  hintText: '0',
                  prefixText: '$currencySymbol ',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: activeThemeColor, width: 1.2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // ── Select Icon ──
              Text(
                'Wallet Icon',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconOptions.map((opt) {
                  final isSelected = _selectedIcon == opt.key;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedIcon = opt.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeThemeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.25 : 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? activeThemeColor : theme.colorScheme.outline.withValues(alpha: 0.12),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(opt.icon, size: 16, color: isSelected ? activeThemeColor : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? activeThemeColor : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ── Select Color Theme ──
              Text(
                'Color Theme',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions.map((opt) {
                  final isSelected = _selectedColor == opt.key;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedColor = opt.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: opt.color,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: opt.color.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
