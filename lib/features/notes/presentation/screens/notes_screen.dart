import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/notes_provider.dart';
import 'note_editor_screen.dart';
import 'note_preview_screen.dart';

// Note colors
const _noteColors = [
  Colors.transparent,
  Color(0xFFF28B82), Color(0xFFFBBC04), Color(0xFFFFF475), Color(0xFFCCFF90),
  Color(0xFFA7FFEB), Color(0xFFCBF0F8), Color(0xFFAECBFA), Color(0xFFD7AEFB),
  Color(0xFFFDCFE8), Color(0xFFE6C9A8), Color(0xFFE8EAED),
];

const _noteColorsDark = [
  Colors.transparent,
  Color(0xFF5C2B29), Color(0xFF614A19), Color(0xFF635D19), Color(0xFF345920),
  Color(0xFF16504B), Color(0xFF2D555E), Color(0xFF1E3A5F), Color(0xFF42275E),
  Color(0xFF5B2245), Color(0xFF442F19), Color(0xFF3C3F43),
];

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notesAsync = ref.watch(filteredNotesProvider);
    final foldersAsync = ref.watch(noteFoldersProvider);
    final activeFolder = ref.watch(noteFolderFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        centerTitle: false,
      ),
      body: Column(
        children: [
            // Floating search bar (Keep-style)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: TextField(
                  onChanged: (v) => ref.read(noteSearchProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search your notes',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: ref.watch(noteSearchProvider).isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            ref.read(noteSearchProvider.notifier).state = '';
                            FocusScope.of(context).unfocus();
                          },
                        ) 
                      : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            // Folder chips
            SizedBox(
              height: 48,
              child: foldersAsync.when(
                data: (folders) {
                  if (folders.isEmpty) return const SizedBox.shrink();
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _FolderChip(
                        label: 'All',
                        isActive: activeFolder == null,
                        onTap: () => ref.read(noteFolderFilterProvider.notifier).state = null,
                      ),
                      ...folders.map((f) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FolderChip(
                          label: f,
                          isActive: activeFolder == f,
                          onTap: () => ref.read(noteFolderFilterProvider.notifier).state = f,
                        ),
                      )),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            // Notes staggered grid
            Expanded(
              child: notesAsync.when(
                data: (allNotes) {
                  final hidden = ref.watch(hiddenItemsProvider);
                  final notes = allNotes.where((n) => !hidden.contains('note_${n.id}')).toList();
                  if (notes.isEmpty) return _emptyState(context);
                  
                  return MasonryGridView.count(
                    padding: const EdgeInsets.all(12),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    itemCount: notes.length,
                    itemBuilder: (context, i) {
                      final note = notes[i];
                      final colors = isDark ? _noteColorsDark : _noteColors;
                      final bgColor = note.colorIndex < colors.length ? colors[note.colorIndex] : Colors.transparent;

                      return _NoteCard(
                        note: note,
                        backgroundColor: bgColor,
                        onTap: () => _openWithFadeSlide(
                          context,
                          NotePreviewScreen(note: note),
                        ),
                        onTogglePin: () {
                          ref.read(databaseProvider).toggleNotePin(note.id, !note.isPinned);
                          ref.read(activityLogProvider.notifier).log(
                            type: 'update',
                            entityType: 'note',
                            entityTitle: note.title,
                          );
                        },
                        onDelete: () => _deleteNote(context, ref, note),
                      ).animate().fadeIn(delay: (50 * i).ms, duration: 300.ms);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'notes_fab',
        onPressed: () => _openWithFadeSlide(context, const NoteEditorScreen()),
        backgroundColor: theme.colorScheme.primaryContainer,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add_rounded, color: theme.colorScheme.onPrimaryContainer, size: 32),
      ),
    );
  }

  Future<void> _openWithFadeSlide(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: page,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  void _deleteNote(BuildContext context, WidgetRef ref, Note note) {
    final itemKey = 'note_${note.id}';
    final db = ref.read(databaseProvider);
    final hiddenNotifier = ref.read(hiddenItemsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    
    // Hide immediately
    hiddenNotifier.update((state) => {...state, itemKey});
    
    messenger.clearSnackBars();
    
    bool undone = false;
    // Schedule actual deletion
    final timer = Timer(const Duration(seconds: 3), () async {
      if (!undone) {
        await db.deleteNote(note.id);
        hiddenNotifier.update((state) {
          final s = {...state};
          s.remove(itemKey);
          return s;
        });
        // Log activity
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
              final s = {...state};
              s.remove(itemKey);
              return s;
            });
          },
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 80, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(height: 20),
          Text('Notes you add appear here', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ==================== NOTE CARD ====================
class _NoteCard extends StatelessWidget {
  final Note note;
  final Color backgroundColor;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.backgroundColor,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDefaultColor = backgroundColor == Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Container(
        decoration: BoxDecoration(
          color: isDefaultColor ? theme.scaffoldBackgroundColor : backgroundColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDefaultColor ? theme.colorScheme.outline.withValues(alpha: 0.5) : backgroundColor,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.title.isNotEmpty || note.isPinned)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.title.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          note.title,
                          style: AppTypography.noteTitle.copyWith(
                            color: isDefaultColor ? theme.colorScheme.onSurface : Colors.black87,
                            fontSize: 16,
                            height: 1.3,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.push_pin_rounded, size: 16, color: isDefaultColor ? theme.colorScheme.onSurfaceVariant : Colors.black54),
                    ),
                ],
              ),
            
            if (note.content.isNotEmpty)
              _buildContentPreview(context, isDefaultColor),

            if (note.folder != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDefaultColor ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    note.folder!,
                    style: AppTypography.labelSmall.copyWith(color: isDefaultColor ? theme.colorScheme.onSurfaceVariant : Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentPreview(BuildContext context, bool isDefaultColor) {
    final theme = Theme.of(context);
    final isChecklist = note.content.startsWith('- [ ] ') || note.content.startsWith('- [x] ');
    
    final lines = note.content.split('\n').take(8).toList();
    
    if (isChecklist) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          if (line.trim().isEmpty) return const SizedBox.shrink();
          final isChecked = line.contains('[x]');
          final text = line.replaceFirst(RegExp(r'- \[( |x)\] '), '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isChecked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                  size: 16,
                  color: isDefaultColor ? theme.colorScheme.onSurfaceVariant : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.noteContent.copyWith(
                      fontSize: 14,
                      color: isDefaultColor ? theme.colorScheme.onSurfaceVariant : Colors.black87,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // Strip markdown formatting for preview
    String previewText = note.content
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1');

    return Text(
      previewText,
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.noteContent.copyWith(
        fontSize: 14,
        color: isDefaultColor ? theme.colorScheme.onSurfaceVariant : Colors.black87,
        height: 1.4,
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
              title: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
              onTap: () { Navigator.pop(ctx); onTogglePin(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Delete note', style: TextStyle(color: AppColors.error)),
              onTap: () { Navigator.pop(ctx); onDelete(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _FolderChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(
            color: isActive ? Colors.transparent : theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isActive ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
