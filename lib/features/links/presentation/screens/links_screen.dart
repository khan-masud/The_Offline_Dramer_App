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
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/link_metadata_service.dart';
import '../../data/links_provider.dart';

class LinksScreen extends ConsumerStatefulWidget {
  const LinksScreen({super.key});

  @override
  ConsumerState<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends ConsumerState<LinksScreen> {
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
    final linksAsync = ref.watch(filteredLinksProvider);
    final allLinksAsync = ref.watch(linksProvider);
    final foldersAsync = ref.watch(linkFoldersProvider);
    final activeFolder = ref.watch(linkFolderFilterProvider);
    final filterTab = ref.watch(linkFilterTabProvider);
    final viewMode = ref.watch(linkViewModeProvider);
    final sortOption = ref.watch(linkSortProvider);

    final totalCount = allLinksAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search links, tags, domains...',
                  hintStyle: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  border: InputBorder.none,
                ),
                onChanged: (v) => ref.read(linkSearchProvider.notifier).state = v,
              )
            : Row(
                children: [
                  const Text('Links'),
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
          // Search toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Close Search' : 'Search Links',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  ref.read(linkSearchProvider.notifier).state = '';
                }
              });
            },
          ),
          // View Mode Switcher
          PopupMenuButton<LinkViewMode>(
            icon: Icon(
              viewMode == LinkViewMode.rich
                  ? Icons.view_agenda_outlined
                  : viewMode == LinkViewMode.compact
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
            ),
            tooltip: 'View Layout',
            initialValue: viewMode,
            onSelected: (mode) => ref.read(linkViewModeProvider.notifier).state = mode,
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: LinkViewMode.rich,
                child: Row(
                  children: [
                    Icon(Icons.view_agenda_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Visual Cards'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LinkViewMode.compact,
                child: Row(
                  children: [
                    Icon(Icons.view_list_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Compact List'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LinkViewMode.grid,
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Grid'),
                  ],
                ),
              ),
            ],
          ),
          // Sort Options
          PopupMenuButton<LinkSortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Links',
            initialValue: sortOption,
            onSelected: (sort) => ref.read(linkSortProvider.notifier).state = sort,
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: LinkSortOption.newest,
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Newest First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LinkSortOption.oldest,
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Oldest First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LinkSortOption.titleAZ,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Title (A-Z)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LinkSortOption.domain,
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Domain'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New Folder',
            onPressed: () => _showAddFolderSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status Filter Tabs (All, Favorites, Unread, Read) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _StatusTabPill(
                    label: 'All',
                    icon: Icons.all_inbox_rounded,
                    isActive: filterTab == LinkFilterTab.all,
                    onTap: () => ref.read(linkFilterTabProvider.notifier).state = LinkFilterTab.all,
                  ),
                  _StatusTabPill(
                    label: 'Favorites',
                    icon: Icons.star_rounded,
                    activeColor: AppColors.warning,
                    isActive: filterTab == LinkFilterTab.favorites,
                    onTap: () => ref.read(linkFilterTabProvider.notifier).state = LinkFilterTab.favorites,
                  ),
                  _StatusTabPill(
                    label: 'Unread (Reading List)',
                    icon: Icons.auto_stories_rounded,
                    activeColor: AppColors.primary,
                    isActive: filterTab == LinkFilterTab.unread,
                    onTap: () => ref.read(linkFilterTabProvider.notifier).state = LinkFilterTab.unread,
                  ),
                  _StatusTabPill(
                    label: 'Archived / Read',
                    icon: Icons.check_circle_outline_rounded,
                    activeColor: AppColors.success,
                    isActive: filterTab == LinkFilterTab.read,
                    onTap: () => ref.read(linkFilterTabProvider.notifier).state = LinkFilterTab.read,
                  ),
                ],
              ),
            ),
          ),

          // ── Folder Chips ──
          foldersAsync.when(
            data: (folders) {
              if (folders.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FolderPill(
                      label: 'All Folders',
                      emoji: '📁',
                      isActive: activeFolder == null,
                      onTap: () => ref.read(linkFolderFilterProvider.notifier).state = null,
                    ),
                    ...folders.map((f) => _FolderPill(
                          label: f.name,
                          emoji: f.emoji,
                          isActive: activeFolder?.id == f.id,
                          onTap: () => ref.read(linkFolderFilterProvider.notifier).state = f,
                          onLongPress: () => _showFolderOptions(context, ref, f),
                        )),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Active Folder Header & Actions ──
          if (activeFolder != null && !_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text('${activeFolder.emoji} ${activeFolder.name}', style: AppTypography.headingSmall),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copy all links in folder',
                    icon: Icon(Icons.copy_all_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () {
                      final links = linksAsync.valueOrNull ?? [];
                      if (links.isEmpty) return;
                      final sb = StringBuffer();
                      for (int i = 0; i < links.length; i++) {
                        sb.writeln('${i + 1}. ${links[i].title} - ${links[i].url}');
                      }
                      Clipboard.setData(ClipboardData(text: sb.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${links.length} links copied!')));
                    },
                  ),
                  IconButton(
                    tooltip: 'Edit Folder',
                    icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => _showEditFolderSheet(context, ref, activeFolder),
                  ),
                  IconButton(
                    tooltip: 'Delete Folder',
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    onPressed: () => _showDeleteFolderDialog(context, ref, activeFolder),
                  )
                ],
              ),
            ),

          const SizedBox(height: 6),

          // ── Links List / Grid ──
          Expanded(
            child: linksAsync.when(
              data: (allLinks) {
                final hidden = ref.watch(hiddenItemsProvider);
                final links = allLinks.where((l) => !hidden.contains('link_${l.id}')).toList();

                if (links.isEmpty) {
                  return _emptyState(context, isSearching: _isSearching);
                }

                if (viewMode == LinkViewMode.grid) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: links.length,
                    itemBuilder: (context, i) {
                      final link = links[i];
                      return _GridLinkCard(
                        link: link,
                        onTap: () => _openLink(link.url),
                        onEdit: () => _showAddLinkSheet(context, ref, link: link),
                        onToggleFavorite: () => ref.read(databaseProvider).toggleLinkFavorite(link.id, !link.isFavorite),
                        onToggleRead: () => ref.read(databaseProvider).toggleLinkReadStatus(link.id, !link.isRead),
                        onDelete: () => _deleteLinkWithUndo(context, ref, link),
                      ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.95, 0.95));
                    },
                  );
                }

                if (viewMode == LinkViewMode.compact) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: links.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final link = links[i];
                      return _CompactLinkCard(
                        link: link,
                        onTap: () => _openLink(link.url),
                        onEdit: () => _showAddLinkSheet(context, ref, link: link),
                        onToggleFavorite: () => ref.read(databaseProvider).toggleLinkFavorite(link.id, !link.isFavorite),
                        onToggleRead: () => ref.read(databaseProvider).toggleLinkReadStatus(link.id, !link.isRead),
                        onDelete: () => _deleteLinkWithUndo(context, ref, link),
                      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
                    },
                  );
                }

                // Default: Rich Visual Cards
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: links.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final link = links[i];
                    return _RichLinkCard(
                      link: link,
                      onTap: () => _openLink(link.url),
                      onEdit: () => _showAddLinkSheet(context, ref, link: link),
                      onToggleFavorite: () => ref.read(databaseProvider).toggleLinkFavorite(link.id, !link.isFavorite),
                      onToggleRead: () => ref.read(databaseProvider).toggleLinkReadStatus(link.id, !link.isRead),
                      onDelete: () => _deleteLinkWithUndo(context, ref, link),
                    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.06, end: 0);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 12),
                      const Text('Could not load links'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'links_fab',
        onPressed: () => _showAddLinkSheet(context, ref),
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Add Link', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _deleteLinkWithUndo(BuildContext context, WidgetRef ref, Link link) {
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
        content: Text('Deleted "${link.title}"'),
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
  }

  static const _allowedSchemes = {'https', 'http', 'mailto', 'tel'};

  Future<void> _openLink(String urlString) async {
    var normalized = LinkMetadataService.normalizeUrl(urlString);
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme.isEmpty || !_allowedSchemes.contains(uri.scheme)) {
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }
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
                isSearching ? Icons.search_off_rounded : Icons.bookmark_border_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No matching links found' : 'No links saved yet',
              style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Try searching by a different title, tag, or website domain.'
                  : 'Save your favorite articles, tools, videos, and websites with 1 tap.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderOptions(BuildContext context, WidgetRef ref, LinkFolder folder) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Text(folder.emoji, style: const TextStyle(fontSize: 22)),
            title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Folder Options'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Folder'),
            onTap: () {
              Navigator.pop(ctx);
              _showEditFolderSheet(context, ref, folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: const Text('Delete Folder & Links', style: TextStyle(color: AppColors.error)),
            onTap: () {
              Navigator.pop(ctx);
              _showDeleteFolderDialog(context, ref, folder);
            },
          ),
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
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: theme.colorScheme.outline.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(folder == null ? 'Create Folder' : 'Edit Folder', style: AppTypography.headingMedium),
              const SizedBox(height: 20),
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
                      decoration: const InputDecoration(labelText: 'Folder Name', hintText: 'e.g. Work, Tech, Design'),
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
                  child: const Text('Save Folder', style: TextStyle(fontWeight: FontWeight.bold)),
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
        content: Text('Delete "${folder.name}" and all links inside this folder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(linkFolderFilterProvider.notifier).state = null;
              ref.read(databaseProvider).deleteLinkFolder(folder.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
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
      builder: (ctx) => _AddEditLinkSheet(link: link),
    );
  }
}

// ────────────────── STATUS TAB PILL ──────────────────

class _StatusTabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  const _StatusTabPill({
    required this.label,
    required this.icon,
    required this.isActive,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = activeColor ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isActive ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? color : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? color : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────── FOLDER PILL ──────────────────

class _FolderPill extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FolderPill({
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────── 1. RICH VISUAL LINK CARD ──────────────────

class _RichLinkCard extends StatelessWidget {
  final Link link;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleRead;

  const _RichLinkCard({
    required this.link,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final uri = Uri.tryParse(link.url);
    final domain = uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
    final faviconUrl = LinkMetadataService.getFaviconUrl(link.url);
    final hasImage = link.previewImageUrl != null && link.previewImageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.06),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Bar: Favicon + Domain + Category + Status + Favorite ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
                child: Row(
                  children: [
                    // Favicon Badge
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          faviconUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.language_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Domain & Category Pill
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  domain.isNotEmpty ? domain : link.url,
                                  style: AppTypography.labelMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (link.category != null && link.category!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    link.category!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            link.url,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // 1-Tap Reading Status Pill
                    GestureDetector(
                      onTap: onToggleRead,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: link.isRead
                              ? AppColors.success.withValues(alpha: 0.12)
                              : theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: link.isRead
                                ? AppColors.success.withValues(alpha: 0.3)
                                : theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              link.isRead ? Icons.check_circle_rounded : Icons.auto_stories_outlined,
                              size: 13,
                              color: link.isRead ? AppColors.success : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              link.isRead ? 'Read' : 'Unread',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: link.isRead ? AppColors.success : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Favorite Button
                    IconButton(
                      icon: Icon(
                        link.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        color: link.isFavorite ? AppColors.warning : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: link.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
                      onPressed: onToggleFavorite,
                    ),
                  ],
                ),
              ),

              // ── Banner Image or Decorative Header Preview ──
              if (hasImage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            link.previewImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                          // Subtle bottom vignette gradient
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.35),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Card Body (Title, Description, Tags, Notes) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      link.title,
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Description
                    if (link.description != null && link.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        link.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                          fontSize: 12.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Tags
                    if (link.tags != null && link.tags!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: link.tags!
                            .split(',')
                            .map((t) => t.trim())
                            .where((t) => t.isNotEmpty)
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '#',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        t,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ],

                    // Personal Note (Annotation Callout)
                    if (link.note != null && link.note!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.12),
                            ),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 3.5,
                                  color: theme.colorScheme.primary,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.edit_note_rounded,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            link.note!,
                                            style: AppTypography.bodySmall.copyWith(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                              height: 1.35,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Action Toolbar ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Open in Browser Capsule Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: onTap,
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),

                    // Copy Link Button
                    IconButton.filledTonal(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy Link',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: link.url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied to clipboard! 📋')),
                        );
                      },
                    ),
                    const Spacer(),

                    // Edit
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Edit Bookmark',
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                    ),

                    // Delete
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      tooltip: 'Delete Bookmark',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────── 2. COMPACT LINK CARD ──────────────────

class _CompactLinkCard extends StatelessWidget {
  final Link link;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleRead;

  const _CompactLinkCard({
    required this.link,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final uri = Uri.tryParse(link.url);
    final domain = uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
    final faviconUrl = LinkMetadataService.getFaviconUrl(link.url);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.12),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Favicon in elevated tile
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network(
                      faviconUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.language_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Domain
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            domain.isNotEmpty ? domain : link.url,
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (link.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Read',
                                style: TextStyle(fontSize: 9, color: AppColors.success, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Quick Favorite
                IconButton(
                  icon: Icon(
                    link.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: link.isFavorite ? AppColors.warning : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleFavorite,
                ),

                // Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  onSelected: (val) {
                    if (val == 'read') onToggleRead();
                    if (val == 'edit') onEdit();
                    if (val == 'copy') {
                      Clipboard.setData(ClipboardData(text: link.url));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
                    }
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'read',
                      child: Row(
                        children: [
                          Icon(link.isRead ? Icons.mark_email_unread_outlined : Icons.check_circle_outline_rounded, size: 18),
                          const SizedBox(width: 10),
                          Text(link.isRead ? 'Mark as Unread' : 'Mark as Read'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Copy Link'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────── 3. GRID LINK CARD ──────────────────

class _GridLinkCard extends StatelessWidget {
  final Link link;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleRead;

  const _GridLinkCard({
    required this.link,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final faviconUrl = LinkMetadataService.getFaviconUrl(link.url);
    final uri = Uri.tryParse(link.url);
    final domain = uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
    final hasImage = link.previewImageUrl != null && link.previewImageUrl!.isNotEmpty;

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
            blurRadius: 8,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner / Thumbnail Area
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasImage)
                        Image.network(
                          link.previewImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Image.network(faviconUrl, width: 32, height: 32),
                          ),
                        )
                      else
                        Center(
                          child: Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                            ),
                            child: Image.network(
                              faviconUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.language_rounded, color: theme.colorScheme.primary),
                            ),
                          ),
                        ),
                      // Top-right favorite button overlay
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: onToggleFavorite,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              link.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 16,
                              color: link.isFavorite ? AppColors.warning : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Area
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.network(
                            faviconUrl,
                            width: 12,
                            height: 12,
                            errorBuilder: (_, __, ___) => const Icon(Icons.language_rounded, size: 12),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              domain,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        link.title,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (link.tags != null && link.tags!.isNotEmpty)
                        Text(
                          '#${link.tags!.split(',').first.trim()}',
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────── ADD / EDIT LINK SHEET ──────────────────

class _AddEditLinkSheet extends ConsumerStatefulWidget {
  final Link? link;
  const _AddEditLinkSheet({this.link});

  @override
  ConsumerState<_AddEditLinkSheet> createState() => _AddEditLinkSheetState();
}

class _AddEditLinkSheetState extends ConsumerState<_AddEditLinkSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _imageCtrl;
  String? _selectedFolder;
  int? _selectedFolderId;
  bool _isFetching = false;
  Link? _duplicateLink;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.link?.title ?? '');
    _urlCtrl = TextEditingController(text: widget.link?.url ?? '');
    _noteCtrl = TextEditingController(text: widget.link?.note ?? '');
    _descCtrl = TextEditingController(text: widget.link?.description ?? '');
    _tagsCtrl = TextEditingController(text: widget.link?.tags ?? '');
    _imageCtrl = TextEditingController(text: widget.link?.previewImageUrl ?? '');
    _selectedFolder = widget.link?.category;
    _selectedFolderId = widget.link?.folderId;

    _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    if (widget.link != null) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text != null && (text.startsWith('http://') || text.startsWith('https://'))) {
      if (_urlCtrl.text.isEmpty) {
        setState(() => _urlCtrl.text = text);
        _fetchMetadata();
      }
    }
  }

  Future<void> _fetchMetadata() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    // Check duplicate
    final db = ref.read(databaseProvider);
    final dup = await db.getDuplicateLink(url);
    if (dup != null && dup.id != widget.link?.id) {
      setState(() => _duplicateLink = dup);
    } else {
      setState(() => _duplicateLink = null);
    }

    setState(() => _isFetching = true);
    final meta = await LinkMetadataService.fetchMetadata(url);

    if (mounted) {
      setState(() {
        if (_titleCtrl.text.isEmpty || _titleCtrl.text == url) {
          _titleCtrl.text = meta.title;
        }
        if (_descCtrl.text.isEmpty && meta.description != null) {
          _descCtrl.text = meta.description!;
        }
        if (_imageCtrl.text.isEmpty && meta.imageUrl != null) {
          _imageCtrl.text = meta.imageUrl!;
        }
        _isFetching = false;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _noteCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    final title = _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final tags = _tagsCtrl.text.trim();
    final image = _imageCtrl.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a URL')));
      return;
    }

    final normalizedUrl = LinkMetadataService.normalizeUrl(url);
    final finalTitle = title.isNotEmpty ? title : (Uri.tryParse(normalizedUrl)?.host ?? normalizedUrl);

    final db = ref.read(databaseProvider);
    if (widget.link != null) {
      await db.updateLink(LinksCompanion(
        id: Value(widget.link!.id),
        title: Value(finalTitle),
        url: Value(normalizedUrl),
        category: Value(_selectedFolder),
        folderId: Value(_selectedFolderId),
        description: Value(desc.isEmpty ? null : desc),
        previewImageUrl: Value(image.isEmpty ? null : image),
        tags: Value(tags.isEmpty ? null : tags),
        note: Value(note.isEmpty ? null : note),
      ));
      ref.read(activityLogProvider.notifier).log(
            entityType: 'link',
            entityTitle: finalTitle,
            action: 'updated',
          );
    } else {
      await db.addLink(LinksCompanion(
        title: Value(finalTitle),
        url: Value(normalizedUrl),
        category: Value(_selectedFolder),
        folderId: Value(_selectedFolderId),
        description: Value(desc.isEmpty ? null : desc),
        previewImageUrl: Value(image.isEmpty ? null : image),
        tags: Value(tags.isEmpty ? null : tags),
        note: Value(note.isEmpty ? null : note),
        createdAt: Value(DateTime.now()),
      ));
      ref.read(activityLogProvider.notifier).log(
            entityType: 'link',
            entityTitle: finalTitle,
            action: 'added',
          );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foldersAsync = ref.watch(linkFoldersProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.link == null ? 'Add Link' : 'Edit Link', style: AppTypography.headingMedium),
                if (_isFetching)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Duplicate URL warning banner
            if (_duplicateLink != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This URL is already saved as "${_duplicateLink!.title}".',
                        style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // URL input with auto-fetch button
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: 'URL *',
                hintText: 'https://example.com/article',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  tooltip: 'Fetch Page Info',
                  onPressed: _fetchMetadata,
                ),
              ),
              onSubmitted: (_) => _fetchMetadata(),
            ),
            const SizedBox(height: 12),

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Page or article title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Short summary or excerpt',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Folder Selector
            foldersAsync.when(
              data: (folders) {
                return DropdownButtonFormField<String>(
                  initialValue: _selectedFolder,
                  decoration: const InputDecoration(
                    labelText: 'Folder',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No Folder (General)')),
                    ...folders.map((f) => DropdownMenuItem(
                          value: f.name,
                          child: Text('${f.emoji} ${f.name}'),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedFolder = val;
                      _selectedFolderId = folders.where((f) => f.name == val).firstOrNull?.id;
                    });
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),

            // Tags
            TextField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                hintText: 'e.g. flutter, design, tools',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Personal Notes (Optional)',
                hintText: 'Add thoughts or key takeaways...',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(widget.link == null ? 'Save Bookmark' : 'Update Bookmark',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
