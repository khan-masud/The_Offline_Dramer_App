import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Active folder filter
final noteFolderFilterProvider = StateProvider<String?>((ref) => null);

// Search query
final noteSearchProvider = StateProvider<String>((ref) => '');

// Reactive notes list
final notesProvider = StreamProvider<List<Note>>((ref) {
  final db = ref.watch(databaseProvider);
  final folder = ref.watch(noteFolderFilterProvider);
  return db.watchAllNotes(folder: folder);
});

// Filtered by search
final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  final search = ref.watch(noteSearchProvider).toLowerCase().trim();

  return notesAsync.whenData((notes) {
    if (search.isEmpty) return notes;
    return notes.where((n) =>
      n.title.toLowerCase().contains(search) ||
      n.content.toLowerCase().contains(search)
    ).toList();
  });
});

// Folders list
final noteFoldersProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchNoteFolders();
});
