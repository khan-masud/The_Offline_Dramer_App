import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// Tag Filter Provider
final diaryTagFilterProvider = StateProvider<String?>((ref) => null);

// Search Query Provider
final diarySearchProvider = StateProvider<String>((ref) => '');

// Favorite Only Filter
final diaryFavoriteOnlyProvider = StateProvider<bool>((ref) => false);

// Stream of all diary entries
final diaryEntriesProvider = StreamProvider<List<DiaryEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  final tag = ref.watch(diaryTagFilterProvider);
  final isFavorite = ref.watch(diaryFavoriteOnlyProvider) ? true : null;
  final search = ref.watch(diarySearchProvider);

  return db.watchAllDiaryEntries(
    tag: tag,
    isFavorite: isFavorite,
    search: search,
  );
});

// Writing Streak Provider
final diaryStreakProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getDiaryStreak();
});

// "On This Day" Memory Recall Provider (Same day & month in past years)
final diaryOnThisDayProvider = FutureProvider<List<DiaryEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getOnThisDayEntries(DateTime.now());
});

// Journal Statistics (Word count, total entries, consistency)
final diaryStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getDiaryStats();
});

// Extract all unique tags across entries
final diaryAllTagsProvider = Provider<List<String>>((ref) {
  final entriesAsync = ref.watch(diaryEntriesProvider);
  final entries = entriesAsync.valueOrNull ?? [];
  final tagSet = <String>{};
  for (final e in entries) {
    if (e.tags != null && e.tags!.isNotEmpty) {
      for (final t in e.tags!.split(',')) {
        final clean = t.trim().replaceAll('#', '');
        if (clean.isNotEmpty) tagSet.add(clean);
      }
    }
  }
  return tagSet.toList()..sort();
});
