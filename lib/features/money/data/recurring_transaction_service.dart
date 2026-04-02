import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final recurringTransactionServiceProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  final prefs = await SharedPreferences.getInstance();
  
  // Last time we checked and generated recurring transactions
  final lastCheckStr = prefs.getString('last_recurring_check');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  if (lastCheckStr != null) {
    final lastCheck = DateTime.parse(lastCheckStr);
    if (lastCheck.year == today.year && lastCheck.month == today.month && lastCheck.day == today.day) {
      // Already checked today
      return;
    }
  }

  // Get all recurring transactions
  final allTx = await db.select(db.transactions).get();
  final recurringTx = allTx.where((t) => t.isRecurring).toList();

  for (final tx in recurringTx) {
    if (tx.recurringPattern == null) continue;
    
    // Find the latest transaction with the same title, amount, category to see when it was last generated
    // Or just look at the creation date of the original transaction and see how many cycles have passed
    // A better approach is to check the latest transaction matching this recurring profile
    final latestMatch = allTx
        .where((t) => t.isRecurring && t.title == tx.title && t.amount == tx.amount && t.type == tx.type)
        .reduce((a, b) => a.date.isAfter(b.date) ? a : b);

    // Calculate next due date
    DateTime nextDue = latestMatch.date;
    switch (tx.recurringPattern) {
      case 'daily':
        nextDue = DateTime(latestMatch.date.year, latestMatch.date.month, latestMatch.date.day + 1);
        break;
      case 'weekly':
        nextDue = DateTime(latestMatch.date.year, latestMatch.date.month, latestMatch.date.day + 7);
        break;
      case 'monthly':
        nextDue = DateTime(latestMatch.date.year, latestMatch.date.month + 1, latestMatch.date.day);
        break;
      case 'yearly':
        nextDue = DateTime(latestMatch.date.year + 1, latestMatch.date.month, latestMatch.date.day);
        break;
    }

    // While the next due date is in the past or today, we generate missing cycles
    while (nextDue.isBefore(today) || nextDue.isAtSameMomentAs(today)) {
      await db.addTransaction(TransactionsCompanion(
        amount: drift.Value(tx.amount),
        type: drift.Value(tx.type),
        title: drift.Value(tx.title),
        category: drift.Value(tx.category),
        note: drift.Value(tx.note),
        date: drift.Value(nextDue),
        isRecurring: drift.Value(true),
        recurringPattern: drift.Value(tx.recurringPattern),
        createdAt: drift.Value(now),
      ));

      // Increment nextDue for the next cycle
      switch (tx.recurringPattern) {
        case 'daily':
          nextDue = DateTime(nextDue.year, nextDue.month, nextDue.day + 1);
          break;
        case 'weekly':
          nextDue = DateTime(nextDue.year, nextDue.month, nextDue.day + 7);
          break;
        case 'monthly':
          nextDue = DateTime(nextDue.year, nextDue.month + 1, nextDue.day);
          break;
        case 'yearly':
          nextDue = DateTime(nextDue.year + 1, nextDue.month, nextDue.day);
          break;
      }
    }
  }

  await prefs.setString('last_recurring_check', today.toIso8601String());
});
