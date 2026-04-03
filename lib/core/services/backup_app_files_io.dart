import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<List<Map<String, dynamic>>> collectAppFilesForBackup() async {
  final docs = await getApplicationDocumentsDirectory();
  final files = <Map<String, dynamic>>[];

  await for (final entity in docs.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (_isExcludedFile(entity.path, docs.path)) continue;

    final relativePath = p.relative(entity.path, from: docs.path).replaceAll('\\', '/');
    final bytes = await entity.readAsBytes();
    files.add({
      'path': relativePath,
      'data': base64Encode(bytes),
    });
  }

  files.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
  return files;
}

Future<void> restoreAppFilesFromBackup(dynamic filesSection) async {
  if (filesSection is! List) return;

  final docs = await getApplicationDocumentsDirectory();

  await for (final entity in docs.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (_isExcludedFile(entity.path, docs.path)) continue;
    await entity.delete();
  }

  for (final item in filesSection) {
    if (item is! Map) continue;
    final row = Map<String, dynamic>.from(item);
    final relativePathRaw = row['path'];
    final data = row['data'];

    if (relativePathRaw is! String || data is! String) continue;

    final relativePath = relativePathRaw.replaceAll('\\', '/').trim();
    if (relativePath.isEmpty || relativePath.startsWith('/')) continue;
    if (relativePath.contains('..')) continue;

    final normalized = p.normalize(relativePath);
    if (p.isAbsolute(normalized) || normalized.startsWith('..')) continue;

    final targetPath = p.join(docs.path, normalized);
    if (_isExcludedFile(targetPath, docs.path)) continue;

    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(base64Decode(data), flush: true);
  }
}

bool _isExcludedFile(String absolutePath, String docsRoot) {
  final normalized = p.normalize(absolutePath);
  final relative = p.relative(normalized, from: docsRoot).replaceAll('\\', '/');

  if (relative.startsWith('backups/')) return true;
  if (relative == 'tod.sqlite') return true;
  if (relative == 'tod.sqlite-wal') return true;
  if (relative == 'tod.sqlite-shm') return true;

  return false;
}
