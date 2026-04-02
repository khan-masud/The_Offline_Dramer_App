import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Debt filter
enum DebtFilter { all, given, taken, settled }
final debtFilterProvider = StateProvider<DebtFilter>((ref) => DebtFilter.all);

// All debts stream
final allDebtsProvider = StreamProvider<List<Debt>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllDebts();
});

// Filtered debts
final filteredDebtsProvider = Provider<AsyncValue<List<Debt>>>((ref) {
  final debtsAsync = ref.watch(allDebtsProvider);
  final filter = ref.watch(debtFilterProvider);

  return debtsAsync.whenData((debtList) {
    switch (filter) {
      case DebtFilter.all:
        return debtList.where((d) => !d.isSettled).toList();
      case DebtFilter.given:
        return debtList.where((d) => d.type == 'given' && !d.isSettled).toList();
      case DebtFilter.taken:
        return debtList.where((d) => d.type == 'taken' && !d.isSettled).toList();
      case DebtFilter.settled:
        return debtList.where((d) => d.isSettled).toList();
    }
  });
});

// Debt payments for a specific debt
final debtPaymentsProvider = StreamProvider.family<List<DebtPayment>, int>((ref, debtId) {
  final db = ref.watch(databaseProvider);
  return db.watchDebtPayments(debtId);
});

// Summary stats
final debtSummaryProvider = Provider<AsyncValue<({double totalGiven, double totalTaken, double givenPaid, double takenPaid})>>((ref) {
  final debtsAsync = ref.watch(allDebtsProvider);
  return debtsAsync.whenData((debtList) {
    double totalGiven = 0;
    double totalTaken = 0;
    double givenPaid = 0;
    double takenPaid = 0;

    for (final d in debtList.where((d) => !d.isSettled)) {
      if (d.type == 'given') {
        totalGiven += d.amount;
        givenPaid += d.paidAmount;
      } else {
        totalTaken += d.amount;
        takenPaid += d.paidAmount;
      }
    }
    return (totalGiven: totalGiven, totalTaken: totalTaken, givenPaid: givenPaid, takenPaid: takenPaid);
  });
});
