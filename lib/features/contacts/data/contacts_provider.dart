import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final contactSearchProvider = StateProvider<String>((ref) => '');

final contactEntriesProvider = StreamProvider<List<ContactEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  final search = ref.watch(contactSearchProvider);
  return db.watchAllContactEntries(search: search);
});
