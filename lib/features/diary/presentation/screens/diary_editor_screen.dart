import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/activity_log_provider.dart';
import '../../data/diary_provider.dart';

class DiaryEditorScreen extends ConsumerStatefulWidget {
  final DiaryEntry? entry;
  final DateTime? initialDate;

  const DiaryEditorScreen({
    super.key,
    this.entry,
    this.initialDate,
  });

  @override
  ConsumerState<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends ConsumerState<DiaryEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _tagsCtrl;
  late FocusNode _contentFocus;
  late FocusNode _titleFocus;

  late DateTime _selectedDate;
  bool _isFavorite = false;
  bool _isLocked = false;
  bool _hasChanges = false;
  bool _isPreviewMode = false;

  bool get isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _selectedDate = entry?.date ?? widget.initialDate ?? DateTime.now();
    _titleCtrl = TextEditingController(text: entry?.title ?? '');
    _contentCtrl = TextEditingController(text: entry?.content ?? '');
    _locationCtrl = TextEditingController(text: entry?.location ?? '');
    _tagsCtrl = TextEditingController(text: entry?.tags ?? '');
    _isFavorite = entry?.isFavorite ?? false;
    _isLocked = entry?.isLocked ?? false;

    _contentFocus = FocusNode();
    _titleFocus = FocusNode();

    _titleCtrl.addListener(_onTextChanged);
    _contentCtrl.addListener(_onTextChanged);
    _locationCtrl.addListener(_onTextChanged);
    _tagsCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _hasChanges = true;
    setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _locationCtrl.dispose();
    _tagsCtrl.dispose();
    _contentFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  // ── Save Entry ──
  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final tags = _tagsCtrl.text.trim();

    if (content.isEmpty && title.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final dateNormalized = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final count = _wordCount;

    if (isEditing) {
      await db.updateDiaryEntry(
        DiaryEntriesCompanion(
          id: Value(widget.entry!.id),
          date: Value(dateNormalized),
          title: Value(title.isEmpty ? null : title),
          content: Value(content),
          weather: const Value(null),
          location: Value(location.isEmpty ? null : location),
          tags: Value(tags.isEmpty ? null : tags),
          isFavorite: Value(_isFavorite),
          isLocked: Value(_isLocked),
          wordCount: Value(count),
          updatedAt: Value(now),
        ),
      );
      ref.read(activityLogProvider.notifier).log(
            type: 'update',
            entityType: 'journal',
            entityTitle: title.isNotEmpty ? title : 'Journal entry for ${DateFormat('MMM d').format(dateNormalized)}',
          );
    } else {
      await db.addDiaryEntry(
        DiaryEntriesCompanion(
          date: Value(dateNormalized),
          title: Value(title.isEmpty ? null : title),
          content: Value(content),
          weather: const Value(null),
          location: Value(location.isEmpty ? null : location),
          tags: Value(tags.isEmpty ? null : tags),
          isFavorite: Value(_isFavorite),
          isLocked: Value(_isLocked),
          wordCount: Value(count),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      ref.read(activityLogProvider.notifier).log(
            type: 'add',
            entityType: 'journal',
            entityTitle: title.isNotEmpty ? title : 'Journal entry for ${DateFormat('MMM d').format(dateNormalized)}',
          );
    }

    ref.invalidate(diaryEntriesProvider);
    ref.invalidate(diaryStreakProvider);
    ref.invalidate(diaryStatsProvider);

    if (mounted) Navigator.pop(context);
  }

  // ── Markdown Formatting Helpers (Reused from Notes Engine) ──
  void _insertAtCursor(String snippet, {int? cursorOffset}) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;

    if (selection.start == -1 || selection.end == -1) {
      final newText = '$text$snippet';
      _contentCtrl.text = newText;
      _contentCtrl.selection = TextSelection.collapsed(
        offset: cursorOffset == null ? newText.length : (newText.length - snippet.length + cursorOffset).clamp(0, newText.length),
      );
      _contentFocus.requestFocus();
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final newText = text.replaceRange(start, end, snippet);
    _contentCtrl.text = newText;

    final nextOffset = cursorOffset == null ? start + snippet.length : (start + cursorOffset).clamp(0, newText.length);
    _contentCtrl.selection = TextSelection.collapsed(offset: nextOffset);
    _contentFocus.requestFocus();
  }

  void _toggleWrapPair(String prefix, String suffix) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;

    if (selection.start == -1) {
      _contentCtrl.text = '$text$prefix$suffix';
      _contentCtrl.selection = TextSelection.collapsed(offset: _contentCtrl.text.length - suffix.length);
    } else {
      final start = selection.start;
      final end = selection.end;
      final selectedText = text.substring(start, end);

      if (start >= prefix.length &&
          end <= text.length - suffix.length &&
          text.substring(start - prefix.length, start) == prefix &&
          text.substring(end, end + suffix.length) == suffix) {
        final newText = text.replaceRange(start - prefix.length, end + suffix.length, selectedText);
        _contentCtrl.text = newText;
        _contentCtrl.selection = TextSelection(
          baseOffset: start - prefix.length,
          extentOffset: end - prefix.length,
        );
      } else {
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

    if (currentLine.startsWith(prefix)) {
      newText = text.replaceRange(lineStart, lineStart + prefix.length, '');
    } else {
      final RegExp otherPrefixes = RegExp(r'^(?:\s*- \[ \]\s|\s*- \[x\]\s|\s*-\s|\s*\d+\.\s|\s*>\s|\s*#{1,6}\s)');
      final match = otherPrefixes.firstMatch(currentLine);
      if (match != null) {
        newText = text.replaceRange(lineStart, lineStart + match.group(0)!.length, prefix);
      } else {
        newText = text.replaceRange(lineStart, lineStart, prefix);
      }
    }

    _contentCtrl.text = newText;
    _contentCtrl.selection = TextSelection.collapsed(offset: (lineStart + prefix.length).clamp(0, newText.length));
    _contentFocus.requestFocus();
  }

  // ── Template Inserter ──
  void _applyTemplate(String type) {
    String templateContent = '';
    switch (type) {
      case 'standup':
        templateContent = '### Top Priorities for Today\n- [ ] Priority 1\n- [ ] Priority 2\n- [ ] Priority 3\n\n### Key Meetings & Commitments\n- \n\n### Potential Blockers & Mitigation\n- \n';
        if (_titleCtrl.text.isEmpty) _titleCtrl.text = 'Daily Standup & Focus';
        break;
      case 'evening_review':
        templateContent = '### Key Accomplishments & Wins\n- \n\n### Critical Learnings & Observations\n- \n\n### Tomorrow\'s Primary Strategic Intentions\n- \n';
        if (_titleCtrl.text.isEmpty) _titleCtrl.text = 'Evening Review & Wins';
        break;
      case 'strategy':
        templateContent = '### Context & Problem Statement\n- \n\n### Core Insights & Strategy\n- \n\n### Immediate Action Plan\n- [ ] Action item 1\n- [ ] Action item 2\n';
        if (_titleCtrl.text.isEmpty) _titleCtrl.text = 'Strategic Overview & Notes';
        break;
      case 'freeform':
        templateContent = '';
        break;
    }

    if (_contentCtrl.text.isEmpty) {
      _contentCtrl.text = templateContent;
    } else {
      _contentCtrl.text = '${_contentCtrl.text}\n\n$templateContent';
    }
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Insert Executive Template', style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary),
              title: const Text('Daily Standup & Focus Plan', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Top priorities, meetings, and anticipated blockers'),
              onTap: () {
                Navigator.pop(ctx);
                _applyTemplate('standup');
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined, color: AppColors.warning),
              title: const Text('Evening Review & Wins', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Accomplishments, key learnings, and next day intentions'),
              onTap: () {
                Navigator.pop(ctx);
                _applyTemplate('evening_review');
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.purple),
              title: const Text('Strategy & Idea Memo', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Context, solutions, and immediate execution steps'),
              onTap: () {
                Navigator.pop(ctx);
                _applyTemplate('strategy');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (_hasChanges) {
          _save();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Diary Entry' : 'New Diary Entry'),
          actions: [
            // Preview Toggle Button
            IconButton(
              icon: Icon(_isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_outlined),
              tooltip: _isPreviewMode ? 'Edit Mode' : 'Preview Format',
              onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
            ),
            // Template Inserter
            IconButton(
              icon: const Icon(Icons.dashboard_customize_outlined),
              tooltip: 'Templates',
              onPressed: _showTemplatePicker,
            ),
            // Privacy Lock
            IconButton(
              icon: Icon(
                _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: _isLocked ? AppColors.error : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: _isLocked ? 'Protected Entry' : 'Lock Entry',
              onPressed: () => setState(() => _isLocked = !_isLocked),
            ),
            // Favorite Bookmark
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _isFavorite ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Bookmark Entry',
              onPressed: () => setState(() => _isFavorite = !_isFavorite),
            ),
            // Save Button
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppColors.primary, size: 26),
              tooltip: 'Save Diary Entry',
              onPressed: _save,
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Metadata Bar: Date Picker + Weather + Location + Tags ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Date Selector Pill
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                                style: AppTypography.labelSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Spacer(),

                      // Word count & Reading time indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_wordCount words',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location & Tags Inputs Row
                  Row(
                    children: [
                      // Location
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 34,
                          child: TextField(
                            controller: _locationCtrl,
                            style: AppTypography.bodySmall,
                            decoration: InputDecoration(
                              hintText: 'Location (e.g. Headquarters, Home)',
                              hintStyle: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                              prefixIcon: const Icon(Icons.location_on_outlined, size: 15),
                              prefixIconConstraints: const BoxConstraints(minWidth: 28),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tags
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 34,
                          child: TextField(
                            controller: _tagsCtrl,
                            style: AppTypography.bodySmall,
                            decoration: InputDecoration(
                              hintText: 'Tags (e.g. strategy, personal)',
                              hintStyle: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                              prefixIcon: const Icon(Icons.tag_rounded, size: 15),
                              prefixIconConstraints: const BoxConstraints(minWidth: 28),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Diary Canvas / Preview Mode ──
            Expanded(
              child: _isPreviewMode
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_titleCtrl.text.isNotEmpty) ...[
                            Text(
                              _titleCtrl.text,
                              style: AppTypography.headingMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                          ],
                          MarkdownBody(
                            data: _contentCtrl.text.isEmpty ? '*No content written yet...*' : _contentCtrl.text,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                              p: AppTypography.bodyMedium.copyWith(
                                height: 1.6,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                              h1: AppTypography.headingLarge.copyWith(fontWeight: FontWeight.bold),
                              h2: AppTypography.headingMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title Input
                          TextField(
                            controller: _titleCtrl,
                            focusNode: _titleFocus,
                            style: AppTypography.headingMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Diary Title (e.g. A memorable day in Dhaka)',
                              hintStyle: AppTypography.headingMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            maxLines: 2,
                          ),
                          const Divider(height: 20),

                          // Markdown Content Input
                          TextField(
                            controller: _contentCtrl,
                            focusNode: _contentFocus,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            style: AppTypography.bodyMedium.copyWith(
                              height: 1.55,
                              color: theme.colorScheme.onSurface,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Dear Diary, today I...',
                              hintStyle: AppTypography.bodyMedium.copyWith(
                                height: 1.55,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // ── Rich Markdown Formatting Toolbar ──
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15))),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                physics: const BouncingScrollPhysics(),
                children: [
                  _ToolbarButton(icon: Icons.format_bold_rounded, tooltip: 'Bold', onTap: () => _toggleWrapPair('**', '**')),
                  _ToolbarButton(icon: Icons.format_italic_rounded, tooltip: 'Italic', onTap: () => _toggleWrapPair('*', '*')),
                  _ToolbarButton(icon: Icons.title_rounded, tooltip: 'Heading 1', onTap: () => _toggleLinePrefix('# ')),
                  _ToolbarButton(icon: Icons.format_size_rounded, tooltip: 'Heading 2', onTap: () => _toggleLinePrefix('## ')),
                  _ToolbarButton(icon: Icons.check_box_outlined, tooltip: 'Checklist', onTap: () => _toggleLinePrefix('- [ ] ')),
                  _ToolbarButton(icon: Icons.format_list_bulleted_rounded, tooltip: 'Bullet List', onTap: () => _toggleLinePrefix('- ')),
                  _ToolbarButton(icon: Icons.format_list_numbered_rounded, tooltip: 'Numbered List', onTap: () => _toggleLinePrefix('1. ')),
                  _ToolbarButton(icon: Icons.format_quote_rounded, tooltip: 'Quote', onTap: () => _toggleLinePrefix('> ')),
                  _ToolbarButton(icon: Icons.code_rounded, tooltip: 'Code', onTap: () => _toggleWrapPair('`', '`')),
                  _ToolbarButton(icon: Icons.horizontal_rule_rounded, tooltip: 'Divider', onTap: () => _insertAtCursor('\n---\n')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}
