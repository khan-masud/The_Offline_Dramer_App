import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Currency symbol
const String currencySymbol = '৳';

// Expense categories
const List<String> expenseCategories = [
  'Food', 'Transport', 'Shopping', 'Bills',
  'Health', 'Education', 'Entertainment', 'Other',
];

// Income categories
const List<String> incomeCategories = [
  'Salary', 'Freelance', 'Gift', 'Other',
];

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
  'Other': '📌',
};

// Active month filter
final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Transaction type filter
enum TransactionTypeFilter { all, income, expense }
final transactionTypeFilterProvider = StateProvider<TransactionTypeFilter>((ref) => TransactionTypeFilter.all);

// Month transactions stream
final monthTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  return db.watchMonthTransactions(month.year, month.month);
});

// Filtered transactions (by type)
final filteredTransactionsProvider = Provider<AsyncValue<List<Transaction>>>((ref) {
  final txAsync = ref.watch(monthTransactionsProvider);
  final filter = ref.watch(transactionTypeFilterProvider);

  return txAsync.whenData((txList) {
    switch (filter) {
      case TransactionTypeFilter.all:
        return txList;
      case TransactionTypeFilter.income:
        return txList.where((t) => t.type == 'income').toList();
      case TransactionTypeFilter.expense:
        return txList.where((t) => t.type == 'expense').toList();
    }
  });
});

// Month stats (income, expense, balance)
final monthStatsProvider = Provider<AsyncValue<({double income, double expense, double balance})>>((ref) {
  final txAsync = ref.watch(monthTransactionsProvider);
  return txAsync.whenData((txList) {
    double income = 0;
    double expense = 0;
    for (final tx in txList) {
      if (tx.type == 'income') {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    return (income: income, expense: expense, balance: income - expense);
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

// Monthly budget
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

// Last 10 days transactions
final last10DaysTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final end = DateTime.now().add(const Duration(days: 1));
  final start = end.subtract(const Duration(days: 11));
  return db.watchTransactions(from: start, to: end);
});

// Category breakdown for last 10 days
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
      emoji: categoryIcons[e.key] ?? '??',
    )).toList();
  });
});
