Future<List<Map<String, dynamic>>> collectAppFilesForBackup() async {
  // Web has no app documents directory in the same sense as native file systems.
  return const <Map<String, dynamic>>[];
}

Future<void> restoreAppFilesFromBackup(dynamic filesSection) async {
  // No-op for web.
}
