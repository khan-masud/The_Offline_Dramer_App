import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Currency symbol
const String currencySymbol = '৳';

// Expense categories
const List<String> expenseCategories = [
  'Food', 'Transport', 'Shopping', 'Bills',
  'Health', 'Education', 'Entertainment',
  'Debt Given', 'Debt Repaid', 'Other',
];

// Income categories
const List<String> incomeCategories = [
  'Salary', 'Freelance', 'Gift',
  'Debt Received', 'Debt Settled', 'Other',
];

// Clean Material Outline Category Icons (100% Emoji-Free)
const Map<String, IconData> categoryMaterialIcons = {
  'Food': Icons.restaurant_outlined,
  'Transport': Icons.directions_car_outlined,
  'Shopping': Icons.shopping_bag_outlined,
  'Bills': Icons.receipt_long_outlined,
  'Health': Icons.medical_services_outlined,
  'Education': Icons.school_outlined,
  'Entertainment': Icons.sports_esports_outlined,
  'Salary': Icons.account_balance_wallet_outlined,
  'Freelance': Icons.laptop_mac_outlined,
  'Gift': Icons.card_giftcard_outlined,
  'Debt Given': Icons.arrow_outward_rounded,
  'Debt Repaid': Icons.payments_outlined,
  'Debt Received': Icons.arrow_downward_rounded,
  'Debt Settled': Icons.check_circle_outline_rounded,
  'Other': Icons.category_outlined,
};

// Category icons
const Map<String, String> categoryIcons = {
  'Food': '🍕',
  'Transport': '🚗',
  'Shopping': '🛒',
  'Bills': '📄',
  'Health': '💊',
  'Education': '📚',
  'Entertainment': '🎮',
  'Salary': '💰',
  'Freelance': '💻',
  'Gift': '🎁',
  'Debt Given': '📤',
  'Debt Repaid': '💸',
  'Debt Received': '📥',
  'Debt Settled': '💰',
  'Other': '📌',
};

// ==================== WALLETS ====================

// Helper to resolve icon from stored string key
IconData getWalletIcon(String? iconKey) {
  return switch (iconKey) {
    'payments_rounded' || 'cash' => Icons.payments_outlined,
    'account_balance_rounded' || 'bank' => Icons.account_balance_outlined,
    'phone_android_rounded' || 'mobile' => Icons.phone_android_outlined,
    'credit_card_rounded' || 'card' => Icons.credit_card_outlined,
    'savings_rounded' || 'savings' => Icons.savings_outlined,
    'currency_exchange_rounded' || 'exchange' => Icons.currency_exchange_rounded,
    'attach_money_rounded' || 'money' => Icons.attach_money_rounded,
    'paid_outlined' || 'paid' => Icons.paid_outlined,
    _ => Icons.account_balance_wallet_outlined,
  };
}

// Helper to resolve theme color from stored string key
Color getWalletColor(String? colorKey, {Color fallback = const Color(0xFF6366F1)}) {
  return switch (colorKey) {
    'green' => const Color(0xFF10B981),
    'blue' => const Color(0xFF0EA5E9),
    'pink' => const Color(0xFFEC4899),
    'orange' => const Color(0xFFF97316),
    'purple' => const Color(0xFF8B5CF6),
    'teal' => const Color(0xFF14B8A6),
    'amber' => const Color(0xFFF59E0B),
    'red' => const Color(0xFFEF4444),
    _ => fallback,
  };
}

final walletsProvider = StreamProvider<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  // Ensure default wallets exist
  db.ensureDefaultWallets();
  return db.watchAllWallets();
});

// All transactions stream (for lifetime wallet balances)
final allTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTransactions();
});

// Map of wallet ID to computed balance: initialBalance + sum(income) - sum(expense)
final walletBalancesProvider = Provider<AsyncValue<Map<int, double>>>((ref) {
  final walletsAsync = ref.watch(walletsProvider);
  final txAsync = ref.watch(allTransactionsProvider);

  if (walletsAsync.isLoading || txAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (walletsAsync.hasError) return AsyncValue.error(walletsAsync.error!, walletsAsync.stackTrace!);
  if (txAsync.hasError) return AsyncValue.error(txAsync.error!, txAsync.stackTrace!);

  final wallets = walletsAsync.value ?? [];
  final txList = txAsync.value ?? [];

  final Map<int, double> balances = {};
  for (final w in wallets) {
    balances[w.id] = w.initialBalance;
  }
  for (final tx in txList) {
    if (tx.walletId != null && balances.containsKey(tx.walletId!)) {
      if (tx.type == 'income') {
        balances[tx.walletId!] = balances[tx.walletId!]! + tx.amount;
      } else if (tx.type == 'expense') {
        balances[tx.walletId!] = balances[tx.walletId!]! - tx.amount;
      }
    }
  }
  return AsyncValue.data(balances);
});

// Selected wallet filter (null = all wallets)
final selectedWalletIdProvider = StateProvider<int?>((ref) => null);

// Active month filter
final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Transaction type filter
enum TransactionTypeFilter { all, income, expense }
final transactionTypeFilterProvider = StateProvider<TransactionTypeFilter>((ref) => TransactionTypeFilter.all);

// Transaction search query
final transactionSearchProvider = StateProvider<String>((ref) => '');

// Month transactions stream
final monthTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  return db.watchMonthTransactions(month.year, month.month);
});

// Filtered transactions (by type, wallet, and search)
final filteredTransactionsProvider = Provider<AsyncValue<List<Transaction>>>((ref) {
  final txAsync = ref.watch(monthTransactionsProvider);
  final filter = ref.watch(transactionTypeFilterProvider);
  final selectedWalletId = ref.watch(selectedWalletIdProvider);
  final searchQuery = ref.watch(transactionSearchProvider).toLowerCase();

  return txAsync.whenData((txList) {
    List<Transaction> result = txList;

    if (selectedWalletId != null) {
      result = result.where((t) => t.walletId == selectedWalletId).toList();
    }

    if (searchQuery.isNotEmpty) {
      result = result.where((t) => 
        t.title.toLowerCase().contains(searchQuery) ||
        (t.note?.toLowerCase().contains(searchQuery) ?? false) ||
        t.category.toLowerCase().contains(searchQuery)
      ).toList();
    }

    switch (filter) {
      case TransactionTypeFilter.all:
        return result;
      case TransactionTypeFilter.income:
        return result.where((t) => t.type == 'income').toList();
      case TransactionTypeFilter.expense:
        return result.where((t) => t.type == 'expense').toList();
    }
  });
});

// Month stats (income, expense, balance) for current wallet/filters
final monthStatsProvider = Provider<AsyncValue<({double income, double expense, double balance})>>((ref) {
  final txAsync = ref.watch(monthTransactionsProvider);
  final selectedWalletId = ref.watch(selectedWalletIdProvider);

  return txAsync.whenData((txList) {
    double income = 0;
    double expense = 0;
    for (final tx in txList) {
      if (selectedWalletId != null && tx.walletId != selectedWalletId) continue;
      if (tx.type == 'income') {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    return (income: income, expense: expense, balance: income - expense);
  });
});

// Daily burn rate (average daily expense for active month)
final dailyBurnRateProvider = Provider<AsyncValue<double>>((ref) {
  final statsAsync = ref.watch(monthStatsProvider);
  final month = ref.watch(selectedMonthProvider);

  return statsAsync.whenData((stats) {
    final now = DateTime.now();
    int days;
    if (month.year == now.year && month.month == now.month) {
      days = now.day;
    } else {
      days = DateTime(month.year, month.month + 1, 0).day;
    }
    if (days <= 0) days = 1;
    return stats.expense / days;
  });
});

// Today's spending
final todaySpentProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTodayTransactions().map((txList) {
    return txList
        .where((t) => t.type == 'expense')
        .fold<double>(0, (sum, t) => sum + t.amount);
  });
});

// Category breakdown for current month
final categoryBreakdownProvider = Provider<AsyncValue<List<({String category, double amount, String emoji})>>>((ref) {
  final txAsync = ref.watch(monthTransactionsProvider);
  final selectedWalletId = ref.watch(selectedWalletIdProvider);

  return txAsync.whenData((txList) {
    final Map<String, double> categoryTotals = {};
    for (final tx in txList.where((t) => t.type == 'expense')) {
      if (selectedWalletId != null && tx.walletId != selectedWalletId) continue;
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
    }
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => (
      category: e.key,
      amount: e.value,
      emoji: categoryIcons[e.key] ?? '📌',
    )).toList();
  });
});

// ==================== BUDGETS ====================

// Monthly overall budget
final monthBudgetProvider = StreamProvider<MonthlyBudget?>((ref) {
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  return db.watchBudget(monthStr);
});

// Budget progress (0.0 to 1.0+)
final budgetProgressProvider = Provider<AsyncValue<double?>>((ref) {
  final budgetAsync = ref.watch(monthBudgetProvider);
  final statsAsync = ref.watch(monthStatsProvider);

  return statsAsync.whenData((stats) {
    final budget = budgetAsync.valueOrNull;
    if (budget == null) return null;
    if (budget.budgetAmount <= 0) return null;
    return stats.expense / budget.budgetAmount;
  });
});

// Category budgets for active month
final categoryBudgetsProvider = StreamProvider<List<CategoryBudget>>((ref) {
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  return db.watchCategoryBudgets(monthStr);
});

// Category budget progress records
typedef CategoryBudgetStatus = ({
  String category,
  String emoji,
  double budgetAmount,
  double spentAmount,
  double progress,
  String alertLevel, // 'safe', 'warning', 'exceeded'
});

final categoryBudgetProgressListProvider = Provider<AsyncValue<List<CategoryBudgetStatus>>>((ref) {
  final catBudgetsAsync = ref.watch(categoryBudgetsProvider);
  final txAsync = ref.watch(monthTransactionsProvider);

  return catBudgetsAsync.whenData((budgets) {
    final txList = txAsync.valueOrNull ?? [];
    final Map<String, double> categorySpend = {};
    for (final tx in txList.where((t) => t.type == 'expense')) {
      categorySpend[tx.category] = (categorySpend[tx.category] ?? 0) + tx.amount;
    }

    return budgets.map((b) {
      final spent = categorySpend[b.category] ?? 0;
      final progress = b.budgetAmount > 0 ? (spent / b.budgetAmount) : 0.0;
      final alertLevel = progress >= 1.0
          ? 'exceeded'
          : (progress >= 0.75 ? 'warning' : 'safe');

      return (
        category: b.category,
        emoji: categoryIcons[b.category] ?? '📌',
        budgetAmount: b.budgetAmount,
        spentAmount: spent,
        progress: progress,
        alertLevel: alertLevel,
      );
    }).toList();
  });
});

// ==================== 6-MONTH CASHFLOW ====================
final cashflow6MonthsProvider = FutureProvider<List<({String month, double income, double expense, double net})>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rawList = await db.getCashflowLast6Months();
  return rawList.map((item) => (
    month: item.month,
    income: item.income,
    expense: item.expense,
    net: item.income - item.expense,
  )).toList();
});

// ==================== LAST 10 DAYS (DASHBOARD GRAPH) ====================
final last10DaysTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final end = DateTime.now().add(const Duration(days: 1));
  final start = end.subtract(const Duration(days: 11));
  return db.watchTransactions(from: start, to: end);
});

final expenseCategoryLast10DaysProvider = Provider<AsyncValue<List<({String category, double amount, String emoji})>>>((ref) {
  final txAsync = ref.watch(last10DaysTransactionsProvider);
  return txAsync.whenData((txList) {
    final Map<String, double> categoryTotals = {};
    for (final tx in txList.where((t) => t.type == 'expense')) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
    }
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => (
      category: e.key,
      amount: e.value,
      emoji: categoryIcons[e.key] ?? '📌',
    )).toList();
  });
});
