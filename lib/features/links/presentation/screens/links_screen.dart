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
import '../../data/links_provider.dart';

class LinksScreen extends ConsumerWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final linksAsync = ref.watch(filteredLinksProvider);
    final categoriesAsync = ref.watch(linkCategoriesProvider);
    final activeCategory = ref.watch(linkCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Links'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category chips
          SizedBox(
            height: 44,
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) return const SizedBox.shrink();
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      isActive: activeCategory == null,
                      onTap: () => ref.read(linkCategoryFilterProvider.notifier).state = null,
                    ),
                    ...categories.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CategoryChip(
                        label: c,
                        emoji: linkCategoryIcons[c],
                        isActive: activeCategory == c,
                        onTap: () => ref.read(linkCategoryFilterProvider.notifier).state = c,
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
          // Links list
          Expanded(
            child: linksAsync.when(
              data: (links) {
                if (links.isEmpty) return _emptyState(context);
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: links.length,
                  itemBuilder: (context, i) {
                    return _LinkTile(
                      link: links[i],
                      onOpen: () => _openLink(context, links[i].url),
                      onCopy: () => _copyLink(context, links[i].url),
                      onEdit: () => _showAddEditSheet(context, ref, link: links[i]),
                      onDelete: () => ref.read(databaseProvider).deleteLink(links[i].id),
                      onToggleFavorite: () => ref.read(databaseProvider).toggleLinkFavorite(
                        links[i].id, !links[i].isFavorite,
                      ),
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
        heroTag: 'links_fab',
        onPressed: () => _showAddEditSheet(context, ref),
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
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.link_rounded, size: 48, color: AppColors.info),
          ),
          const SizedBox(height: 20),
          Text('No links saved', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Tap + to save your first link', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    var uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!uri.hasScheme) {
      uri = Uri.parse('https://$url');
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _copyLink(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard ✓'), duration: Duration(seconds: 2)),
    );
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: ref.read(linkSearchProvider));
        return AlertDialog(
          title: const Text('Search Links'),
          content: TextField(
            controller: controller,
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

  void _showAddEditSheet(BuildContext context, WidgetRef ref, {Link? link}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditLinkSheet(link: link),
    );
  }
}

// ==================== LINK TILE ====================
class _LinkTile extends StatelessWidget {
  final Link link;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const _LinkTile({
    required this.link,
    required this.onOpen,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emoji = linkCategoryIcons[link.category ?? ''] ?? '🔗';
    final domain = _extractDomain(link.url);

    return Dismissible(
      key: ValueKey(link.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          onTap: onOpen,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.title,
                      style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      domain,
                      style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggleFavorite,
                child: Icon(
                  link.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: link.isFavorite ? AppColors.warning : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                onSelected: (v) {
                  switch (v) {
                    case 'copy': onCopy();
                    case 'edit': onEdit();
                    case 'delete': onDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy_rounded), title: Text('Copy URL'), dense: true)),
                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), dense: true)),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: AppColors.error), title: Text('Delete', style: TextStyle(color: AppColors.error)), dense: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _extractDomain(String url) {
    try {
      var uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) return uri.host;
      uri = Uri.tryParse('https://$url');
      if (uri != null && uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    return url.length > 40 ? '${url.substring(0, 40)}...' : url;
  }
}

// ==================== ADD/EDIT SHEET ====================
class _AddEditLinkSheet extends ConsumerStatefulWidget {
  final Link? link;
  const _AddEditLinkSheet({this.link});

  @override
  ConsumerState<_AddEditLinkSheet> createState() => _AddEditLinkSheetState();
}

class _AddEditLinkSheetState extends ConsumerState<_AddEditLinkSheet> {
  late TextEditingController _urlCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  String? _category;

  bool get isEditing => widget.link != null;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.link?.url ?? '');
    _titleCtrl = TextEditingController(text: widget.link?.title ?? '');
    _noteCtrl = TextEditingController(text: widget.link?.note ?? '');
    _category = widget.link?.category ?? defaultLinkCategories.first;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_urlCtrl.text.trim().isEmpty) return;
    if (_titleCtrl.text.trim().isEmpty) {
      // Auto-generate title from URL
      _titleCtrl.text = _extractTitle(_urlCtrl.text.trim());
    }

    final db = ref.read(databaseProvider);

    if (isEditing) {
      await db.updateLink(LinksCompanion(
        id: Value(widget.link!.id),
        url: Value(_urlCtrl.text.trim()),
        title: Value(_titleCtrl.text.trim()),
        category: Value(_category),
        note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
      ));
    } else {
      await db.addLink(LinksCompanion(
        url: Value(_urlCtrl.text.trim()),
        title: Value(_titleCtrl.text.trim()),
        category: Value(_category),
        note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
        createdAt: Value(DateTime.now()),
      ));
    }

    if (mounted) Navigator.pop(context);
  }

  String _extractTitle(String url) {
    try {
      var uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) {
        uri = Uri.tryParse('https://$url');
      }
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host.replaceFirst('www.', '');
      }
    } catch (_) {}
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(isEditing ? 'Edit Link' : 'Save Link', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            // URL
            TextField(
              controller: _urlCtrl,
              autofocus: !isEditing,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://...', prefixIcon: Icon(Icons.link_rounded)),
              style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            // Title
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Title (auto-generated if empty)'),
              style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            // Category
            Text('Category', style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: defaultLinkCategories.map((cat) {
                final isActive = _category == cat;
                final emoji = linkCategoryIcons[cat] ?? '🔗';
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.info.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      border: Border.all(color: isActive ? AppColors.info : theme.colorScheme.outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(cat, style: AppTypography.labelMedium.copyWith(
                          color: isActive ? AppColors.info : theme.colorScheme.onSurfaceVariant,
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Note
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(hintText: 'Note (optional)...'),
              style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(isEditing ? 'Save Changes' : 'Save Link', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ==================== CATEGORY CHIP ====================
class _CategoryChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool isActive;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, this.emoji, required this.isActive, required this.onTap});

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(color: isActive ? Colors.white : theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
