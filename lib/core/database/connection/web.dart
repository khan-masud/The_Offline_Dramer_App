import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor connect() {
  return LazyDatabase(() async {
    final storage = await DriftWebStorage.indexedDbIfSupported('tod_db');
    return WebDatabase.withStorage(storage);
  });
}
