import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/med_file.dart';
import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/topic_service.dart';
import '../utils/file_type_icon.dart';
import '../widgets/file_thumbnail.dart';
import '../widgets/edit_topic_sheet.dart';
import '../widgets/medical_emoji_picker.dart';
import 'file_properties_screen.dart';
import 'note_viewer_screen.dart';

class FileListScreen extends StatefulWidget {
  const FileListScreen({super.key, required this.topic});

  final Topic topic;

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<MedFile>> _filesFuture;
  List<MedFile> _cachedFiles = [];

  // Speed-dial state
  bool _fabOpen = false;
  late final AnimationController _fabAnimCtrl;
  late final Animation<double> _fabRotate;
  late final Animation<double> _fabFade;

  @override
  void initState() {
    super.initState();
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fabRotate = Tween<double>(begin: 0, end: 0.375)
        .animate(CurvedAnimation(parent: _fabAnimCtrl, curve: Curves.easeOut));
    _fabFade = CurvedAnimation(parent: _fabAnimCtrl, curve: Curves.easeOut);
    FileNotifier.instance.addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _filesFuture = _loadFiles().then((result) {
      if (mounted) setState(() => _cachedFiles = result);
      return result;
    });
    _debugPrintFiles();
  }

  @override
  void dispose() {
    FileNotifier.instance.removeListener(_refresh);
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  Future<List<MedFile>> _loadFiles() =>
      DatabaseService.instance.getFilesForTopic(widget.topic.id);

  Future<void> _debugPrintFiles() async {
    debugPrint('── FileListScreen opened for topicId: "${widget.topic.id}" ──');
    final all = await DatabaseService.instance.getAllFiles();
    debugPrint('  All files in DB (${all.length}):');
    for (final f in all) {
      debugPrint('    id=${f.id} name="${f.name}" topicId="${f.topicId}"');
    }
    final forTopic =
        await DatabaseService.instance.getFilesForTopic(widget.topic.id);
    debugPrint(
        '  Files for topicId "${widget.topic.id}": ${forTopic.length} found');
  }

  Future<void> _refresh() async {
    final next = _loadFiles();
    setState(() => _filesFuture = next);
    final result = await next;
    if (mounted) setState(() => _cachedFiles = result);
  }

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    _fabOpen ? _fabAnimCtrl.forward() : _fabAnimCtrl.reverse();
  }

  void _closeFab() {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      _fabAnimCtrl.reverse();
    }
  }

  // ─── New Subfolder ──────────────────────────────────────────────────────────

  Future<void> _showNewSubfolderSheet({Topic? parentOverride}) async {
    _closeFab();
    final parent = parentOverride ?? widget.topic;
    final ts = context.read<TopicService>();

    String selectedEmoji = '📁';
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showModalBottomSheet<Topic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurfaceVariant
                            .withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'New Subfolder in ${parent.emoji} ${parent.name}',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),

                  // Emoji + name row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmojiPickerButton(
                        emoji: selectedEmoji,
                        onChanged: (e) => setSheet(() => selectedEmoji = e),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: nameCtrl,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Folder name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Name required'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.of(ctx).pop(
                        // Return a pseudo-topic so caller knows what was made
                        Topic(
                          id: '',
                          name: nameCtrl.text.trim(),
                          emoji: selectedEmoji,
                          parentId: parent.id,
                        ),
                      );
                    },
                    child: const Text('Create Folder'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();

    if (created == null || !mounted) return;

    await ts.addTopic(
      name: created.name,
      parentId: created.parentId,
      emoji: created.emoji,
    );
    if (!mounted) return;
    setState(() {}); // rebuild subfolder row

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📁 "${created.name}" folder created!'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Ask if user wants to add another sub-subfolder inside the new one
    final newTopic = context.read<TopicService>().flatTopics.lastWhere(
          (t) => t.name == created.name && t.parentId == created.parentId,
          orElse: () => created,
        );

    final again = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Inside "${created.name}"?'),
        content:
            Text('Want to add a subfolder inside "${created.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Done'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, add more'),
          ),
        ],
      ),
    );
    if (again == true && mounted) {
      await _showNewSubfolderSheet(parentOverride: newTopic);
    }
  }

  // ─── Import File ──────────────────────────────────────────────────────────

  Future<void> _pickAndSaveFile() async {
    _closeFab();
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final src = result.files.single.path;
    if (src == null) return;

    final name = p.basenameWithoutExtension(src);
    final ext = p.extension(src);
    final fileType = MedFile.typeFromExtension(ext.replaceAll('.', ''));
    int fileSize = 0;
    try {
      fileSize = File(src).statSync().size;
    } catch (_) {}

    if (!mounted) return;

    final nameCtrl = TextEditingController(text: name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save File'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File Name'),
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
    nameCtrl.dispose();
    if (confirmed != true || !mounted) return;

    try {
      final medFile = await FileStorageService.instance.storeFile(
        sourcePath: src,
        topic: widget.topic,
        customName:
            nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : name,
      );
      await DatabaseService.instance.saveFile(
        medFile.copyWith(sizeBytes: fileSize, fileType: fileType),
      );
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${widget.topic.name} ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save file.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ─── AppBar ⋮ menu ─────────────────────────────────────────────────────────

  void _showFolderMenu(BuildContext ctx) {
    final ts = context.read<TopicService>();
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit Folder'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showEditFolderSheet(ts);
                },
              ),
              ListTile(
                leading: const Text('➕', style: TextStyle(fontSize: 20)),
                title: const Text('Add subfolder here'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showNewSubfolderSheet();
                },
              ),
              ListTile(
                leading: Text('🗑️',
                    style: TextStyle(fontSize: 20, color: cs.error)),
                title: Text('Delete this folder',
                    style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _confirmDeleteFolder(ts);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEditFolderSheet(TopicService ts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EditTopicSheet(
        topic: widget.topic,
        topicService: ts,
        onSaved: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _confirmDeleteFolder(TopicService ts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Delete "${widget.topic.name}" and ALL its contents?\n\n'
          'Files will be moved to Unsorted.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ts.deleteTopic(widget.topic.id);
    if (mounted) Navigator.of(context).pop();
  }

  // ─── File actions ──────────────────────────────────────────────────────────

  void _showFileActions(BuildContext context, MedFile file) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    getFileIcon(file),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        file.name,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  NoteViewerScreen.open(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('File Info'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) =>
                              FilePropertiesScreen(file: file)))
                      .then((deleted) {
                        if (!mounted) return;
                        if (deleted == true) {
                          setState(() {
                            _cachedFiles.removeWhere((f) => f.path == file.path);
                            _filesFuture =
                                Future.value(List<MedFile>.from(_cachedFiles));
                          });
                        } else {
                          _refresh();
                        }
                      });
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showRenameDialog(file);
                },
              ),
              ListTile(
                leading: Icon(file.isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded),
                title: Text(
                    file.isBookmarked ? 'Remove Bookmark' : 'Bookmark'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  final newValue = !file.isBookmarked;
                  final messenger = ScaffoldMessenger.of(context);
                  await DatabaseService.instance
                      .toggleBookmark(file.path, newValue);
                  _refresh();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(newValue
                          ? '🔖 Added to bookmarks'
                          : 'Removed from bookmarks'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_rounded),
                title: const Text('Move to Folder'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showMoveDialog(file);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_rounded, color: cs.error),
                title:
                    Text('Delete', style: TextStyle(color: cs.error)),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _confirmDelete(file);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(MedFile file) async {
    final ctrl = TextEditingController(text: file.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
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
    final newName = ctrl.text.trim();
    ctrl.dispose();
    if (confirmed == true && newName.isNotEmpty && newName != file.name) {
      await DatabaseService.instance.saveFile(file.copyWith(name: newName));
      _refresh();
    }
  }

  Future<void> _showMoveDialog(MedFile file) async {
    if (!mounted) return;
    final ts = context.read<TopicService>();
    final targets = ts.flatTopics.where((t) => t.id != file.topicId).toList();

    final picked = await showDialog<Topic>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Move to Folder'),
        children: targets
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(t),
                child: ListTile(
                  leading:
                      Text(t.emoji, style: const TextStyle(fontSize: 20)),
                  title: Text(t.name),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null || !mounted) return;

    try {
      final oldPath = file.path;
      final newPath =
          await FileStorageService.instance.moveFile(oldPath, picked.id);
      await DatabaseService.instance
          .moveFile(oldPath, picked.id, newPath: newPath);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to ${picked.name} ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to move file.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(MedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete File',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${file.name}"?\nThis cannot be undone.',
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
    await FileStorageService.instance.deleteFileFromStorage(file.path);

    // 2. Delete database record — primary: by path; secondary: by id.
    await DatabaseService.instance.deleteFile(file.path);
    if (file.id != null) {
      await DatabaseService.instance.deleteFileById(file.id!);
    }

    // 3. Instantly remove from local list — no reload needed.
    if (mounted) {
      setState(() {
        _cachedFiles.removeWhere((f) => f.path == file.path);
        _filesFuture = Future.value(List<MedFile>.from(_cachedFiles));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${file.name}" deleted'),
          backgroundColor: Colors.grey[800],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ts = context.watch<TopicService>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final breadcrumb = ts.getBreadcrumb(widget.topic.id);
    final subfolders = ts.getChildren(widget.topic.id);

    return GestureDetector(
      onTap: _closeFab, // tap anywhere to close speed dial
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.topic.emoji} ${widget.topic.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (breadcrumb.isNotEmpty)
                Text(
                  breadcrumb,
                  style: tt.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          toolbarHeight: 64,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Folder options',
              onPressed: () => _showFolderMenu(context),
            ),
          ],
        ),
        floatingActionButton: _buildSpeedDial(cs),
        body: FutureBuilder<List<MedFile>>(
          future: _filesFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final files = snap.data ?? [];

            if (subfolders.isEmpty && files.isEmpty) {
              return _EmptyState(onAddFile: _pickAndSaveFile);
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                children: [
                  // ── Subfolder row ─────────────────────────────────────
                  if (subfolders.isNotEmpty) ...[
                    _SectionLabel(label: 'SUBFOLDERS', tt: tt, cs: cs),
                    const SizedBox(height: 8),
                    _SubfolderRow(
                      subfolders: subfolders,
                      onTap: (child) {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => FileListScreen(topic: child)))
                            .then((_) { if (mounted) _refresh(); });
                      },
                      onAddNew: _showNewSubfolderSheet,
                      cs: cs,
                      tt: tt,
                    ),
                    const SizedBox(height: 16),
                    if (files.isNotEmpty) ...[
                      _SectionLabel(
                          label: 'FILES IN THIS FOLDER', tt: tt, cs: cs),
                      const SizedBox(height: 8),
                    ],
                  ],

                  // ── Files ─────────────────────────────────────────────
                  ...List.generate(files.length, (i) {
                    final file = files[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _FileTile(
                        file: file,
                        onTap: () => NoteViewerScreen.open(context, file),
                        onLongPress: () => _showFileActions(context, file),
                        onInfo: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) =>
                                    FilePropertiesScreen(file: file)))
                            .then((deleted) {
                              if (!mounted) return;
                              if (deleted == true) {
                                setState(() {
                                  _cachedFiles
                                      .removeWhere((f) => f.path == file.path);
                                  _filesFuture = Future.value(
                                      List<MedFile>.from(_cachedFiles));
                                });
                              } else {
                                _refresh();
                              }
                            }),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeedDial(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FABs (shown when open)
        FadeTransition(
          opacity: _fabFade,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniFab(
                label: 'New Subfolder',
                emoji: '📁',
                onTap: _showNewSubfolderSheet,
                cs: cs,
              ),
              const SizedBox(height: 12),
              _MiniFab(
                label: 'Import File',
                emoji: '📥',
                onTap: _pickAndSaveFile,
                cs: cs,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleFab,
          tooltip: 'Add',
          child: RotationTransition(
            turns: _fabRotate,
            child: Icon(_fabOpen ? Icons.close_rounded : Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

// ─── Mini FAB ─────────────────────────────────────────────────────────────────

class _MiniFab extends StatelessWidget {
  const _MiniFab({
    required this.label,
    required this.emoji,
    required this.onTap,
    required this.cs,
  });
  final String label;
  final String emoji;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          elevation: 1,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.tt,
    required this.cs,
  });
  final String label;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: tt.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

// ─── Subfolder Row ────────────────────────────────────────────────────────────

class _SubfolderRow extends StatelessWidget {
  const _SubfolderRow({
    required this.subfolders,
    required this.onTap,
    required this.onAddNew,
    required this.cs,
    required this.tt,
  });
  final List<Topic> subfolders;
  final void Function(Topic) onTap;
  final VoidCallback onAddNew;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 4),
        itemCount: subfolders.length + 1, // +1 for the "Add" chip
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          if (i < subfolders.length) {
            return _SubfolderCard(
              topic: subfolders[i],
              onTap: () => onTap(subfolders[i]),
              cs: cs,
              tt: tt,
            );
          }
          // "New subfolder" card
          return GestureDetector(
            onTap: onAddNew,
            child: Container(
              width: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: cs.outline.withAlpha(80),
                  width: 1.5,
                  // dashed borders aren't natively supported; solid is fine
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: cs.primary, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    'New',
                    style: tt.labelSmall?.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubfolderCard extends StatelessWidget {
  const _SubfolderCard({
    required this.topic,
    required this.onTap,
    required this.cs,
    required this.tt,
  });
  final Topic topic;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(topic.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              topic.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── File Tile ────────────────────────────────────────────────────────────────

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.onTap,
    required this.onLongPress,
    required this.onInfo,
  });

  final MedFile file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final tt        = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              FileThumbnail(file: file, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (file.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        file.description!,
                        style: tt.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '${file.formattedDate} · ${file.formattedSize}',
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (file.isBookmarked)
                    Icon(Icons.bookmark_rounded,
                        size: 16, color: cs.primary),
                  IconButton(
                    icon: Icon(Icons.info_outline_rounded,
                        size: 18, color: cs.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onInfo,
                    tooltip: 'File Info',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddFile});
  final VoidCallback onAddFile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📂', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No files here yet.',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Share any file from any app directly into MedShelf 📲\nor tap + to import.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Re-export kMedicalEmojis for other files that import this ────────────────
const kMedicalEmojis = [
  '📁', '🏥', '💊', '🩺', '🔬', '🧬', '🧪', '💉', '🩸', '🫁',
  '🧠', '❤️', '🦴', '👶', '🤰', '🚨', '🌡️', '🦷', '👁️', '🩹',
];
