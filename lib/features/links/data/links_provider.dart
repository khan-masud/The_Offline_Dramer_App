import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Category filter
final linkCategoryFilterProvider = StateProvider<String?>((ref) => null);

// Search
final linkSearchProvider = StateProvider<String>((ref) => '');

// All links (optionally filtered by category)
final linksProvider = StreamProvider<List<Link>>((ref) {
  final db = ref.watch(databaseProvider);
  final category = ref.watch(linkCategoryFilterProvider);
  return db.watchAllLinks(category: category);
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
      (l.category?.toLowerCase().contains(search) ?? false)
    ).toList();
  });
});

// Link categories
final linkCategoriesProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLinkCategories();
});

// Default link categories
const List<String> defaultLinkCategories = [
  'Work', 'Learning', 'Social', 'News', 'Shopping', 'Dev', 'Other',
];

// Category emojis
const Map<String, String> linkCategoryIcons = {
  'Work': '💼',
  'Learning': '📖',
  'Social': '👥',
  'News': '📰',
  'Shopping': '🛍️',
  'Dev': '💻',
  'Other': '🔗',
};
