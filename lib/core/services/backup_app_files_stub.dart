Future<List<Map<String, dynamic>>> collectAppFilesForBackup() async {
  return const <Map<String, dynamic>>[];
}

Future<void> restoreAppFilesFromBackup(dynamic filesSection) async {
  // No-op on unsupported platforms.
}
