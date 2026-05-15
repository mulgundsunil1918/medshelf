import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/med_file.dart';
import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/topic_service.dart';
import '../utils/app_colors.dart';
import 'medical_emoji_picker.dart';
import 'topic_selector_widget.dart';

class SaveFileSheet extends StatefulWidget {
  const SaveFileSheet({super.key, required this.sourcePath});

  final String sourcePath;

  @override
  State<SaveFileSheet> createState() => _SaveFileSheetState();
}

class _SaveFileSheetState extends State<SaveFileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  Topic? _selectedTopic;
  bool _isBookmarked = false;
  bool _isSaving = false;

  /// When set, `TopicSelectorWidget` auto-selects this topic ID on rebuild.
  /// Paired with a `ValueKey` so the widget restarts fresh on each creation.
  String? _autoSelectTopicId;

  late final String _ext;
  late final FileType _fileType;
  late final int _fileSize;

  @override
  void initState() {
    super.initState();
    _ext = p.extension(widget.sourcePath);
    _fileType = MedFile.typeFromExtension(_ext.replaceAll('.', ''));
    _nameController = TextEditingController(
      text: p.basenameWithoutExtension(widget.sourcePath),
    );
    _descController = TextEditingController();
    _fileSize = _readFileSize();
  }

  int _readFileSize() {
    try {
      return File(widget.sourcePath).statSync().size;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ─── Save logic ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a file name.');
      return;
    }
    final topic = _selectedTopic;
    if (topic == null) {
      _showError('Please select a folder.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final medFile = await FileStorageService.instance.storeFile(
        sourcePath: widget.sourcePath,
        topic: topic,
        customName: name,
      );

      final desc = _descController.text.trim();
      final fileToSave = medFile.copyWith(
        isBookmarked: _isBookmarked,
        description: desc.isEmpty ? null : desc,
      );
      await DatabaseService.instance.saveFile(fileToSave);
      FileNotifier.instance.notifyFileChanged();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved to ${topic.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to save file.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  // ─── Quick-create launchers ───────────────────────────────────────────────

  void _onTopicCreated(Topic topic) {
    setState(() => _autoSelectTopicId = topic.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${topic.emoji} ${topic.name} created!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showNewSpecialtySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NewFolderSheet(
        title: 'New Specialty',
        label: 'Specialty name',
        parentId: null,
        onCreated: _onTopicCreated,
      ),
    );
  }

  void _showNewTopicSheet(TopicService ts) {
    // Pre-select the currently chosen specialty, if any.
    String? preselectedSpecialtyId;
    final sel = _selectedTopic;
    if (sel != null) {
      preselectedSpecialtyId = sel.parentId ?? sel.id;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NewChildSheet(
        title: 'New Topic',
        label: 'Topic name',
        dropdownLabel: 'Under Specialty',
        parents: ts.rootTopics,
        preselectedParentId: preselectedSpecialtyId,
        onCreated: _onTopicCreated,
      ),
    );
  }

  void _showNewSubtopicSheet(TopicService ts) {
    // Pre-select the currently chosen topic (if non-root), if any.
    String? preselectedTopicId;
    final sel = _selectedTopic;
    if (sel != null && sel.parentId != null) {
      preselectedTopicId = sel.id;
    }

    // All non-root topics as valid parents.
    final nonRootTopics =
        ts.flatTopics.where((t) => t.parentId != null).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NewChildSheet(
        title: 'New Subtopic',
        label: 'Subtopic name',
        dropdownLabel: 'Under Topic',
        parents: nonRootTopics,
        preselectedParentId: preselectedTopicId,
        showBreadcrumb: true,
        onCreated: _onTopicCreated,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
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
            child: Text(
              'Save to MedShelf 📥',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── File preview ────────────────────────────────────────
                  _FilePreviewCard(
                    fileType: _fileType,
                    sourcePath: widget.sourcePath,
                    fileSize: _fileSize,
                    ext: _ext,
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(height: 20),

                  // ── File name ───────────────────────────────────────────
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'File Name',
                      hintText: 'Enter a name for this file',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  // ── Description ─────────────────────────────────────────
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Add notes about this file...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: null,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 20),

                  // ── Folder selector ─────────────────────────────────────
                  // ValueKey forces a fresh widget (resets _didAutoSelect)
                  // every time a new folder is created.
                  TopicSelectorWidget(
                    key: ValueKey(_autoSelectTopicId ?? '__default__'),
                    initialTopicId: _autoSelectTopicId,
                    onChanged: (t) => setState(() => _selectedTopic = t),
                  ),

                  // ── Quick-create buttons ────────────────────────────────
                  const SizedBox(height: 12),
                  Consumer<TopicService>(
                    builder: (ctx, ts, _) {
                      final hasSpecialties = ts.rootTopics.isNotEmpty;
                      final hasNonRoot =
                          ts.flatTopics.any((t) => t.parentId != null);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _quickBtn(
                                cs,
                                '➕ Specialty',
                                _showNewSpecialtySheet,
                              ),
                              const SizedBox(width: 8),
                              _quickBtn(
                                cs,
                                '➕ Topic',
                                hasSpecialties
                                    ? () => _showNewTopicSheet(ts)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              _quickBtn(
                                cs,
                                '➕ Subtopic',
                                hasNonRoot
                                    ? () => _showNewSubtopicSheet(ts)
                                    : null,
                              ),
                            ],
                          ),
                          if (!hasSpecialties)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Create a Specialty first to add topics',
                                style: tt.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            )
                          else if (!hasNonRoot)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Create a Topic first to add subtopics',
                                style: tt.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Bookmark toggle ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🔖', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text('Bookmark this file', style: tt.bodyMedium),
                        ],
                      ),
                      Switch(
                        value: _isBookmarked,
                        onChanged: (v) => setState(() => _isBookmarked = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Save / Cancel ───────────────────────────────────────
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save File'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(ColorScheme cs, String label, VoidCallback? onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
        side: BorderSide(
          color: onTap != null
              ? cs.primary
              : cs.outline.withAlpha(80),
        ),
        foregroundColor: onTap != null
            ? cs.primary
            : cs.onSurface.withAlpha(80),
      ),
      child: Text(label),
    );
  }
}

// ─── New Specialty Sheet ──────────────────────────────────────────────────────

/// Sheet for creating a root-level specialty (no parent).
class _NewFolderSheet extends StatefulWidget {
  const _NewFolderSheet({
    required this.title,
    required this.label,
    required this.parentId,
    required this.onCreated,
  });

  final String title;
  final String label;
  final String? parentId;
  final void Function(Topic) onCreated;

  @override
  State<_NewFolderSheet> createState() => _NewFolderSheetState();
}

class _NewFolderSheetState extends State<_NewFolderSheet> {
  final _nameCtrl = TextEditingController();
  String _emoji = '📁';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    // Capture ts BEFORE setState to avoid _dependents.isEmpty crash
    final ts = context.read<TopicService>();
    setState(() => _saving = true);
    try {
      final newTopic = await ts.addTopic(
        name: name,
        emoji: _emoji,
        parentId: widget.parentId,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(newTopic);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
            child: Text(
              widget.title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Emoji picker
                Center(
                  child: EmojiPickerButton(
                    emoji: _emoji,
                    size: 80,
                    onChanged: (e) => setState(() => _emoji = e),
                  ),
                ),
                const SizedBox(height: 20),

                // Name field
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: 'e.g. Pediatrics',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: _nameCtrl.clear,
                    ),
                  ),
                  onSubmitted: (_) => _create(),
                ),
                const SizedBox(height: 24),

                // Live preview
                _LivePreview(emoji: _emoji, name: _nameCtrl, cs: cs, tt: tt),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _saving ? null : _create,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── New Topic / Subtopic Sheet ────────────────────────────────────────────────

/// Sheet for creating a child topic under a chosen parent from [parents].
class _NewChildSheet extends StatefulWidget {
  const _NewChildSheet({
    required this.title,
    required this.label,
    required this.dropdownLabel,
    required this.parents,
    required this.onCreated,
    this.preselectedParentId,
    this.showBreadcrumb = false,
  });

  final String title;
  final String label;
  final String dropdownLabel;
  final List<Topic> parents;
  final String? preselectedParentId;
  final bool showBreadcrumb;
  final void Function(Topic) onCreated;

  @override
  State<_NewChildSheet> createState() => _NewChildSheetState();
}

class _NewChildSheetState extends State<_NewChildSheet> {
  final _nameCtrl = TextEditingController();
  String _emoji = '📁';
  Topic? _selectedParent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-select the parent if provided and found in the list.
    if (widget.preselectedParentId != null) {
      _selectedParent = widget.parents
          .where((t) => t.id == widget.preselectedParentId)
          .firstOrNull;
    }
    _selectedParent ??=
        widget.parents.isNotEmpty ? widget.parents.first : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selectedParent == null) return;
    // Capture ts BEFORE setState to avoid _dependents.isEmpty crash
    final ts = context.read<TopicService>();
    setState(() => _saving = true);
    try {
      final newTopic = await ts.addTopic(
        name: name,
        emoji: _emoji,
        parentId: _selectedParent!.id,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(newTopic);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _parentLabel(Topic t) {
    if (!widget.showBreadcrumb) return '${t.emoji} ${t.name}';
    final ts = Provider.of<TopicService>(context, listen: false);
    final breadcrumb = ts.getBreadcrumb(t.id);
    return '${t.emoji} $breadcrumb';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
            child: Text(
              widget.title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Emoji picker
                  Center(
                    child: EmojiPickerButton(
                      emoji: _emoji,
                      size: 80,
                      onChanged: (e) => setState(() => _emoji = e),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Parent dropdown
                  Text(
                    widget.dropdownLabel,
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Topic>(
                    initialValue: _selectedParent,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    items: widget.parents.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(
                          _parentLabel(t),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (t) =>
                        setState(() => _selectedParent = t),
                  ),
                  const SizedBox(height: 16),

                  // Name field
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: widget.label,
                      hintText: 'e.g. Neonatology',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: _nameCtrl.clear,
                      ),
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                  const SizedBox(height: 24),

                  // Live preview
                  _LivePreview(
                      emoji: _emoji, name: _nameCtrl, cs: cs, tt: tt),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed:
                        (_saving || _selectedParent == null) ? null : _create,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Live Preview ─────────────────────────────────────────────────────────────

class _LivePreview extends StatefulWidget {
  const _LivePreview({
    required this.emoji,
    required this.name,
    required this.cs,
    required this.tt,
  });

  final String emoji;
  final TextEditingController name;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  State<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<_LivePreview> {
  @override
  void initState() {
    super.initState();
    widget.name.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.name.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final name = widget.name.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: widget.tt.labelSmall
              ?.copyWith(color: widget.cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(widget.emoji,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Folder name…' : name,
                  style: widget.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: name.isEmpty
                        ? widget.cs.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── File Preview Card ────────────────────────────────────────────────────────

class _FilePreviewCard extends StatelessWidget {
  const _FilePreviewCard({
    required this.fileType,
    required this.sourcePath,
    required this.fileSize,
    required this.ext,
    required this.cs,
    required this.tt,
  });

  final FileType fileType;
  final String sourcePath;
  final int fileSize;
  final String ext;
  final ColorScheme cs;
  final TextTheme tt;

  String get _typeLabel => fileType.name.toUpperCase();

  String _formatSize(int bytes) {
    if (bytes < 1024) { return '$bytes B'; }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fileTypeEmoji(FileType type) => switch (type) {
        FileType.pdf => '📄',
        FileType.image => '🖼️',
        FileType.video => '🎬',
        FileType.document => '📝',
        FileType.other => '📎',
      };

  @override
  Widget build(BuildContext context) {
    final badgeColor = AppColors.getColorForFileType(fileType);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _fileTypeEmoji(fileType),
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(sourcePath),
                  style: tt.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatSize(fileSize),
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _typeLabel,
              style: tt.labelSmall?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
