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

class DiaryReaderScreen extends ConsumerWidget {
  final DiaryEntry entry;

  const DiaryReaderScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('MMMM d, yyyy').format(entry.date),
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Edit
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Diary Entry',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => DiaryEditorScreen(entry: entry)),
              );
            },
          ),
          // Share Text
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Entry',
            onPressed: () {
              final text = '${entry.title != null ? "${entry.title}\n\n" : ""}${entry.content}';
              Share.share(text, subject: entry.title ?? 'Diary Entry');
            },
          ),
          // Copy
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Text',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.content));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diary entry copied to clipboard!')));
            },
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Metadata Strip (Date + Location + Weather + Word Count) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Full Date & Day
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(entry.date),
                        style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  // Weather
                  if (entry.weather != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getWeatherIcon(entry.weather), size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(_getWeatherLabel(entry.weather), style: AppTypography.labelSmall),
                      ],
                    ),

                  // Location
                  if (entry.location != null && entry.location!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(entry.location!, style: AppTypography.labelSmall),
                      ],
                    ),

                  // Word Count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notes_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${entry.wordCount} words', style: AppTypography.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Headline / Title ──
            if (entry.title != null && entry.title!.isNotEmpty) ...[
              Text(
                entry.title!,
                style: AppTypography.headingLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
            ],

            // ── Markdown Body Content ──
            MarkdownBody(
              data: entry.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: AppTypography.bodyMedium.copyWith(
                  height: 1.6,
                  fontSize: 15.5,
                  color: theme.colorScheme.onSurface,
                ),
                h1: AppTypography.headingLarge.copyWith(fontWeight: FontWeight.bold),
                h2: AppTypography.headingMedium.copyWith(fontWeight: FontWeight.bold),
                h3: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold),
                blockquoteDecoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: theme.colorScheme.primary, width: 3.5),
                  ),
                ),
              ),
            ),

            // ── Tags Strip ──
            if (entry.tags != null && entry.tags!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: entry.tags!
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
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
        title: const Text('Delete Journal Entry?'),
        content: const Text('Are you sure you want to permanently delete this journal entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(databaseProvider).deleteDiaryEntry(entry.id);
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

  IconData _getWeatherIcon(String? weather) {
    switch (weather) {
      case 'sunny': return Icons.wb_sunny_outlined;
      case 'cloudy': return Icons.cloud_outlined;
      case 'rainy': return Icons.water_drop_outlined;
      case 'clear_night': return Icons.nights_stay_outlined;
      default: return Icons.wb_sunny_outlined;
    }
  }

  String _getWeatherLabel(String? weather) {
    switch (weather) {
      case 'sunny': return 'Sunny';
      case 'cloudy': return 'Cloudy';
      case 'rainy': return 'Rainy';
      case 'clear_night': return 'Night';
      default: return 'Clear';
    }
  }
}
