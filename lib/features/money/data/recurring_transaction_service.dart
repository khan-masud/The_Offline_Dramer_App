import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final recurringTransactionServiceProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  final prefs = await SharedPreferences.getInstance();

  final lastCheckStr = prefs.getString('last_recurring_check');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (lastCheckStr != null) {
    try {
      final lastCheck = DateTime.parse(lastCheckStr);
      if (lastCheck.year == today.year && lastCheck.month == today.month && lastCheck.day == today.day) {
        return; // Already checked today
      }
    } catch (_) {}
  }

  // Get all recurring transactions
  final allTx = await db.select(db.transactions).get();
  final recurringTx = allTx.where((t) => t.isRecurring && t.recurringPattern != null).toList();
  if (recurringTx.isEmpty) {
    await prefs.setString('last_recurring_check', today.toIso8601String());
    return;
  }

  // Group by profile
  final Map<String, List<Transaction>> grouped = {};
  for (final tx in recurringTx) {
    final key = '${tx.title}_${tx.category}_${tx.type}_${tx.amount}_${tx.recurringPattern}';
    grouped.putIfAbsent(key, () => []).add(tx);
  }

  for (final group in grouped.values) {
    if (group.isEmpty) continue;
    group.sort((a, b) => b.date.compareTo(a.date));
    final template = group.first;
    DateTime nextDue = template.date;

    DateTime incrementDate(DateTime date, String pattern) {
      switch (pattern) {
        case 'daily':
          return date.add(const Duration(days: 1));
        case 'weekly':
          return date.add(const Duration(days: 7));
        case 'monthly':
          return DateTime(date.year, date.month + 1, date.day);
        case 'yearly':
          return DateTime(date.year + 1, date.month, date.day);
        default:
          return date.add(const Duration(days: 1));
      }
    }

    nextDue = incrementDate(nextDue, template.recurringPattern!);

    // Generate any missed cycles
    int safeguard = 0;
    while ((nextDue.isBefore(today) || (nextDue.year == today.year && nextDue.month == today.month && nextDue.day == today.day)) && safeguard < 365) {
      safeguard++;
      await db.addTransaction(TransactionsCompanion(
        amount: drift.Value(template.amount),
        type: drift.Value(template.type),
        title: drift.Value(template.title),
        category: drift.Value(template.category),
        note: drift.Value(template.note),
        date: drift.Value(nextDue),
        isRecurring: const drift.Value(true),
        recurringPattern: drift.Value(template.recurringPattern),
        walletId: drift.Value(template.walletId),
        createdAt: drift.Value(now),
      ));

      nextDue = incrementDate(nextDue, template.recurringPattern!);
    }
  }

  await prefs.setString('last_recurring_check', today.toIso8601String());
});
