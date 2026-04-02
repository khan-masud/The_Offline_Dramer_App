import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

class MarkdownTextController extends TextEditingController {
  MarkdownTextController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    List<TextSpan> children = [];
    final text = this.text;
    
    // Light regex to detect: **bold**, *italic*, - [ ], - [x], - bullet
    final RegExp pattern = RegExp(
      r'(\*\*.*?\*\*)|(\*.*?\*)|(^ *- \[ \])|(^ *- \[x\])|(^ *- )',
      multiLine: true,
    );
    
    int lastMatchEnd = 0;
    final matches = pattern.allMatches(text);
    
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: style));
      }
      
      final matchedText = match.group(0)!;
      TextStyle spanStyle = style ?? const TextStyle();
      
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
      } else if (matchedText.contains('- [ ]')) {
        spanStyle = spanStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold);
      } else if (matchedText.contains('- [x]')) {
        spanStyle = spanStyle.copyWith(color: AppColors.success, decoration: TextDecoration.lineThrough);
      } else if (matchedText.endsWith('- ')) {
        spanStyle = spanStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold);
      }
      
      children.add(TextSpan(text: matchedText, style: spanStyle));
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }
    
    return TextSpan(style: style, children: children);
  }
}

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late MarkdownTextController _contentCtrl;
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
    _contentCtrl = MarkdownTextController(text: widget.note?.content ?? '');
    _contentFocus = FocusNode();
    _titleFocus = FocusNode();
    _folder = widget.note?.folder;
    _colorIndex = widget.note?.colorIndex ?? 0;
    _isPinned = widget.note?.isPinned ?? false;

    _titleCtrl.addListener(_onChanged);
    _contentCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _hasChanges = true);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contentFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text;
    
    final finalTitle = title.isEmpty && content.isNotEmpty 
        ? (content.length > 20 ? '${content.substring(0, 20)}...' : content.split('\n').first)
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
    }
  }

  // Formatting helpers
  void _toggleWrap(String wrapWith) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    
    if (selection.start == -1) {
      _contentCtrl.text = '$text$wrapWith$wrapWith';
      _contentCtrl.selection = TextSelection.collapsed(offset: _contentCtrl.text.length - wrapWith.length);
    } else {
      final start = selection.start;
      final end = selection.end;
      final selectedText = text.substring(start, end);
      
      // If already wrapped, remove it. Otherwise add it.
      if (start >= wrapWith.length && end <= text.length - wrapWith.length &&
          text.substring(start - wrapWith.length, start) == wrapWith &&
          text.substring(end, end + wrapWith.length) == wrapWith) {
        
        // Remove wrap
        final newText = text.replaceRange(start - wrapWith.length, end + wrapWith.length, selectedText);
        _contentCtrl.text = newText;
        _contentCtrl.selection = TextSelection(baseOffset: start - wrapWith.length, extentOffset: end - wrapWith.length);
      } else {
        // Add wrap
        final newText = text.replaceRange(start, end, '$wrapWith$selectedText$wrapWith');
        _contentCtrl.text = newText;
        _contentCtrl.selection = TextSelection(baseOffset: start + wrapWith.length, extentOffset: end + wrapWith.length);
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
      final RegExp otherPrefixes = RegExp(r'^( *- \[ \] | *- \[x\] | *- )');
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextField(
                      controller: _titleCtrl,
                      focusNode: _titleFocus,
                      style: AppTypography.noteTitle.copyWith(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: AppTypography.noteTitle.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    // Content
                    TextField(
                      controller: _contentCtrl,
                      focusNode: _contentFocus,
                      autofocus: !isEditing,
                      style: AppTypography.noteContent.copyWith(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Note',
                        hintStyle: AppTypography.noteContent.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 100), // padding for keyboard/bottom bar
                  ],
                ),
              ),
            ),
            // Bottom Toolbar (Google Keep style)
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      // Add formatting
                      IconButton(
                        icon: const Icon(Icons.check_box_outlined),
                        tooltip: 'Checkbox',
                        onPressed: () => _toggleLinePrefix('- [ ] '),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted_rounded),
                        tooltip: 'Bullet List',
                        onPressed: () => _toggleLinePrefix('- '),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_bold_rounded),
                        tooltip: 'Bold',
                        onPressed: () => _toggleWrap('**'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined),
                        tooltip: 'Color',
                        onPressed: _showColorPicker,
                      ),
                      Expanded(
                        child: Text(
                          _folder ?? 'No folder',
                          textAlign: TextAlign.center,
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
