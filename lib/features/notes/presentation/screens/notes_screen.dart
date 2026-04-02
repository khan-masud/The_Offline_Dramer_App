import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../data/notes_provider.dart';
import 'note_editor_screen.dart';

// Note colors
const _noteColors = [
  Colors.transparent, // 0 = default
  Color(0xFFFEF3C7), // 1 = yellow
  Color(0xFFDCFCE7), // 2 = green
  Color(0xFFDBEAFE), // 3 = blue
  Color(0xFFFCE7F3), // 4 = pink
  Color(0xFFF3E8FF), // 5 = purple
  Color(0xFFFFEDD5), // 6 = orange
];

const _noteColorsDark = [
  Colors.transparent,
  Color(0xFF422006),
  Color(0xFF052E16),
  Color(0xFF172554),
  Color(0xFF4A0D2B),
  Color(0xFF2E1065),
  Color(0xFF431407),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Folder chips
          SizedBox(
            height: 44,
            child: foldersAsync.when(
              data: (folders) {
                if (folders.isEmpty) return const SizedBox.shrink();
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 8),
          // Notes grid
          Expanded(
            child: notesAsync.when(
              data: (allNotes) {
                final hidden = ref.watch(hiddenItemsProvider);
                final notes = allNotes.where((n) => !hidden.contains('note_${n.id}')).toList();
                if (notes.isEmpty) return _emptyState(context);
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final note = notes[i];
                    final colors = isDark ? _noteColorsDark : _noteColors;
                    final bgColor = note.colorIndex < colors.length ? colors[note.colorIndex] : Colors.transparent;

                    return _NoteCard(
                      note: note,
                      backgroundColor: bgColor,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                      ),
                      onTogglePin: () => ref.read(databaseProvider).toggleNotePin(note.id, !note.isPinned),
                      onDelete: () {
                        final itemKey = 'note_${note.id}';
                        ref.read(hiddenItemsProvider.notifier).update((state) => {...state, itemKey});
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Note deleted'),
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'UNDO',
                              onPressed: () {
                                ref.read(hiddenItemsProvider.notifier).update((state) => {...state}..remove(itemKey));
                              },
                            ),
                          ),
                        ).closed.then((reason) {
                          if (reason != SnackBarClosedReason.action) {
                            if (ref.read(hiddenItemsProvider).contains(itemKey)) {
                              ref.read(databaseProvider).deleteNote(note.id);
                              ref.read(hiddenItemsProvider.notifier).update((state) => {...state}..remove(itemKey));
                            }
                          }
                        });
                      },
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
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.note_alt_outlined, size: 48, color: AppColors.teal),
          ),
          const SizedBox(height: 20),
          Text('No notes yet', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Tap + to create your first note', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: ref.read(noteSearchProvider));
        return AlertDialog(
          title: const Text('Search Notes'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (v) => ref.read(noteSearchProvider.notifier).state = v,
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(noteSearchProvider.notifier).state = '';
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        );
      },
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

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor == Colors.transparent ? theme.cardTheme.color : backgroundColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pin + folder
            Row(
              children: [
                if (note.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin_rounded, size: 14, color: AppColors.warning),
                  ),
                if (note.folder != null)
                  Expanded(
                    child: Text(
                      note.folder!,
                      style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              note.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            // Content preview
            Expanded(
              child: Text(
                note.content.isEmpty ? 'No content' : note.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            // Date
            const SizedBox(height: 6),
            Text(
              _formatDate(note.updatedAt),
              style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
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
              title: Text(note.isPinned ? 'Unpin' : 'Pin'),
              onTap: () { Navigator.pop(ctx); onTogglePin(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
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
          color: isActive ? AppColors.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(color: isActive ? AppColors.primary : theme.colorScheme.outline),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(color: isActive ? Colors.white : theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
