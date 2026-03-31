import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _folderCtrl;
  int _colorIndex = 0;
  bool _isPinned = false;
  bool _hasChanges = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
    _folderCtrl = TextEditingController(text: widget.note?.folder ?? '');
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
    _folderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty'), backgroundColor: AppColors.error),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    if (isEditing) {
      await db.updateNote(NotesCompanion(
        id: Value(widget.note!.id),
        title: Value(_titleCtrl.text.trim()),
        content: Value(_contentCtrl.text),
        folder: Value(_folderCtrl.text.trim().isEmpty ? null : _folderCtrl.text.trim()),
        colorIndex: Value(_colorIndex),
        isPinned: Value(_isPinned),
        updatedAt: Value(now),
      ));
    } else {
      await db.addNote(NotesCompanion(
        title: Value(_titleCtrl.text.trim()),
        content: Value(_contentCtrl.text),
        folder: Value(_folderCtrl.text.trim().isEmpty ? null : _folderCtrl.text.trim()),
        colorIndex: Value(_colorIndex),
        isPinned: Value(_isPinned),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
    }

    if (mounted) Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges && _titleCtrl.text.trim().isNotEmpty) {
      await _save();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && _hasChanges && _titleCtrl.text.trim().isNotEmpty) {
          await _save();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Note' : 'New Note'),
          actions: [
            // Pin toggle
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: _isPinned ? AppColors.warning : null),
              onPressed: () => setState(() { _isPinned = !_isPinned; _hasChanges = true; }),
            ),
            // Color picker
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              onPressed: _showColorPicker,
            ),
            // Save
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: _save,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Folder
              TextField(
                controller: _folderCtrl,
                decoration: InputDecoration(
                  hintText: 'Folder (optional)',
                  prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 12),
              // Title
              TextField(
                controller: _titleCtrl,
                autofocus: !isEditing,
                decoration: InputDecoration(
                  hintText: 'Note title...',
                  border: InputBorder.none,
                  hintStyle: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
              ),
              const Divider(),
              // Content
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                    hintStyle: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker() {
    final colors = [
      (Colors.transparent, 'Default'),
      (const Color(0xFFFEF3C7), 'Yellow'),
      (const Color(0xFFDCFCE7), 'Green'),
      (const Color(0xFFDBEAFE), 'Blue'),
      (const Color(0xFFFCE7F3), 'Pink'),
      (const Color(0xFFF3E8FF), 'Purple'),
      (const Color(0xFFFFEDD5), 'Orange'),
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Note Color', style: AppTypography.headingSmall),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: colors.asMap().entries.map((e) {
                  final isActive = _colorIndex == e.key;
                  return GestureDetector(
                    onTap: () {
                      setState(() { _colorIndex = e.key; _hasChanges = true; });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: e.value.$1 == Colors.transparent
                            ? Theme.of(context).colorScheme.surface
                            : e.value.$1,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? AppColors.primary : Theme.of(context).colorScheme.outline,
                          width: isActive ? 3 : 1,
                        ),
                      ),
                      child: isActive ? const Icon(Icons.check, size: 20, color: AppColors.primary) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
