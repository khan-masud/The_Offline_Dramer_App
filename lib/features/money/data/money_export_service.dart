import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/app_database.dart';

class MoneyExportService {
  static Future<String> generateCsv({
    required List<Transaction> transactions,
    required DateTime month,
    List<Wallet> wallets = const [],
  }) async {
    final Map<int, String> walletMap = {for (final w in wallets) w.id: w.name};
    final monthName = DateFormat('MMMM_yyyy').format(month);
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('Date,Type,Title,Category,Amount,Wallet,Note,Recurring');

    for (final tx in transactions) {
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.date);
      final typeStr = tx.type.toUpperCase();
      final title = _escapeCsv(tx.title);
      final category = _escapeCsv(tx.category);
      final amount = tx.amount.toStringAsFixed(2);
      final wallet = _escapeCsv(walletMap[tx.walletId] ?? 'Default');
      final note = _escapeCsv(tx.note ?? '');
      final recurring = tx.isRecurring ? (tx.recurringPattern ?? 'Yes') : 'No';

      buffer.writeln('$dateStr,$typeStr,$title,$category,$amount,$wallet,$note,$recurring');
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/Transactions_$monthName.csv';
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    return filePath;
  }

  static Future<void> exportAndShareCsv({
    required List<Transaction> transactions,
    required DateTime month,
    List<Wallet> wallets = const [],
  }) async {
    final filePath = await generateCsv(
      transactions: transactions,
      month: month,
      wallets: wallets,
    );
    final monthName = DateFormat('MMMM yyyy').format(month);
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Transaction Statement — $monthName',
      text: 'Here is the transaction statement for $monthName exported from Me++.',
    );
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
