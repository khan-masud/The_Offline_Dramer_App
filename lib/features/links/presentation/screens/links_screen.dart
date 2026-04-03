import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/links_provider.dart';

class LinksScreen extends ConsumerWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final linksAsync = ref.watch(filteredLinksProvider);
    final foldersAsync = ref.watch(linkFoldersProvider);
    final activeFolder = ref.watch(linkFolderFilterProvider);
    final searchQuery = ref.watch(linkSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Links'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showAddFolderSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Folder chips
          SizedBox(
            height: 48,
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
                      emoji: '📚',
                      isActive: activeFolder == null,
                      onTap: () => ref.read(linkFolderFilterProvider.notifier).state = null,
                    ),
                    ...folders.map((f) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FolderChip(
                        label: f.name,
                        emoji: f.emoji,
                        isActive: activeFolder?.id == f.id,
                        onTap: () => ref.read(linkFolderFilterProvider.notifier).state = f,
                      ),
                    )),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          
          if (searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text('Showing results for "$searchQuery"', style: AppTypography.labelMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.read(linkSearchProvider.notifier).state = '',
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Custom Folder Management info
          if (activeFolder != null && searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('${activeFolder.emoji} ${activeFolder.name}', style: AppTypography.headingSmall),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copy all links',
                    icon: Icon(Icons.copy_all_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () {
                      final linksAsyncVal = ref.read(filteredLinksProvider);
                      linksAsyncVal.whenData((links) {
                        if (links.isEmpty) return;
                        final sb = StringBuffer();
                        for (int i = 0; i < links.length; i++) {
                          sb.writeln('${i + 1}. ${links[i].url}');
                        }
                        Clipboard.setData(ClipboardData(text: sb.toString()));
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${links.length} links copied to clipboard')));
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => _showEditFolderSheet(context, ref, activeFolder),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    onPressed: () => _showDeleteFolderDialog(context, ref, activeFolder),
                  )
                ],
              ),
            ),

          // Links List
          Expanded(
            child: linksAsync.when(
              data: (allLinks) {
                final hidden = ref.watch(hiddenItemsProvider);
                final links = allLinks.where((l) => !hidden.contains('link_${l.id}')).toList();

                if (links.isEmpty) return _emptyState(context);

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: links.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final link = links[i];
                    return _LinkCard(
                      link: link,
                      onTap: () => _openLink(link.url),
                      onEdit: () => _showAddLinkSheet(context, ref, link: link),
                      onToggleFavorite: () => ref.read(databaseProvider).toggleLinkFavorite(link.id, !link.isFavorite),
                      onDelete: () {
                        final itemKey = 'link_${link.id}';
                        final db = ref.read(databaseProvider);
                        final hiddenNotifier = ref.read(hiddenItemsProvider.notifier);
                        final messenger = ScaffoldMessenger.of(context);
                        
                        hiddenNotifier.update((s) => {...s, itemKey});
                        messenger.clearSnackBars();
                        
                        bool undone = false;
                        final timer = Timer(const Duration(seconds: 5), () {
                          if (!undone) {
                            db.deleteLink(link.id);
                            hiddenNotifier.update((s) {
                              final ns = {...s};
                              ns.remove(itemKey);
                              return ns;
                            });
                            ref.read(activityLogProvider.notifier).log(
                              entityType: 'link',
                              entityTitle: link.title,
                              action: 'deleted',
                            );
                          }
                          messenger.hideCurrentSnackBar();
                        });
                        
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Link deleted'),
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: 'UNDO',
                              onPressed: () {
                                undone = true;
                                timer.cancel();
                                messenger.hideCurrentSnackBar();
                                hiddenNotifier.update((s) {
                                  final ns = {...s};
                                  ns.remove(itemKey);
                                  return ns;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: (50 * i).ms, duration: 300.ms).slideY(begin: 0.1, end: 0, delay: (50 * i).ms);
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
        heroTag: 'links_fab',
        onPressed: () => _showAddLinkSheet(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: ref.read(linkSearchProvider));
        return AlertDialog(
          title: const Text('Search Links'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (v) => ref.read(linkSearchProvider.notifier).state = v,
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(linkSearchProvider.notifier).state = '';
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

  Future<void> _openLink(String urlString) async {
    final url = Uri.tryParse(urlString);
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.link_rounded, size: 48, color: AppColors.purple),
          ),
          const SizedBox(height: 16),
          Text('No links found', style: AppTypography.headingMedium),
        ],
      ),
    );
  }

  void _showAddFolderSheet(BuildContext context, WidgetRef ref) {
    _showFolderSheet(context, ref, null);
  }

  void _showEditFolderSheet(BuildContext context, WidgetRef ref, LinkFolder folder) {
    _showFolderSheet(context, ref, folder);
  }

  void _showFolderSheet(BuildContext context, WidgetRef ref, LinkFolder? folder) {
    final nameCtrl = TextEditingController(text: folder?.name ?? '');
    final emojiCtrl = TextEditingController(text: folder?.emoji ?? '📁');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(folder == null ? 'Create Folder' : 'Edit Folder', style: AppTypography.headingMedium),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: emojiCtrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                      decoration: const InputDecoration(labelText: 'Emoji'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Folder Name'),
                      autofocus: folder == null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final db = ref.read(databaseProvider);
                    if (folder == null) {
                      await db.addLinkFolder(LinkFoldersCompanion(
                        name: Value(nameCtrl.text.trim()),
                        emoji: Value(emojiCtrl.text.trim().isEmpty ? '📁' : emojiCtrl.text.trim()),
                        createdAt: Value(DateTime.now()),
                      ));
                    } else {
                      await db.updateLinkFolder(LinkFoldersCompanion(
                        id: Value(folder.id),
                        name: Value(nameCtrl.text.trim()),
                        emoji: Value(emojiCtrl.text.trim().isEmpty ? '📁' : emojiCtrl.text.trim()),
                      ));
                      if (ref.read(linkFolderFilterProvider)?.id == folder.id) {
                        ref.read(linkFolderFilterProvider.notifier).state = null;
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Folder'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteFolderDialog(BuildContext context, WidgetRef ref, LinkFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Are you sure you want to delete "${folder.name}"? This will also delete ALL links inside this folder.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(linkFolderFilterProvider.notifier).state = null;
              ref.read(databaseProvider).deleteLinkFolder(folder.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddLinkSheet(BuildContext context, WidgetRef ref, {Link? link}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddLinkSheet(link: link),
    );
  }
}

class _FolderChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isActive;
  final VoidCallback onTap;

  const _FolderChip({
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? AppColors.primary : theme.colorScheme.surface;
    final textColor = isActive ? Colors.white : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(
            color: isActive ? color : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.labelMedium.copyWith(color: textColor)),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final Link link;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const _LinkCard({
    required this.link,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = Uri.tryParse(link.url);
    final domain = uri?.host ?? '';
    
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Favicon placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Center(
                    child: Text(
                      domain.isNotEmpty ? domain[0].toUpperCase() : '🔗',
                      style: AppTypography.headingMedium.copyWith(color: AppColors.purple),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(link.title, style: AppTypography.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.link_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              domain.isNotEmpty ? domain : link.url,
                              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (link.category != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            link.category!,
                            style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (link.note != null && link.note!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5))),
              ),
              child: Text(
                link.note!,
                style: AppTypography.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onTap,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Copy Link',
                        icon: Icon(Icons.copy_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link.url));
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(link.isFavorite ? Icons.star_rounded : Icons.star_border_rounded, 
                      color: link.isFavorite ? AppColors.warning : theme.colorScheme.onSurfaceVariant),
                  onPressed: onToggleFavorite,
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLinkSheet extends ConsumerStatefulWidget {
  final Link? link;
  const _AddLinkSheet({this.link});

  @override
  ConsumerState<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends ConsumerState<_AddLinkSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _noteCtrl;
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.link?.title ?? '');
    _urlCtrl = TextEditingController(text: widget.link?.url ?? '');
    _noteCtrl = TextEditingController(text: widget.link?.note ?? '');
    _selectedFolder = widget.link?.category;
    
    _checkClipboardForUrl();
  }

  Future<void> _checkClipboardForUrl() async {
    if (widget.link != null) return; // Don't overwrite if editing
    
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text != null && (text.startsWith('http://') || text.startsWith('https://'))) {
      if (_urlCtrl.text.isEmpty) {
        setState(() {
          _urlCtrl.text = text;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    final title = _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (title.isEmpty || url.isEmpty || _selectedFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title, URL, and Folder are required')));
      return;
    }

    final db = ref.read(databaseProvider);
    if (widget.link != null) {
      await db.updateLink(LinksCompanion(
        id: Value(widget.link!.id),
        title: Value(title),
        url: Value(url),
        category: Value(_selectedFolder),
        note: Value(note.isEmpty ? null : note),
      ));
      ref.read(activityLogProvider.notifier).log(
        entityType: 'link',
        entityTitle: title,
        action: 'updated',
      );
    } else {
      await db.addLink(LinksCompanion(
        title: Value(title),
        url: Value(url),
        category: Value(_selectedFolder),
        note: Value(note.isEmpty ? null : note),
        createdAt: Value(DateTime.now()),
      ));
      ref.read(activityLogProvider.notifier).log(
        entityType: 'link',
        entityTitle: title,
        action: 'added',
      );
    }
    
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final foldersAsync = ref.watch(linkFoldersProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.link != null ? 'Edit Link' : 'Save Link', style: AppTypography.headingMedium),
          const SizedBox(height: 24),
          
          // Folder Selection
          Text('Folder*', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: foldersAsync.when(
              data: (folders) {
                if (folders.isEmpty) return const Text('No folders available.');
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedFolder,
                    hint: const Text('Select a folder'),
                    items: folders.map((f) => DropdownMenuItem(
                      value: f.name,
                      child: Text('${f.emoji} ${f.name}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedFolder = v),
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading folders'),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(labelText: 'URL*', hintText: 'https://...', prefixIcon: Icon(Icons.link_rounded)),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title*', prefixIcon: Icon(Icons.title_rounded)),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes_rounded)),
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Save Link'),
          ),
        ],
      ),
    );
  }
}
