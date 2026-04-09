import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/med_file.dart';
import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/file_storage_service.dart';
import '../services/topic_service.dart';
import '../utils/app_colors.dart';
import '../widgets/topic_selector_widget.dart';
import 'note_viewer_screen.dart';

class FilePropertiesScreen extends StatefulWidget {
  const FilePropertiesScreen({super.key, required this.file});

  final MedFile file;

  @override
  State<FilePropertiesScreen> createState() => _FilePropertiesScreenState();
}

class _FilePropertiesScreenState extends State<FilePropertiesScreen> {
  late MedFile _file;

  @override
  void initState() {
    super.initState();
    _file = widget.file;
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _showRenameDialog() async {
    final isNote = _file.isNote;
    final ext = isNote ? '' : p.extension(_file.path);
    final displayName = isNote
        ? _file.name
        : p.basenameWithoutExtension(_file.path);

    final ctrl = TextEditingController(text: displayName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name',
            suffix: isNote ? null : Text(ext, style: const TextStyle(fontSize: 13)),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    );
    final newBase = ctrl.text.trim();
    ctrl.dispose();
    if (confirmed != true || newBase.isEmpty) return;

    try {
      final dir = p.dirname(_file.path);
      final newPath = p.join(dir, '$newBase$ext');
      await File(_file.path).rename(newPath);
      final updated = _file.copyWith(
        name: isNote ? newBase : '$newBase$ext',
        path: newPath,
      );
      await DatabaseService.instance.saveFile(updated);
      if (mounted) setState(() => _file = updated);
    } catch (_) {
      if (mounted) _showError('Failed to rename file.');
    }
  }

  Future<void> _showEditDescriptionDialog() async {
    final ctrl = TextEditingController(text: _file.description ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Description / Notes'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          minLines: 4,
          decoration: const InputDecoration(
            hintText: 'Add notes about this file...',
            alignLabelWithHint: true,
          ),
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    );
    final newDesc = ctrl.text.trim();
    ctrl.dispose();
    if (confirmed != true) return;

    final updated = _file.copyWith(
      description: newDesc.isEmpty ? null : newDesc,
    );
    await DatabaseService.instance.saveFile(updated);
    if (mounted) setState(() => _file = updated);
  }

  Future<void> _toggleBookmark(bool value) async {
    await DatabaseService.instance.toggleBookmark(_file.path, value);
    if (!mounted) return;
    setState(() => _file = _file.copyWith(isBookmarked: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? '🔖 Added to bookmarks' : 'Removed from bookmarks'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMoveSheet() {
    Topic? picked;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setStateSheet) {
          final cs = Theme.of(sheetCtx).colorScheme;
          final tt = Theme.of(sheetCtx).textTheme;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text('Move to Folder',
                      style: tt.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TopicSelectorWidget(
                          onChanged: (t) =>
                              setStateSheet(() => picked = t),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: picked == null
                              ? null
                              : () {
                                  Navigator.of(sheetCtx).pop();
                                  _doMove(picked!);
                                },
                          child: const Text('Move Here'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _doMove(Topic newTopic) async {
    try {
      final oldPath = _file.path;
      final newPath =
          await FileStorageService.instance.moveFile(oldPath, newTopic.id);
      // Update the DB record matched by the OLD path, setting both the new
      // topicId and new path in a single operation.
      await DatabaseService.instance
          .moveFile(oldPath, newTopic.id, newPath: newPath);
      final updated = _file.copyWith(topicId: newTopic.id, path: newPath);
      if (mounted) {
        setState(() => _file = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to ${newTopic.name} ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) _showError('Failed to move file.');
    }
  }

  void _copyPath() {
    Clipboard.setData(ClipboardData(text: _file.path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Path copied! ✓'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteFile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete File',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${_file.name}"?\nThis cannot be undone.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red[600]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 1. Delete physical file from storage.
    await FileStorageService.instance.deleteFileFromStorage(_file.path);

    // 2. Delete database record — primary: by path; secondary: by id.
    await DatabaseService.instance.deleteFile(_file.path);
    if (_file.id != null) {
      await DatabaseService.instance.deleteFileById(_file.id!);
    }

    // 3. Pop back — caller receives `true` and can refresh its own list.
    if (mounted) Navigator.of(context).pop(true);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ts = context.watch<TopicService>();
    final badgeColor = AppColors.getColorForFileType(_file.fileType);
    final breadcrumb = ts.getBreadcrumb(_file.topicId);
    final formattedDate =
        DateFormat('d MMMM yyyy, hh:mm a').format(_file.savedAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Info'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ──────────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _file.fileTypeIcon,
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _file.isNote
                          ? 'NOTE'
                          : _file.fileType.name.toUpperCase(),
                      style: tt.labelMedium?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Details card ──────────────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // File Name
                    _DetailRow(
                      emoji: '📄',
                      label: 'File Name',
                      value: _file.name,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: _showRenameDialog,
                        tooltip: 'Rename',
                      ),
                      cs: cs,
                      tt: tt,
                    ),
                    _divider(cs),

                    // Saved In
                    _DetailRow(
                      emoji: '📁',
                      label: 'Saved In',
                      value: breadcrumb.isNotEmpty
                          ? breadcrumb
                          : 'Unsorted',
                      onTap: _showMoveSheet,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      cs: cs,
                      tt: tt,
                    ),
                    _divider(cs),

                    // Date Saved
                    _DetailRow(
                      emoji: '📅',
                      label: 'Date Saved',
                      value: formattedDate,
                      cs: cs,
                      tt: tt,
                    ),
                    _divider(cs),

                    // File Size
                    _DetailRow(
                      emoji: '💾',
                      label: 'File Size',
                      value: _file.formattedSize,
                      cs: cs,
                      tt: tt,
                    ),
                    _divider(cs),

                    // File Type
                    _DetailRow(
                      emoji: '🏷️',
                      label: 'File Type',
                      value: _file.isNote
                          ? 'Clinical Note'
                          : switch (_file.fileType.name) {
                              'pdf' => 'PDF Document',
                              'image' => 'Image',
                              'video' => 'Video',
                              'document' => 'Document',
                              'audio' => 'Audio',
                              _ => _file.fileType.name.toUpperCase(),
                            },
                      cs: cs,
                      tt: tt,
                    ),
                    _divider(cs),

                    // Bookmarked
                    _BookmarkRow(
                      value: _file.isBookmarked,
                      onChanged: _toggleBookmark,
                      cs: cs,
                      tt: tt,
                    ),
                    _divider(cs),

                    // File Location
                    _DetailRow(
                      emoji: '📍',
                      label: 'File Location',
                      value: _file.path,
                      monospace: true,
                      onTap: _copyPath,
                      trailing: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      cs: cs,
                      tt: tt,
                    ),
                    _divider(cs),

                    // Description
                    _DetailRow(
                      emoji: '📝',
                      label: 'Description / Notes',
                      value: (_file.description?.isNotEmpty == true)
                          ? _file.description!
                          : 'Tap to add notes...',
                      valueColor:
                          (_file.description?.isNotEmpty == true)
                              ? null
                              : cs.onSurfaceVariant,
                      onTap: _showEditDescriptionDialog,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: _showEditDescriptionDialog,
                        tooltip: 'Edit description',
                      ),
                      cs: cs,
                      tt: tt,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Actions ───────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: () => NoteViewerScreen.open(context, _file),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open File'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _deleteFile,
              icon: Icon(Icons.delete_outline_rounded,
                  color: cs.error),
              label: Text('Delete File',
                  style: TextStyle(color: cs.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Divider(
        height: 1,
        color: cs.outlineVariant.withAlpha(100),
      );
}

// ─── Detail Row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
    this.trailing,
    this.onTap,
    this.monospace = false,
    this.valueColor,
  });

  final String emoji;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool monospace;
  final Color? valueColor;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: monospace
                        ? TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: valueColor ?? cs.onSurface,
                          )
                        : tt.bodyMedium?.copyWith(
                            color: valueColor,
                          ),
                    maxLines: monospace ? 3 : 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Bookmark Row ─────────────────────────────────────────────────────────────

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.value,
    required this.onChanged,
    required this.cs,
    required this.tt,
  });

  final bool value;
  final void Function(bool) onChanged;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Text('🔖', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bookmarked',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? 'Yes — appears in bookmarks' : 'No',
                  style: tt.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
