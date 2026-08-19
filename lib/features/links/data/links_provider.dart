import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// View Modes: Rich Cards (with image preview), Compact List, Grid
enum LinkViewMode { rich, compact, grid }

// Filter Tabs: All, Favorites, Unread Reading List, Read / Archive
enum LinkFilterTab { all, favorites, unread, read }

// Sort Options
enum LinkSortOption { newest, oldest, titleAZ, domain }

// Active Folder filter
final linkFolderFilterProvider = StateProvider<LinkFolder?>((ref) => null);

// View Mode Provider
final linkViewModeProvider = StateProvider<LinkViewMode>((ref) => LinkViewMode.rich);

// Filter Tab Provider
final linkFilterTabProvider = StateProvider<LinkFilterTab>((ref) => LinkFilterTab.all);

// Sort Provider
final linkSortProvider = StateProvider<LinkSortOption>((ref) => LinkSortOption.newest);

// Search Query
final linkSearchProvider = StateProvider<String>((ref) => '');

// All Link Folders Stream
final linkFoldersProvider = StreamProvider<List<LinkFolder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllLinkFolders();
});

// All links stream
final linksProvider = StreamProvider<List<Link>>((ref) {
  final db = ref.watch(databaseProvider);
  final folder = ref.watch(linkFolderFilterProvider);
  return db.watchAllLinks(
    category: folder?.name,
    folderId: folder?.id,
  );
});

// Filtered, searched, and sorted links provider
final filteredLinksProvider = Provider<AsyncValue<List<Link>>>((ref) {
  final linksAsync = ref.watch(linksProvider);
  final search = ref.watch(linkSearchProvider).toLowerCase().trim();
  final filterTab = ref.watch(linkFilterTabProvider);
  final sortOption = ref.watch(linkSortProvider);

  return linksAsync.whenData((rawLinks) {
    var list = rawLinks;

    // 1. Tab Filter
    switch (filterTab) {
      case LinkFilterTab.all:
        break;
      case LinkFilterTab.favorites:
        list = list.where((l) => l.isFavorite).toList();
        break;
      case LinkFilterTab.unread:
        list = list.where((l) => !l.isRead).toList();
        break;
      case LinkFilterTab.read:
        list = list.where((l) => l.isRead).toList();
        break;
    }

    // 2. Search Filter
    if (search.isNotEmpty) {
      list = list.where((l) {
        final titleMatch = l.title.toLowerCase().contains(search);
        final urlMatch = l.url.toLowerCase().contains(search);
        final categoryMatch = l.category?.toLowerCase().contains(search) ?? false;
        final noteMatch = l.note?.toLowerCase().contains(search) ?? false;
        final descMatch = l.description?.toLowerCase().contains(search) ?? false;
        final tagsMatch = l.tags?.toLowerCase().contains(search) ?? false;
        return titleMatch || urlMatch || categoryMatch || noteMatch || descMatch || tagsMatch;
      }).toList();
    }

    // 3. Sorting
    switch (sortOption) {
      case LinkSortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case LinkSortOption.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case LinkSortOption.titleAZ:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LinkSortOption.domain:
        list.sort((a, b) {
          final hostA = Uri.tryParse(a.url)?.host ?? a.url;
          final hostB = Uri.tryParse(b.url)?.host ?? b.url;
          return hostA.toLowerCase().compareTo(hostB.toLowerCase());
        });
        break;
    }

    return list;
  });
});

// Pending shared URL (stored while waiting for auth)
final pendingSharedUrlProvider = StateProvider<String?>((ref) => null);
final pendingSharedTextProvider = StateProvider<String?>((ref) => null);

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
      'Articles': '📄',
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
