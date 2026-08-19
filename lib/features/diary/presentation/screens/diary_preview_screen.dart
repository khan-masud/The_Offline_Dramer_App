import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/diary_provider.dart';
import 'diary_editor_screen.dart';

class DiaryPreviewScreen extends ConsumerStatefulWidget {
  final DiaryEntry entry;

  const DiaryPreviewScreen({super.key, required this.entry});

  @override
  ConsumerState<DiaryPreviewScreen> createState() => _DiaryPreviewScreenState();
}

class _DiaryPreviewScreenState extends ConsumerState<DiaryPreviewScreen> {
  late DiaryEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('MMMM d, yyyy').format(_entry.date),
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Edit Button (Navigates to Editor Screen)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            tooltip: 'Edit Diary Entry',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DiaryEditorScreen(entry: _entry)),
              );
              // Refetch updated entry
              final db = ref.read(databaseProvider);
              final updated = await (db.select(db.diaryEntries)..where((d) => d.id.equals(_entry.id))).getSingleOrNull();
              if (updated != null && mounted) {
                setState(() => _entry = updated);
              }
            },
          ),

          // Bookmark Toggle
          IconButton(
            icon: Icon(
              _entry.isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _entry.isFavorite ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Bookmark',
            onPressed: () async {
              final newStatus = !_entry.isFavorite;
              await ref.read(databaseProvider).toggleDiaryFavorite(_entry.id, newStatus);
              setState(() {
                _entry = _entry.copyWith(isFavorite: newStatus);
              });
              ref.invalidate(diaryEntriesProvider);
            },
          ),

          // Share Text
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Entry',
            onPressed: () {
              final text = '${_entry.title != null ? "${_entry.title}\n\n" : ""}${_entry.content}';
              Share.share(text, subject: _entry.title ?? 'Diary Entry');
            },
          ),

          // Copy Text
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Text',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _entry.content));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diary entry copied to clipboard!')));
            },
          ),

          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Delete Entry',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Metadata Strip ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Date
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_entry.date),
                        style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  // Location
                  if (_entry.location != null && _entry.location!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(_entry.location!, style: AppTypography.labelSmall),
                      ],
                    ),

                  // Word count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notes_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${_entry.wordCount} words', style: AppTypography.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Entry Title ──
            if (_entry.title != null && _entry.title!.isNotEmpty) ...[
              Text(
                _entry.title!,
                style: AppTypography.headingLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],

            // ── Full Formatted Markdown Content ──
            MarkdownBody(
              data: _entry.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: AppTypography.bodyMedium.copyWith(
                  height: 1.65,
                  fontSize: 15.5,
                  color: theme.colorScheme.onSurface,
                ),
                h1: AppTypography.headingLarge.copyWith(fontWeight: FontWeight.bold),
                h2: AppTypography.headingMedium.copyWith(fontWeight: FontWeight.bold),
                h3: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold),
                blockquoteDecoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: theme.colorScheme.primary, width: 3.5),
                  ),
                ),
              ),
            ),

            // ── Tags Strip ──
            if (_entry.tags != null && _entry.tags!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _entry.tags!
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            '#${t.replaceAll('#', '')}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Diary Entry?'),
        content: const Text('Are you sure you want to permanently delete this diary entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(databaseProvider).deleteDiaryEntry(_entry.id);
              ref.invalidate(diaryEntriesProvider);
              ref.invalidate(diaryStreakProvider);
              ref.invalidate(diaryStatsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
