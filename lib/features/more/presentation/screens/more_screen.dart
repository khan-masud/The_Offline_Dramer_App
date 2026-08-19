import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/tools_provider.dart';

enum ToolsLayoutMode { grid, list }

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  late TextEditingController _searchCtrl;
  Timer? _debounceTimer;
  ToolsLayoutMode _layoutMode = ToolsLayoutMode.grid;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // 300ms Ajax Debouncer
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(toolsPersonalizationProvider.notifier).setSearchQuery(query);
    });
  }

  void _handleToolTap(ToolItem tool) async {
    ref.read(toolsPersonalizationProvider.notifier).trackUsage(tool.id);

    if (tool.route.startsWith('http://') || tool.route.startsWith('https://')) {
      final uri = Uri.parse(tool.route);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open GitHub Issues page.')),
          );
        }
      }
    } else {
      Navigator.pushNamed(context, tool.route);
    }
  }

  void _showPinManagerSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final theme = Theme.of(context);
          final personalization = ref.watch(toolsPersonalizationProvider);
          final pinnedIds = personalization.pinnedIds;

          return Material(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Header
                Row(
                  children: [
                    const Icon(Icons.push_pin_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Customize Featured Tools', style: AppTypography.headingSmall),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Pin your most-used tools to keep them at the top of your dashboard.',
                  style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // List of tools with toggle switches
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: allAppTools.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final tool = allAppTools[i];
                      final isPinned = pinnedIds.contains(tool.id);

                      return SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tool.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(tool.icon, size: 20, color: tool.color),
                        ),
                        title: Text(
                          tool.label,
                          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          tool.description,
                          style: AppTypography.bodySmall.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: isPinned,
                        activeThumbColor: AppColors.primary,
                        onChanged: (_) {
                          ref.read(toolsPersonalizationProvider.notifier).togglePin(tool.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sortedTools = ref.watch(sortedAndFilteredToolsProvider);
    final personalization = ref.watch(toolsPersonalizationProvider);
    final pinnedIds = personalization.pinnedIds;
    final searchQuery = personalization.searchQuery;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('More Tools', style: AppTypography.headingLarge.copyWith(color: theme.colorScheme.onSurface)),
                        const SizedBox(height: 2),
                        Text(
                          'Explore more tools and pin your favourite for quick access',
                          style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),

                  // Actions Group: Pin Manager + Layout Mode Switcher (Grid vs List)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pin Manager Button
                        IconButton(
                          icon: Icon(
                            pinnedIds.isNotEmpty ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                            size: 18,
                            color: pinnedIds.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Manage Pinned Tools',
                          onPressed: () => _showPinManagerSheet(context, ref),
                        ),
                        Container(height: 16, width: 1, color: theme.colorScheme.outline.withValues(alpha: 0.2)),

                        // Grid View Button
                        IconButton(
                          icon: Icon(
                            Icons.grid_view_rounded,
                            size: 18,
                            color: _layoutMode == ToolsLayoutMode.grid ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _layoutMode = ToolsLayoutMode.grid),
                        ),

                        // List View Button
                        IconButton(
                          icon: Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 18,
                            color: _layoutMode == ToolsLayoutMode.list ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _layoutMode = ToolsLayoutMode.list),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Real-Time Debounced Ajax Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search tools (e.g. diary, notes, money, timer)...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(toolsPersonalizationProvider.notifier).setSearchQuery('');
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                    ),
                  ),
                ),
              ),
            ),

            // ── Sorted Tools List / Grid Body ──
            Expanded(
              child: sortedTools.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text('No tools matching "$searchQuery"', style: AppTypography.headingSmall),
                            const SizedBox(height: 4),
                            Text('Try searching for keywords like diary, notes, money, habits, timer', style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                    )
                  : _layoutMode == ToolsLayoutMode.grid
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.96,
                          ),
                          itemCount: sortedTools.length,
                          itemBuilder: (context, i) {
                            final tool = sortedTools[i];
                            final isPinned = pinnedIds.contains(tool.id);

                            return _GridToolCard(
                              tool: tool,
                              isPinned: isPinned,
                              onTap: () => _handleToolTap(tool),
                            ).animate().fadeIn(delay: (30 * i).ms, duration: 250.ms).scale(begin: const Offset(0.95, 0.95));
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const BouncingScrollPhysics(),
                          itemCount: sortedTools.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final tool = sortedTools[i];
                            final isPinned = pinnedIds.contains(tool.id);

                            return _ListToolCard(
                              tool: tool,
                              isPinned: isPinned,
                              onTap: () => _handleToolTap(tool),
                            ).animate().fadeIn(delay: (30 * i).ms, duration: 250.ms).slideY(begin: 0.05, end: 0);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────── GRID TOOL CARD ──────────────────

class _GridToolCard extends StatelessWidget {
  final ToolItem tool;
  final bool isPinned;
  final VoidCallback onTap;

  const _GridToolCard({
    required this.tool,
    required this.isPinned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPinned
                  ? tool.color.withValues(alpha: 0.45)
                  : theme.colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
              width: isPinned ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : tool.color.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Floating Top-Right Pin Badge (ONLY displayed if tool IS pinned)
              if (isPinned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.push_pin_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),

              // Dead-Center Content Column
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Centered Icon with Gradient Squircle Badge
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tool.color.withValues(alpha: isDark ? 0.25 : 0.16),
                              tool.color.withValues(alpha: isDark ? 0.12 : 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: tool.color.withValues(alpha: 0.2),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          tool.icon,
                          size: 26,
                          color: tool.color,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tool Label
                      Text(
                        tool.label,
                        style: AppTypography.labelMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.1,
                        ),
                        textAlign: TextAlign.center,
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

// ────────────────── LIST TOOL CARD ──────────────────

class _ListToolCard extends StatelessWidget {
  final ToolItem tool;
  final bool isPinned;
  final VoidCallback onTap;

  const _ListToolCard({
    required this.tool,
    required this.isPinned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tool.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tool.icon, size: 22, color: tool.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Text(
                  tool.label,
                  style: AppTypography.labelLarge.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (isPinned) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.push_pin_rounded, size: 14, color: AppColors.primary),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
