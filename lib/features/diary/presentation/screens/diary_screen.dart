import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/diary_provider.dart';
import 'diary_editor_screen.dart';
import 'diary_preview_screen.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(diaryEntriesProvider);
    final streakAsync = ref.watch(diaryStreakProvider);
    final onThisDayAsync = ref.watch(diaryOnThisDayProvider);
    final allTags = ref.watch(diaryAllTagsProvider);
    final activeTag = ref.watch(diaryTagFilterProvider);
    final favoriteOnly = ref.watch(diaryFavoriteOnlyProvider);

    final totalCount = entriesAsync.valueOrNull?.length ?? 0;
    final streak = streakAsync.valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search diary entries, tags, locations...',
                  hintStyle: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  border: InputBorder.none,
                ),
                onChanged: (v) => ref.read(diarySearchProvider.notifier).state = v,
              )
            : Row(
                children: [
                  const Text('Diary'),
                  if (totalCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalCount',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          // Streak Badge
          if (streak > 0 && !_isSearching)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 15, color: AppColors.orange),
                  const SizedBox(width: 3),
                  Text(
                    '$streak Day${streak > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.orange),
                  ),
                ],
              ),
            ),

          // Search Toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Close Search' : 'Search Diary',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  ref.read(diarySearchProvider.notifier).state = '';
                }
              });
            },
          ),

          // Favorite Filter Toggle
          IconButton(
            icon: Icon(
              favoriteOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: favoriteOnly ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: favoriteOnly ? 'Show All' : 'Bookmarks Only',
            onPressed: () => ref.read(diaryFavoriteOnlyProvider.notifier).state = !favoriteOnly,
          ),

          // Stats & Analytics Button
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Journal Insights',
            onPressed: () => _showStatsModal(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── "On This Day" Memory Recall Card ──
          onThisDayAsync.when(
            data: (memories) {
              if (memories.isEmpty || _isSearching) return const SizedBox.shrink();
              final memory = memories.first;
              final yearsAgo = DateTime.now().year - memory.date.year;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded, size: 20, color: AppColors.purple),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ON THIS DAY ($yearsAgo YEAR${yearsAgo > 1 ? 'S' : ''} AGO)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.purple.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            memory.title ?? memory.content,
                            style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.purple,
                      ),
                      onPressed: () => _openReader(memory),
                      child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Tag Filter Strip ──
          if (allTags.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _TagPill(
                    label: 'All Entries',
                    isActive: activeTag == null,
                    onTap: () => ref.read(diaryTagFilterProvider.notifier).state = null,
                  ),
                  ...allTags.map((tag) => _TagPill(
                        label: '#$tag',
                        isActive: activeTag == tag,
                        onTap: () => ref.read(diaryTagFilterProvider.notifier).state = activeTag == tag ? null : tag,
                      )),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // ── Timeline Stream ──
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return _emptyState(context, isSearching: _isSearching);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  physics: const BouncingScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    return _ExecutiveJournalCard(
                      entry: entry,
                      onTap: () => _openReader(entry),
                      onEdit: () => _openEditor(entry: entry),
                      onToggleFavorite: () => ref.read(databaseProvider).toggleDiaryFavorite(entry.id, !entry.isFavorite),
                      onDelete: () => _deleteEntry(context, ref, entry),
                    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Could not load journal entries')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'diary_fab',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.menu_book_rounded),
        label: const Text('Write Diary', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _openEditor({DiaryEntry? entry}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DiaryEditorScreen(entry: entry)),
    );
  }

  void _openReader(DiaryEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DiaryPreviewScreen(entry: entry)),
    );
  }

  void _deleteEntry(BuildContext context, WidgetRef ref, DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Diary Entry?'),
        content: Text('Delete diary entry for ${DateFormat('MMMM d, yyyy').format(entry.date)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(databaseProvider).deleteDiaryEntry(entry.id);
              ref.invalidate(diaryEntriesProvider);
              ref.invalidate(diaryStreakProvider);
              ref.invalidate(diaryStatsProvider);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showStatsModal(BuildContext context, WidgetRef ref) async {
    final stats = await ref.read(databaseProvider).getDiaryStats();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Diary Insights & Metrics', style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            Row(
              children: [
                _StatTile(title: 'Total Entries', value: '${stats['totalEntries']}', icon: Icons.book_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                _StatTile(title: 'Words Written', value: '${stats['totalWords']}', icon: Icons.notes_rounded, color: AppColors.teal),
                const SizedBox(width: 12),
                _StatTile(title: 'Active Streak', value: '${stats['streak']} Days', icon: Icons.bolt_rounded, color: AppColors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, {required bool isSearching}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.menu_book_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No matching diary entries' : 'Your diary is empty',
              style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Try searching by a different keyword, tag, or location.'
                  : 'Start writing your personal thoughts, daily events, and memories in your diary.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────── STAT TILE ──────────────────

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value, style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ────────────────── TAG PILL ──────────────────

class _TagPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TagPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ────────────────── EXECUTIVE JOURNAL CARD ──────────────────

class _ExecutiveJournalCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const _ExecutiveJournalCard({
    required this.entry,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final date = entry.date;
    final dayNum = DateFormat('dd').format(date);
    final dayName = DateFormat('EEE').format(date).toUpperCase();
    final monthName = DateFormat('MMM').format(date).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Date Badge Column
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayNum,
                        style: AppTypography.headingMedium.copyWith(fontWeight: FontWeight.w800, height: 1.1),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        monthName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Right Content Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Location + Word Count + Bookmark
                      Row(
                        children: [
                          if (entry.location != null && entry.location!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 10, color: AppColors.error),
                                  const SizedBox(width: 3),
                                  Text(
                                    entry.location!,
                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${entry.wordCount} words',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          ),
                          const Spacer(),
                          if (entry.isLocked)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.lock_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          GestureDetector(
                            onTap: onToggleFavorite,
                            child: Icon(
                              entry.isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 18,
                              color: entry.isFavorite ? AppColors.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        entry.title != null && entry.title!.isNotEmpty ? entry.title! : 'Diary Entry',
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Content Preview
                      Text(
                        _stripMarkdown(entry.content),
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Tags
                      if (entry.tags != null && entry.tags!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: entry.tags!
                              .split(',')
                              .take(3)
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${t.trim().replaceAll('#', '')}',
                                      style: TextStyle(fontSize: 9.5, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stripMarkdown(String md) {
    return md
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'\*\*|\*|__|_|`|>|- \[ \]|-\s'), '')
        .replaceAll('\n', ' ')
        .trim();
  }
}
