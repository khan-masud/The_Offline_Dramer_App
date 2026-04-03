import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/notes_provider.dart';
import 'note_editor_screen.dart';

const _noteColors = [
  Colors.transparent,
  Color(0xFFF28B82),
  Color(0xFFFBBC04),
  Color(0xFFFFF475),
  Color(0xFFCCFF90),
  Color(0xFFA7FFEB),
  Color(0xFFCBF0F8),
  Color(0xFFAECBFA),
  Color(0xFFD7AEFB),
  Color(0xFFFDCFE8),
  Color(0xFFE6C9A8),
  Color(0xFFE8EAED),
];

const _noteColorsDark = [
  Colors.transparent,
  Color(0xFF5C2B29),
  Color(0xFF614A19),
  Color(0xFF635D19),
  Color(0xFF345920),
  Color(0xFF16504B),
  Color(0xFF2D555E),
  Color(0xFF1E3A5F),
  Color(0xFF42275E),
  Color(0xFF5B2245),
  Color(0xFF442F19),
  Color(0xFF3C3F43),
];

class NotePreviewScreen extends ConsumerWidget {
  final Note note;

  const NotePreviewScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? _noteColorsDark : _noteColors;
    final bgColor = note.colorIndex < colors.length ? colors[note.colorIndex] : Colors.transparent;
    final isDefaultColor = bgColor == Colors.transparent;
    final effectiveBg = isDefaultColor ? theme.scaffoldBackgroundColor : bgColor;
    final textColor = isDefaultColor ? theme.colorScheme.onSurface : (isDark ? Colors.white : Colors.black87);
    final subtextColor = isDefaultColor
        ? theme.colorScheme.onSurfaceVariant
        : (isDark ? Colors.white70 : Colors.black54);

    final notesAsync = ref.watch(notesProvider);
    final currentNote = notesAsync.whenData((notes) {
      try {
        return notes.firstWhere((n) => n.id == note.id);
      } catch (_) {
        return note;
      }
    }).valueOrNull;

    if (currentNote == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Note not found')),
      );
    }

    return Scaffold(
      backgroundColor: effectiveBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Delete note',
            onPressed: () => _deleteWithUndo(context, ref, currentNote),
          ),
          IconButton(
            icon: Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
            tooltip: 'Edit note',
            onPressed: () => _openEditor(context, currentNote),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentNote.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  currentNote.title,
                  style: AppTypography.noteTitle.copyWith(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: subtextColor),
                const SizedBox(width: 6),
                Text(
                  _formatDate(currentNote.updatedAt),
                  style: AppTypography.labelSmall.copyWith(color: subtextColor),
                ),
                if (currentNote.folder != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.folder_outlined, size: 14, color: subtextColor),
                  const SizedBox(width: 4),
                  Text(
                    currentNote.folder!,
                    style: AppTypography.labelSmall.copyWith(color: subtextColor),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            Divider(color: subtextColor.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 22),
            if (currentNote.content.trim().isNotEmpty)
              MarkdownBody(
                data: currentNote.content,
                selectable: true,
                softLineBreak: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: AppTypography.noteContent.copyWith(
                    color: textColor,
                    fontSize: 16,
                    height: 1.6,
                  ),
                  h1: AppTypography.headingMedium.copyWith(color: textColor),
                  h2: AppTypography.headingSmall.copyWith(color: textColor),
                  listBullet: AppTypography.noteContent.copyWith(color: textColor),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Text(
                    'Empty note',
                    style: AppTypography.bodyMedium.copyWith(color: subtextColor),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'note_edit_fab',
        onPressed: () => _openEditor(context, currentNote),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Edit'),
      ),
    );
  }

  void _openEditor(BuildContext context, Note note) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: NoteEditorScreen(note: note),
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, WidgetRef ref, Note note) {
    final itemKey = 'note_${note.id}';
    final db = ref.read(databaseProvider);
    final hiddenNotifier = ref.read(hiddenItemsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    hiddenNotifier.update((state) => {...state, itemKey});
    navigator.pop();

    messenger.clearSnackBars();

    var undone = false;
    final timer = Timer(const Duration(seconds: 3), () async {
      if (!undone) {
        await db.deleteNote(note.id);
        hiddenNotifier.update((state) {
          final next = {...state};
          next.remove(itemKey);
          return next;
        });
        ref.read(activityLogProvider.notifier).log(
          type: 'delete',
          entityType: 'note',
          entityTitle: note.title,
        );
      }
      messenger.hideCurrentSnackBar();
    });

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            undone = true;
            timer.cancel();
            messenger.hideCurrentSnackBar();
            hiddenNotifier.update((state) {
              final next = {...state};
              next.remove(itemKey);
              return next;
            });
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dt);
  }
}
