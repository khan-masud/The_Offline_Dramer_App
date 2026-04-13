import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late FocusNode _contentFocus;
  late FocusNode _titleFocus;
  String? _folder;
  int _colorIndex = 0;
  bool _isPinned = false;
  bool _hasChanges = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
    _contentFocus = FocusNode();
    _titleFocus = FocusNode();
    _folder = widget.note?.folder;
    _colorIndex = widget.note?.colorIndex ?? 0;
    _isPinned = widget.note?.isPinned ?? false;

    _titleCtrl.addListener(_onTextChanged);
    _contentCtrl.addListener(_onTextChanged);
    _titleFocus.addListener(_onFocusChanged);
    _contentFocus.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    _hasChanges = true;
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contentFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  String _plainTextFromMarkdown(String markdown) {
    return markdown
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]+\)'), ' ')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+\[( |x)\]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
        .replaceAll(RegExp(r'(\*\*|__|\*|_|~~|`{1,3})'), '')
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text;

    final plainContent = _plainTextFromMarkdown(content);
    final finalTitle = title.isEmpty && plainContent.isNotEmpty
        ? (plainContent.length > 40
            ? '${plainContent.substring(0, 40).trim()}...'
            : plainContent)
        : title;

    if (finalTitle.isEmpty && content.isEmpty) return; 

    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    if (isEditing) {
      await db.updateNote(NotesCompanion(
        id: Value(widget.note!.id),
        title: Value(finalTitle),
        content: Value(content),
        folder: Value(_folder),
        colorIndex: Value(_colorIndex),
        isPinned: Value(_isPinned),
        updatedAt: Value(now),
      ));
      ref.read(activityLogProvider.notifier).log(
        type: 'update',
        entityType: 'note',
        entityTitle: finalTitle,
      );
    } else {
      await db.addNote(NotesCompanion(
        title: Value(finalTitle),
        content: Value(content),
        folder: Value(_folder),
        colorIndex: Value(_colorIndex),
        isPinned: Value(_isPinned),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
      ref.read(activityLogProvider.notifier).log(
        type: 'add',
        entityType: 'note',
        entityTitle: finalTitle,
      );
    }
  }

  // Formatting helpers
  void _insertAtCursor(String snippet, {int? cursorOffset}) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;

    if (selection.start == -1 || selection.end == -1) {
      final newText = '$text$snippet';
      _contentCtrl.text = newText;
      _contentCtrl.selection = TextSelection.collapsed(
        offset: cursorOffset == null
            ? newText.length
            : (newText.length - snippet.length + cursorOffset).clamp(0, newText.length),
      );
      _contentFocus.requestFocus();
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final newText = text.replaceRange(start, end, snippet);
    _contentCtrl.text = newText;

    final nextOffset = cursorOffset == null
        ? start + snippet.length
        : (start + cursorOffset).clamp(0, newText.length);
    _contentCtrl.selection = TextSelection.collapsed(offset: nextOffset);
    _contentFocus.requestFocus();
  }

  void _toggleWrap(String wrapWith) {
    _toggleWrapPair(wrapWith, wrapWith);
  }

  void _toggleWrapPair(String prefix, String suffix) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;

    if (selection.start == -1) {
      _contentCtrl.text = '$text$prefix$suffix';
      _contentCtrl.selection =
          TextSelection.collapsed(offset: _contentCtrl.text.length - suffix.length);
    } else {
      final start = selection.start;
      final end = selection.end;
      final selectedText = text.substring(start, end);

      // If already wrapped, remove it. Otherwise add it.
      if (start >= prefix.length &&
          end <= text.length - suffix.length &&
          text.substring(start - prefix.length, start) == prefix &&
          text.substring(end, end + suffix.length) == suffix) {
        // Remove wrap
        final newText =
            text.replaceRange(start - prefix.length, end + suffix.length, selectedText);
        _contentCtrl.text = newText;
        _contentCtrl.selection = TextSelection(
          baseOffset: start - prefix.length,
          extentOffset: end - prefix.length,
        );
      } else {
        // Add wrap
        final newText = text.replaceRange(start, end, '$prefix$selectedText$suffix');
        _contentCtrl.text = newText;
        _contentCtrl.selection = TextSelection(
          baseOffset: start + prefix.length,
          extentOffset: end + prefix.length,
        );
      }
    }
    _contentFocus.requestFocus();
  }

  void _toggleLinePrefix(String prefix) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    
    // Find boundaries of the current line
    int cursor = selection.baseOffset == -1 ? text.length : selection.baseOffset;
    
    int lineStart = cursor;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    
    int lineEnd = cursor;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }
    
    final currentLine = text.substring(lineStart, lineEnd);
    
    String newText;
    int cursorOffset = 0;
    
    if (currentLine.startsWith(prefix)) {
      // Remove prefix
      newText = text.replaceRange(lineStart, lineStart + prefix.length, '');
      cursorOffset = -prefix.length;
    } else {
      // Remove other prefixes if exist to switch lists cleanly
      final RegExp otherPrefixes = RegExp(
        r'^(?:\s*- \[ \]\s|\s*- \[x\]\s|\s*-\s|\s*\d+\.\s|\s*>\s|\s*#{1,6}\s)',
      );
      final match = otherPrefixes.firstMatch(currentLine);
      
      if (match != null) {
         // Replace existing prefix
         final existingPrefix = match.group(0)!;
         final lineWithoutPrefix = currentLine.substring(existingPrefix.length);
         newText = text.replaceRange(lineStart, lineEnd, '$prefix$lineWithoutPrefix');
         cursorOffset = prefix.length - existingPrefix.length;
      } else {
         // Add new prefix
         newText = text.replaceRange(lineStart, lineStart, prefix);
         cursorOffset = prefix.length;
      }
    }
    
    _contentCtrl.text = newText;
    int newCursorPos = (cursor + cursorOffset).clamp(0, newText.length);
    _contentCtrl.selection = TextSelection.collapsed(offset: newCursorPos);
    _contentFocus.requestFocus();
  }

  void _insertHeading(int level) {
    _toggleLinePrefix('${'#' * level} ');
  }

  void _insertQuote() {
    _toggleLinePrefix('> ');
  }

  void _insertNumberedList() {
    _toggleLinePrefix('1. ');
  }

  void _insertHorizontalRule() {
    _insertAtCursor('\n---\n');
  }

  void _insertToggleList() {
    const template = '\n:::toggle Toggle title\nAdd collapsible content here\n:::\n';
    _insertAtCursor(template);
  }

  void _insertInlineCode() {
    _toggleWrap('`');
  }

  void _wrapSelectionWithTags(String openTag, String closeTag, {String fallback = 'text'}) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;

    if (selection.start < 0 || selection.end < 0 || selection.start > selection.end) {
      _insertAtCursor('$openTag$fallback$closeTag');
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final selected = start == end ? fallback : text.substring(start, end);
    final replacement = '$openTag$selected$closeTag';
    final newText = text.replaceRange(start, end, replacement);
    _contentCtrl.text = newText;
    _contentCtrl.selection = TextSelection(
      baseOffset: start + openTag.length,
      extentOffset: start + openTag.length + selected.length,
    );
    _contentFocus.requestFocus();
  }

  Future<void> _showTextColorPicker() async {
    const palette = <String>[
      '#111111', '#D32F2F', '#1976D2', '#2E7D32', '#F57C00', '#6A1B9A', '#00838F', '#5D4037'
    ];
    final picked = await _pickColorHex(palette, title: 'Text Color');
    if (picked == null) return;
    _wrapSelectionWithTags('[color=$picked]', '[/color]');
  }

  Future<void> _showBackgroundColorPicker() async {
    const palette = <String>[
      '#FFF59D', '#FFCCBC', '#C8E6C9', '#B3E5FC', '#D1C4E9', '#F8BBD0', '#CFD8DC', '#FFE0B2'
    ];
    final picked = await _pickColorHex(palette, title: 'Highlight Color');
    if (picked == null) return;
    _wrapSelectionWithTags('[bg=$picked]', '[/bg]');
  }

  Future<String?> _pickColorHex(List<String> palette, {required String title}) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.headingSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: palette.map((hex) {
                  final color = Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
                  return GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.4)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _insertCodeBlock() {
    const snippet = '\n```dart\n// your code\n```\n';
    _insertAtCursor(snippet, cursorOffset: 9);
  }

  Future<void> _insertLink() async {
    final selection = _contentCtrl.selection;
    final text = _contentCtrl.text;

    String selectedText = 'Link text';
    if (selection.start >= 0 &&
        selection.end >= 0 &&
        selection.start < selection.end &&
        selection.end <= text.length) {
      selectedText = text.substring(selection.start, selection.end).trim();
      if (selectedText.isEmpty) {
        selectedText = 'Link text';
      }
    }

    final labelCtrl = TextEditingController(text: selectedText);
    final urlCtrl = TextEditingController(text: 'https://');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Text'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final label = labelCtrl.text.trim().isEmpty ? 'Link text' : labelCtrl.text.trim();
    final url = urlCtrl.text.trim();
    if (url.isEmpty) return;

    _insertAtCursor('[$label]($url)');
  }

  void _toggleChecklistStateOnCurrentLine() {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    int cursor = selection.baseOffset == -1 ? text.length : selection.baseOffset;

    int lineStart = cursor;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    int lineEnd = cursor;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final currentLine = text.substring(lineStart, lineEnd);
    final match = RegExp(r'^(\s*)- \[( |x)\]\s(.*)$').firstMatch(currentLine);

    String newLine;
    if (match == null) {
      final trimmed = currentLine.trim();
      newLine = '- [ ] ${trimmed.isEmpty ? 'Task' : trimmed}';
    } else {
      final indent = match.group(1) ?? '';
      final state = match.group(2) ?? ' ';
      final body = match.group(3) ?? '';
      final nextState = state == 'x' ? ' ' : 'x';
      newLine = '$indent- [$nextState] $body';
    }

    final updated = text.replaceRange(lineStart, lineEnd, newLine);
    _contentCtrl.text = updated;
    _contentCtrl.selection = TextSelection.collapsed(
      offset: (lineStart + newLine.length).clamp(0, updated.length),
    );
    _contentFocus.requestFocus();
  }

  void _insertTable() {
    const tableTemplate =
        '\n| Column 1 | Column 2 | Column 3 |\n| --- | --- | --- |\n| Data | Data | Data |\n';
    _insertAtCursor(tableTemplate);
  }

  Future<void> _insertImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory(p.join(appDir.path, 'note_images'));
      if (!imageDir.existsSync()) {
        await imageDir.create(recursive: true);
      }

      final ext = p.extension(picked.path).trim().isEmpty
          ? '.jpg'
          : p.extension(picked.path).toLowerCase();
      final fileName = 'note_image_${DateTime.now().millisecondsSinceEpoch}$ext';
      final savedPath = p.join(imageDir.path, fileName);
        final bytes = await picked.readAsBytes();
        await File(savedPath).writeAsBytes(bytes, flush: true);

        final imageUri = Uri.file(savedPath).toString();
        _insertAtCursor('\n![Image]($imageUri)\n');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add image')),
      );
    }
  }

  void _showBlockPicker() {
    final actions = <({IconData icon, String title, VoidCallback onTap})>[
      (
        icon: Icons.title_rounded,
        title: 'Heading 1',
        onTap: () => _insertHeading(1),
      ),
      (
        icon: Icons.title_outlined,
        title: 'Heading 2',
        onTap: () => _insertHeading(2),
      ),
      (
        icon: Icons.text_fields_rounded,
        title: 'Heading 3',
        onTap: () => _insertHeading(3),
      ),
      (
        icon: Icons.check_box_outlined,
        title: 'Todo list',
        onTap: () => _toggleLinePrefix('- [ ] '),
      ),
      (
        icon: Icons.task_alt_rounded,
        title: 'Toggle task checked/unchecked',
        onTap: _toggleChecklistStateOnCurrentLine,
      ),
      (
        icon: Icons.format_list_bulleted_rounded,
        title: 'Bullet list',
        onTap: () => _toggleLinePrefix('- '),
      ),
      (
        icon: Icons.format_list_numbered_rounded,
        title: 'Numbered list',
        onTap: _insertNumberedList,
      ),
      (
        icon: Icons.format_quote_rounded,
        title: 'Quote',
        onTap: _insertQuote,
      ),
      (
        icon: Icons.horizontal_rule_rounded,
        title: 'Divider',
        onTap: _insertHorizontalRule,
      ),
      (
        icon: Icons.table_chart_outlined,
        title: 'Table',
        onTap: _insertTable,
      ),
      (
        icon: Icons.link_rounded,
        title: 'URL Link',
        onTap: _insertLink,
      ),
      (
        icon: Icons.format_color_text_rounded,
        title: 'Text color',
        onTap: _showTextColorPicker,
      ),
      (
        icon: Icons.format_color_fill_rounded,
        title: 'Text background',
        onTap: _showBackgroundColorPicker,
      ),
      (
        icon: Icons.code_rounded,
        title: 'Code block',
        onTap: _insertCodeBlock,
      ),
      (
        icon: Icons.expand_rounded,
        title: 'Toggle list',
        onTap: _insertToggleList,
      ),
      (
        icon: Icons.image_outlined,
        title: 'Image',
        onTap: () {
          _insertImage();
        },
      ),
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: actions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final action = actions[index];
            return ListTile(
              leading: Icon(action.icon),
              title: Text(action.title),
              onTap: () {
                Navigator.of(ctx).pop();
                action.onTap();
              },
            );
          },
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? _noteColorsDark : _noteColors;
    return _colorIndex < colors.length ? colors[_colorIndex] : Theme.of(context).scaffoldBackgroundColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = _getBackgroundColor();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && _hasChanges) {
          await _save();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: _isPinned ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
              onPressed: () => setState(() { _isPinned = !_isPinned; _hasChanges = true; }),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _titleFocus.hasFocus
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : theme.colorScheme.outline.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _titleCtrl,
                        focusNode: _titleFocus,
                        style: AppTypography.noteTitle.copyWith(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Title',
                          hintStyle: AppTypography.noteTitle.copyWith(color: Colors.black45),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      constraints: const BoxConstraints(minHeight: 340),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _contentFocus.hasFocus
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : theme.colorScheme.outline.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _contentCtrl,
                        focusNode: _contentFocus,
                        autofocus: !isEditing,
                        style: AppTypography.noteContent.copyWith(
                          color: Colors.black87,
                          height: 1.55,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write your note...',
                          hintStyle: AppTypography.noteContent.copyWith(color: Colors.black45),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Toolbar (Google Keep style)
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, -3))
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                    children: [
                      // Add formatting
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        tooltip: 'Add block',
                        onPressed: _showBlockPicker,
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_box_outlined),
                        tooltip: 'Checkbox',
                        onPressed: () => _toggleLinePrefix('- [ ] '),
                      ),
                      IconButton(
                        icon: const Icon(Icons.task_alt_rounded),
                        tooltip: 'Toggle checked state',
                        onPressed: _toggleChecklistStateOnCurrentLine,
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted_rounded),
                        tooltip: 'Bullet List',
                        onPressed: () => _toggleLinePrefix('- '),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_list_numbered_rounded),
                        tooltip: 'Numbered List',
                        onPressed: _insertNumberedList,
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_bold_rounded),
                        tooltip: 'Bold',
                        onPressed: () => _toggleWrap('**'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_italic_rounded),
                        tooltip: 'Italic',
                        onPressed: () => _toggleWrap('*'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_strikethrough_rounded),
                        tooltip: 'Strikethrough',
                        onPressed: () => _toggleWrap('~~'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.title_rounded),
                        tooltip: 'Heading 1',
                        onPressed: () => _insertHeading(1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_quote_rounded),
                        tooltip: 'Quote',
                        onPressed: _insertQuote,
                      ),
                      IconButton(
                        icon: const Icon(Icons.horizontal_rule_rounded),
                        tooltip: 'Divider',
                        onPressed: _insertHorizontalRule,
                      ),
                      IconButton(
                        icon: const Icon(Icons.link_rounded),
                        tooltip: 'Insert URL',
                        onPressed: _insertLink,
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_color_text_rounded),
                        tooltip: 'Text color',
                        onPressed: _showTextColorPicker,
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_color_fill_rounded),
                        tooltip: 'Text background',
                        onPressed: _showBackgroundColorPicker,
                      ),
                      IconButton(
                        icon: const Icon(Icons.code_rounded),
                        tooltip: 'Code block',
                        onPressed: _insertCodeBlock,
                      ),
                      IconButton(
                        icon: const Icon(Icons.code_off_rounded),
                        tooltip: 'Inline code',
                        onPressed: _insertInlineCode,
                      ),
                      IconButton(
                        icon: const Icon(Icons.expand_rounded),
                        tooltip: 'Toggle list',
                        onPressed: _insertToggleList,
                      ),
                      IconButton(
                        icon: const Icon(Icons.table_chart_outlined),
                        tooltip: 'Table',
                        onPressed: _insertTable,
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_outlined),
                        tooltip: 'Image',
                        onPressed: _insertImage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined),
                        tooltip: 'Color',
                        onPressed: _showColorPicker,
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _folder ?? 'No folder',
                          style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_outlined),
                        tooltip: 'Folder',
                        onPressed: _showFolderPicker,
                      ),
                    ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? _noteColorsDark : _noteColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('Color', style: AppTypography.headingSmall),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: colors.asMap().entries.map((e) {
                    final isActive = _colorIndex == e.key;
                    final isDefault = e.key == 0;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() { _colorIndex = e.key; _hasChanges = true; });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: isDefault ? theme.scaffoldBackgroundColor : e.value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive ? AppColors.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
                            width: isActive ? 3 : 1,
                          ),
                        ),
                        child: isActive 
                            ? Icon(Icons.check, size: 24, color: isDefault ? theme.colorScheme.onSurface : Colors.black87) 
                            : (isDefault ? Icon(Icons.format_color_reset_outlined, color: theme.colorScheme.onSurfaceVariant) : null),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderPicker() {
    final TextEditingController newFolderCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Assign Folder', style: AppTypography.headingSmall),
              const SizedBox(height: 16),
              TextField(
                controller: newFolderCtrl,
                decoration: const InputDecoration(
                  hintText: 'New folder name...',
                  prefixIcon: Icon(Icons.create_new_folder_outlined),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    setState(() { _folder = val.trim(); _hasChanges = true; });
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() { _folder = null; _hasChanges = true; });
                  Navigator.pop(ctx);
                },
                child: const Text('Clear Folder'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Keep-style colors
const _noteColors = [
  Colors.transparent, // 0 = default
  Color(0xFFF28B82), // 1 = red
  Color(0xFFFBBC04), // 2 = orange
  Color(0xFFFFF475), // 3 = yellow
  Color(0xFFCCFF90), // 4 = green
  Color(0xFFA7FFEB), // 5 = teal
  Color(0xFFCBF0F8), // 6 = blue
  Color(0xFFAECBFA), // 7 = dark blue
  Color(0xFFD7AEFB), // 8 = purple
  Color(0xFFFDCFE8), // 9 = pink
  Color(0xFFE6C9A8), // 10 = brown
  Color(0xFFE8EAED), // 11 = grey
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
