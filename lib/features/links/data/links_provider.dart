import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Category/Folder filter
final linkFolderFilterProvider = StateProvider<LinkFolder?>((ref) => null);

// Search
final linkSearchProvider = StateProvider<String>((ref) => '');

// All Link Folders Stream
final linkFoldersProvider = StreamProvider<List<LinkFolder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllLinkFolders();
});

// All links (optionally filtered by category/folder name)
final linksProvider = StreamProvider<List<Link>>((ref) {
  final db = ref.watch(databaseProvider);
  final folder = ref.watch(linkFolderFilterProvider);
  return db.watchAllLinks(category: folder?.name);
});

// Filtered by search
final filteredLinksProvider = Provider<AsyncValue<List<Link>>>((ref) {
  final linksAsync = ref.watch(linksProvider);
  final search = ref.watch(linkSearchProvider).toLowerCase().trim();

  return linksAsync.whenData((links) {
    if (search.isEmpty) return links;
    return links.where((l) =>
      l.title.toLowerCase().contains(search) ||
      l.url.toLowerCase().contains(search) ||
      (l.category?.toLowerCase().contains(search) ?? false) ||
      (l.note?.toLowerCase().contains(search) ?? false)
    ).toList();
  });
});

// Pre-seed default folders
Future<void> seedDefaultLinkFolders(AppDatabase db) async {
  final count = await db.select(db.linkFolders).get();
  if (count.isEmpty) {
    var order = 0;
    const defaultFolderIcons = {
      'Work': '💼',
      'Learning': '📖',
      'Social': '👥',
      'News': '📰',
      'Shopping': '🛍️',
      'Dev': '💻',
      'Other': '🔗',
    };
    
    for (final folder in defaultFolderIcons.entries) {
      await db.addLinkFolder(LinkFoldersCompanion(
        name: Value(folder.key),
        emoji: Value(folder.value),
        sortOrder: Value(order++),
        createdAt: Value(DateTime.now()),
      ));
    }
  }
}
