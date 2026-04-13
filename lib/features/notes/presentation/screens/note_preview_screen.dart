import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../../../core/providers/undo_provider.dart';
import '../../../../core/services/pdf_file_saver.dart';
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

enum _PreviewMenuAction {
  exportPdf,
}

class _HeadingItem {
  final int level;
  final String title;
  final int lineIndex;
  final GlobalKey anchorKey;

  const _HeadingItem({
    required this.level,
    required this.title,
    required this.lineIndex,
    required this.anchorKey,
  });
}

class _ColorTagSyntax extends md.InlineSyntax {
  _ColorTagSyntax() : super(r'\[color=(#[0-9A-Fa-f]{6})\](.*?)\[/color\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('color', match.group(2) ?? '');
    element.attributes['hex'] = match.group(1) ?? '';
    parser.addNode(element);
    return true;
  }
}

class _BgTagSyntax extends md.InlineSyntax {
  _BgTagSyntax() : super(r'\[bg=(#[0-9A-Fa-f]{6})\](.*?)\[/bg\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('bg', match.group(2) ?? '');
    element.attributes['hex'] = match.group(1) ?? '';
    parser.addNode(element);
    return true;
  }
}

class _ColorTagBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final hex = element.attributes['hex'];
    final color = _hexToColor(hex);
    return Text(
      element.textContent,
      style: (preferredStyle ?? const TextStyle()).copyWith(color: color),
    );
  }
}

class _BgTagBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final hex = element.attributes['hex'];
    final bg = _hexToColor(hex);
    return Text(
      element.textContent,
      style: (preferredStyle ?? const TextStyle()).copyWith(backgroundColor: bg),
    );
  }
}

Color? _hexToColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
  final intValue = int.tryParse(hex.substring(1), radix: 16);
  if (intValue == null) return null;
  return Color(0xFF000000 | intValue);
}

class NotePreviewScreen extends ConsumerStatefulWidget {
  final Note note;

  const NotePreviewScreen({super.key, required this.note});

  @override
  ConsumerState<NotePreviewScreen> createState() => _NotePreviewScreenState();
}

class _NotePreviewScreenState extends ConsumerState<NotePreviewScreen> {
  bool _showToc = false;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _headingAnchors = <int, GlobalKey>{};
  List<_HeadingItem> _currentHeadings = const <_HeadingItem>[];
  int? _activeHeadingLineIndex;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    _updateActiveHeadingByScroll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? _noteColorsDark : _noteColors;
    final bgColor = widget.note.colorIndex < colors.length ? colors[widget.note.colorIndex] : Colors.transparent;
    final isDefaultColor = bgColor == Colors.transparent;
    final effectiveBg = isDefaultColor ? theme.scaffoldBackgroundColor : bgColor;
    final textColor = isDefaultColor ? theme.colorScheme.onSurface : (isDark ? Colors.white : Colors.black87);
    final subtextColor = isDefaultColor
        ? theme.colorScheme.onSurfaceVariant
        : (isDark ? Colors.white70 : Colors.black54);

    final notesAsync = ref.watch(notesProvider);
    final currentNote = notesAsync.whenData((notes) {
      try {
        return notes.firstWhere((n) => n.id == widget.note.id);
      } catch (_) {
        return widget.note;
      }
    }).valueOrNull;

    final headings = currentNote == null ? const <_HeadingItem>[] : _extractHeadings(currentNote.content);
    _currentHeadings = headings;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateActiveHeadingByScroll();
      }
    });
    final headingsByLine = <int, _HeadingItem>{
      for (final h in headings) h.lineIndex: h,
    };

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
            icon: const Icon(Icons.content_copy_rounded),
            tooltip: 'Copy plain text',
            onPressed: () => _copyPlainText(context, currentNote),
          ),
          PopupMenuButton<_PreviewMenuAction>(
            tooltip: 'More options',
            onSelected: (action) {
              switch (action) {
                case _PreviewMenuAction.exportPdf:
                  _exportAsPdf(context, currentNote);
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: _PreviewMenuAction.exportPdf,
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined),
                    SizedBox(width: 10),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
          ),
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
        controller: _scrollController,
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
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _showToc = !_showToc),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.toc_rounded, color: theme.colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Table of Contents',
                              style: AppTypography.labelLarge.copyWith(color: textColor),
                            ),
                          ),
                          Icon(
                            _showToc ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: subtextColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showToc)
                    if (headings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No headings in this note',
                            style: AppTypography.bodySmall.copyWith(color: subtextColor),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Column(
                          children: headings.map((item) {
                            final leftPad = ((item.level - 1) * 12).toDouble();
                            final isActive = _activeHeadingLineIndex == item.lineIndex;
                            return ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              tileColor: isActive
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              contentPadding: EdgeInsets.fromLTRB(8 + leftPad, 0, 8, 0),
                              leading: Text(
                                'H${item.level}',
                                style: AppTypography.labelMedium.copyWith(
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelLarge.copyWith(
                                  color: isActive ? theme.colorScheme.primary : textColor,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              onTap: () => _jumpToHeading(item),
                            );
                          }).toList(),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Divider(color: subtextColor.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 22),
            if (currentNote.content.trim().isNotEmpty)
              ..._buildContentWidgets(
                context: context,
                ref: ref,
                note: currentNote,
                headingsByLine: headingsByLine,
                theme: theme,
                textColor: textColor,
                subtextColor: subtextColor,
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

  List<Widget> _buildContentWidgets({
    required BuildContext context,
    required WidgetRef ref,
    required Note note,
    required Map<int, _HeadingItem> headingsByLine,
    required ThemeData theme,
    required Color textColor,
    required Color subtextColor,
  }) {
    final widgets = <Widget>[];
    final lines = note.content.split('\n');
    final markdownBuffer = StringBuffer();

    void flushMarkdownBuffer() {
      final markdownText = markdownBuffer.toString().trimRight();
      markdownBuffer.clear();
      if (markdownText.trim().isEmpty) return;
      widgets.add(
        _buildMarkdownBody(
          context: context,
          data: markdownText,
          theme: theme,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
      );
      widgets.add(const SizedBox(height: 4));
    }

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      final headingMatch = RegExp(r'^\s*(#{1,6})\s+(.+?)\s*$').firstMatch(line);
      if (headingMatch != null) {
        flushMarkdownBuffer();
        final headingItem = headingsByLine[i];
        final level = headingItem?.level ?? headingMatch.group(1)!.length;
        final title = headingItem?.title ?? (headingMatch.group(2) ?? '').trim();
        final anchor = headingItem?.anchorKey ?? GlobalKey();

        widgets.add(
          _buildHeadingBlock(
            anchorKey: anchor,
            level: level,
            title: title,
            theme: theme,
            textColor: textColor,
          ),
        );
        widgets.add(const SizedBox(height: 8));
        i++;
        continue;
      }

      final toggleStart = RegExp(r'^\s*:::\s*toggle(?:\s+(.*))?\s*$', caseSensitive: false).firstMatch(line);
      if (toggleStart != null) {
        flushMarkdownBuffer();
        final title = (toggleStart.group(1) ?? 'Toggle').trim();
        i++;

        final bodyLines = <String>[];
        while (i < lines.length && !RegExp(r'^\s*:::\s*$').hasMatch(lines[i])) {
          bodyLines.add(lines[i]);
          i++;
        }
        if (i < lines.length && RegExp(r'^\s*:::\s*$').hasMatch(lines[i])) {
          i++;
        }

        widgets.add(
          _buildToggleBlock(
            context: context,
            title: title.isEmpty ? 'Toggle' : title,
            body: bodyLines.join('\n').trim(),
            theme: theme,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
        );
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final quoteMatch = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
      if (quoteMatch != null) {
        flushMarkdownBuffer();

        final quoteLines = <String>[];
        while (i < lines.length) {
          final m = RegExp(r'^\s*>\s?(.*)$').firstMatch(lines[i]);
          if (m == null) break;
          quoteLines.add((m.group(1) ?? '').trim());
          i++;
        }

        final quoteText = quoteLines.join(' ').trim();
        widgets.add(
          _buildQuoteBlock(
            text: quoteText,
            theme: theme,
            textColor: textColor,
          ),
        );
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final checklistMatch = RegExp(r'^(\s*)- \[( |x)\]\s(.*)$').firstMatch(line);
      if (checklistMatch != null) {
        flushMarkdownBuffer();
        final checked = checklistMatch.group(2) == 'x';
        final itemText = checklistMatch.group(3) ?? '';

        widgets.add(
          _buildChecklistTile(
            context: context,
            ref: ref,
            note: note,
            lineIndex: i,
            checked: checked,
            text: itemText,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
        );
        widgets.add(const SizedBox(height: 2));
        i++;
        continue;
      }

      markdownBuffer.writeln(line);
      i++;
    }

    flushMarkdownBuffer();
    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }
    return widgets;
  }

  Widget _buildHeadingBlock({
    required GlobalKey anchorKey,
    required int level,
    required String title,
    required ThemeData theme,
    required Color textColor,
  }) {
    final display = title.isEmpty ? 'Heading' : title;
    TextStyle style;
    Color bg;
    Color border;
    Color accent;
    EdgeInsets pad;

    if (level <= 1) {
      style = AppTypography.headingMedium.copyWith(color: textColor);
      bg = const Color(0xFFE6F0FF);
      border = const Color(0xFF91B5FF);
      accent = const Color(0xFF2F6FED);
      pad = const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    } else if (level == 2) {
      style = AppTypography.headingSmall.copyWith(color: textColor);
      bg = const Color(0xFFE8F7EF);
      border = const Color(0xFF8ECFA9);
      accent = const Color(0xFF228B5A);
      pad = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    } else {
      style = AppTypography.labelLarge.copyWith(color: textColor, fontWeight: FontWeight.w700);
      bg = const Color(0xFFFFF2E6);
      border = const Color(0xFFFFC38A);
      accent = const Color(0xFFE07A22);
      pad = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    }

    return Container(
      key: anchorKey,
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.75), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(display, style: style)),
        ],
      ),
    );
  }

  Widget _buildMarkdownBody({
    required BuildContext context,
    required String data,
    required ThemeData theme,
    required Color textColor,
    required Color subtextColor,
  }) {
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [_ColorTagSyntax(), _BgTagSyntax()],
      builders: {
        'color': _ColorTagBuilder(),
        'bg': _BgTagBuilder(),
      },
      onTapLink: (text, href, title) => _openLink(context, href),
      sizedImageBuilder: (config) => _buildMarkdownImage(
        config.uri,
        theme,
        width: config.width,
        height: config.height,
      ),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: AppTypography.noteContent.copyWith(
          color: textColor,
          fontSize: 16,
          height: 1.6,
        ),
        h1: AppTypography.headingMedium.copyWith(
          color: textColor,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
        h2: AppTypography.headingSmall.copyWith(
          color: textColor,
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.16),
        ),
        h3: AppTypography.labelLarge.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.16),
        ),
        a: AppTypography.noteContent.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        listBullet: AppTypography.noteContent.copyWith(color: textColor),
        blockquote: AppTypography.noteContent.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 4),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: subtextColor.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
        ),
        code: AppTypography.bodySmall.copyWith(
          fontFamily: 'monospace',
          color: textColor,
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        h1Padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        h2Padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        h3Padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  Widget _buildQuoteBlock({
    required String text,
    required ThemeData theme,
    required Color textColor,
  }) {
    final safeText = text.isEmpty ? 'Quote' : text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      child: Text(
        '"$safeText"',
        style: AppTypography.noteContent.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildChecklistTile({
    required BuildContext context,
    required WidgetRef ref,
    required Note note,
    required int lineIndex,
    required bool checked,
    required String text,
    required Color textColor,
    required Color subtextColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _toggleChecklistLine(context, ref, note, lineIndex, !checked),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Checkbox(
              value: checked,
              onChanged: (v) => _toggleChecklistLine(
                context,
                ref,
                note,
                lineIndex,
                v ?? false,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 4, bottom: 10),
              child: Text(
                text.trim().isEmpty ? 'Task' : text,
                style: AppTypography.noteContent.copyWith(
                  color: checked ? subtextColor : textColor,
                  fontSize: 16,
                  height: 1.45,
                  decoration: checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBlock({
    required BuildContext context,
    required String title,
    required String body,
    required ThemeData theme,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        collapsedIconColor: subtextColor,
        iconColor: theme.colorScheme.primary,
        title: Text(
          title,
          style: AppTypography.labelLarge.copyWith(color: textColor),
        ),
        children: [
          if (body.trim().isNotEmpty)
            _buildMarkdownBody(
              context: context,
              data: body,
              theme: theme,
              textColor: textColor,
              subtextColor: subtextColor,
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No content',
                style: AppTypography.bodySmall.copyWith(color: subtextColor),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleChecklistLine(
    BuildContext context,
    WidgetRef ref,
    Note note,
    int lineIndex,
    bool checked,
  ) async {
    try {
      final lines = note.content.split('\n');
      if (lineIndex < 0 || lineIndex >= lines.length) return;

      final match = RegExp(r'^(\s*)- \[( |x)\]\s(.*)$').firstMatch(lines[lineIndex]);
      if (match == null) return;

      final indent = match.group(1) ?? '';
      final body = match.group(3) ?? '';
      lines[lineIndex] = '$indent- [${checked ? 'x' : ' '}] $body';

      await ref.read(databaseProvider).updateNote(
            NotesCompanion(
              id: Value(note.id),
              content: Value(lines.join('\n')),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update checklist item')),
      );
    }
  }

  Widget _buildMarkdownImage(
    Uri uri,
    ThemeData theme, {
    double? width,
    double? height,
  }) {
    final imagePath = uri.toString();

    Widget imageWidget;
    if (!kIsWeb && uri.scheme == 'file') {
      imageWidget = Image.file(
        File(uri.toFilePath()),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenImage(theme),
      );
    } else {
      imageWidget = Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenImage(theme),
      );
    }

    final desiredHeight = height == null || height <= 0 ? 320.0 : height;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: desiredHeight,
            maxWidth: width ?? double.infinity,
          ),
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _brokenImage(ThemeData theme) {
    return Container(
      height: 140,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String? href) async {
    if (href == null || href.trim().isEmpty) return;
    final uri = Uri.tryParse(href.trim());
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open URL')),
      );
    }
  }

  List<_HeadingItem> _extractHeadings(String content) {
    final headings = <_HeadingItem>[];
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = RegExp(r'^\s*(#{1,6})\s+(.+?)\s*$').firstMatch(line);
      if (match == null) continue;
      final level = match.group(1)!.length;
      final title = match.group(2)!.trim();
      if (title.isEmpty) continue;
      final anchorKey = _headingAnchors.putIfAbsent(i, () => GlobalKey());
      headings.add(
        _HeadingItem(
          level: level,
          title: title,
          lineIndex: i,
          anchorKey: anchorKey,
        ),
      );
    }
    return headings;
  }

  void _updateActiveHeadingByScroll() {
    if (!mounted) return;
    if (_currentHeadings.isEmpty) {
      if (_activeHeadingLineIndex != null) {
        setState(() => _activeHeadingLineIndex = null);
      }
      return;
    }

    final targetY = MediaQuery.of(context).padding.top + kToolbarHeight + 20;
    _HeadingItem? bestAbove;
    double bestAboveY = -double.infinity;
    _HeadingItem? bestBelow;
    double bestBelowY = double.infinity;

    for (final item in _currentHeadings) {
      final itemContext = item.anchorKey.currentContext;
      if (itemContext == null) continue;
      final render = itemContext.findRenderObject();
      if (render is! RenderBox || !render.attached) continue;

      final y = render.localToGlobal(Offset.zero).dy;
      if (y <= targetY && y > bestAboveY) {
        bestAboveY = y;
        bestAbove = item;
      }
      if (y > targetY && y < bestBelowY) {
        bestBelowY = y;
        bestBelow = item;
      }
    }

    final selected = bestAbove ?? bestBelow;
    final selectedLine = selected?.lineIndex;
    if (selectedLine != _activeHeadingLineIndex) {
      setState(() => _activeHeadingLineIndex = selectedLine);
    }
  }

  Future<void> _jumpToHeading(_HeadingItem item) async {
    if (_activeHeadingLineIndex != item.lineIndex) {
      setState(() => _activeHeadingLineIndex = item.lineIndex);
    }
    final targetContext = item.anchorKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
    if (mounted) {
      _updateActiveHeadingByScroll();
    }
  }

  String _plainTextFromMarkdown(String markdown) {
    return markdown
        .replaceAll(RegExp(r'^\s*:::\s*toggle.*$', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*:::\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]+\)'), ' ')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+\[( |x)\]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^(\s*\|.*\|\s*)$', multiLine: true), '')
        .replaceAll(RegExp(r'(\*\*|__|\*|_|~~)'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();
  }

  void _copyPlainText(BuildContext context, Note note) {
    final plain = _plainTextFromMarkdown(note.content);
    Clipboard.setData(ClipboardData(text: plain));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plain text copied')),
    );
  }

  Future<void> _exportAsPdf(BuildContext context, Note note) async {
    try {
      final plainContent = _plainTextFromMarkdown(note.content);
      final document = pw.Document();

      document.addPage(
        pw.MultiPage(
          build: (ctx) => [
            pw.Text(
              note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim(),
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(note.updatedAt)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              plainContent.isEmpty ? 'Empty note' : plainContent,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 2),
            ),
          ],
        ),
      );

      final bytes = await document.save();
      final fileName = _buildPdfFileName(note);
      final savedPath = await _savePdfBytes(bytes, fileName);

      if (!context.mounted) return;
      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF export cancelled')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported: $savedPath')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  String _buildPdfFileName(Note note) {
    final raw = note.title.trim().isEmpty ? 'note' : note.title.trim();
    final sanitized = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${sanitized}_$stamp.pdf';
  }

  Future<String?> _savePdfBytes(Uint8List bytes, String fileName) async {
    try {
      final savedPath = await savePdfFile(bytes, fileName);
      if (savedPath != null && savedPath.trim().isNotEmpty) {
        return savedPath;
      }
    } catch (_) {
      // Ignore and fallback to app documents path below.
    }

    if (kIsWeb) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(appDir.path, 'exports'));
    if (!exportDir.existsSync()) {
      await exportDir.create(recursive: true);
    }

    final fallbackPath = p.join(exportDir.path, fileName);
    await File(fallbackPath).writeAsBytes(bytes, flush: true);
    return fallbackPath;
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