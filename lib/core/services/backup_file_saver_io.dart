import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> saveBackupFile(Uint8List bytes, String fileName) async {
  final docDir = await getApplicationDocumentsDirectory();
  final backupDir = Directory(p.join(docDir.path, 'backups'));
  if (!backupDir.existsSync()) {
    backupDir.createSync(recursive: true);
  }

  final file = File(p.join(backupDir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
