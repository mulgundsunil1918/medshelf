import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/med_file.dart';
import '../services/database_service.dart';
import '../services/file_storage_service.dart';
import '../services/topic_service.dart';
import '../utils/app_colors.dart';
import '../utils/file_type_icon.dart';
import '../utils/share_helper.dart';
import '../widgets/file_thumbnail.dart';
import '../widgets/save_file_sheet.dart';
import 'file_properties_screen.dart';
import 'note_viewer_screen.dart';

enum _SortMode {
  newestFirst,
  oldestFirst,
  nameAZ,
  nameZA,
  largestFirst,
  smallestFirst,
}

extension _SortModeLabel on _SortMode {
  String get label => switch (this) {
        _SortMode.newestFirst => 'Newest First',
        _SortMode.oldestFirst => 'Oldest First',
        _SortMode.nameAZ => 'Name A–Z',
        _SortMode.nameZA => 'Name Z–A',
        _SortMode.largestFirst => 'Largest First',
        _SortMode.smallestFirst => 'Smallest First',
      };
}

class AllFilesScreen extends StatefulWidget {
  const AllFilesScreen({super.key, this.showBookmarkedOnly = false});

  final bool showBookmarkedOnly;

  @override
  State<AllFilesScreen> createState() => _AllFilesScreenState();
}

class _AllFilesScreenState extends State<AllFilesScreen> {
  late Future<List<MedFile>> _dataFuture;
  List<MedFile> _cachedFiles = [];
  _SortMode _sortMode = _SortMode.newestFirst;
  FileType? _filterType; // null = all; used when showBookmarkedOnly=false
  bool _notesOnly = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData().then((result) {
      if (mounted) setState(() => _cachedFiles = result);
      return result;
    });
  }

  Future<List<MedFile>> _loadData() => widget.showBookmarkedOnly
      ? DatabaseService.instance.getBookmarkedFiles()
      : DatabaseService.instance.getAllFiles();

  Future<void> _refresh() async {
    final next = _loadData();
    setState(() => _dataFuture = next);
    final result = await next;
    if (mounted) setState(() => _cachedFiles = result);
  }

  List<MedFile> _applyFiltersAndSort(List<MedFile> raw) {
    var list = raw.toList();

    // Filter
    if (_notesOnly) {
      list = list.where((f) => f.isNote).toList();
    } else if (_filterType != null) {
      list = list.where((f) => f.fileType == _filterType).toList();
    }

    // Sort
    switch (_sortMode) {
      case _SortMode.newestFirst:
        list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      case _SortMode.oldestFirst:
        list.sort((a, b) => a.savedAt.compareTo(b.savedAt));
      case _SortMode.nameAZ:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.nameZA:
        list.sort((a, b) => b.name.compareTo(a.name));
      case _SortMode.largestFirst:
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case _SortMode.smallestFirst:
        list.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
    }

    return list;
  }

  void _setFilter(FileType? type) =>
      setState(() { _filterType = type; _notesOnly = false; });

  void _setNotesFilter() =>
      setState(() { _notesOnly = true; _filterType = null; });

  Future<void> _importDocuments() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(allowMultiple: false);
    } catch (_) {
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null || !mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SaveFileSheet(sourcePath: file.path!),
    );
    if (saved == true) await _refresh();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = context.watch<TopicService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showBookmarkedOnly ? 'Bookmarked Files 🔖' : 'All Files 📂',
        ),
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            initialValue: _sortMode,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (_) => _SortMode.values
                .map(
                  (m) => PopupMenuItem(
                    value: m,
                    child: Row(
                      children: [
                        if (m == _sortMode)
                          Icon(Icons.check_rounded, size: 18, color: cs.primary)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(m.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filterType == null && !_notesOnly,
                  onTap: () => _setFilter(null),
                  cs: cs,
                ),
                const SizedBox(width: 8),
                ...FileType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: type.name[0].toUpperCase() +
                          type.name.substring(1),
                      selected: _filterType == type && !_notesOnly,
                      onTap: () => _setFilter(type),
                      color: AppColors.getColorForFileType(type),
                      cs: cs,
                    ),
                  ),
                ),
                _FilterChip(
                  label: 'Notes',
                  selected: _notesOnly,
                  onTap: _setNotesFilter,
                  color: cs.tertiary,
                  cs: cs,
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<MedFile>>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final raw = snap.data ?? [];
          final files = _applyFiltersAndSort(raw);

          if (raw.isEmpty) {
            return _EmptyState(onImport: _importDocuments);
          }

          if (files.isEmpty) {
            return Center(
              child: Text(
                'No ${_notesOnly ? "notes" : _filterType?.name ?? "files"} found.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              itemCount: files.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final file = files[i];
                return _AllFileTile(
                  file: file,
                  breadcrumb: ts.getBreadcrumb(file.topicId),
                  onTap: () => NoteViewerScreen.open(context, file),
                  onLongPress: () => _showFileActions(ctx, file),
                  onInfo: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => FilePropertiesScreen(file: file)))
                      .then((deleted) {
                        if (!mounted) return;
                        if (deleted == true) {
                          setState(() {
                            _cachedFiles.removeWhere((f) => f.path == file.path);
                            _dataFuture =
                                Future.value(List<MedFile>.from(_cachedFiles));
                          });
                        } else {
                          _refresh();
                        }
                      }),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showFileActions(BuildContext ctx, MedFile file) {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;

    showModalBottomSheet(
      context: ctx,
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
                    Text(file.fileTypeIcon,
                        style: const TextStyle(fontSize: 22)),
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
                leading: const Text('📂', style: TextStyle(fontSize: 20)),
                title: const Text('Open File'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  NoteViewerScreen.open(ctx, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  ShareHelper.shareFile(ctx, file);
                },
              ),
              ListTile(
                leading: Text(
                  file.isBookmarked ? '🔖' : '📑',
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(
                    file.isBookmarked ? 'Remove Bookmark' : 'Bookmark'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  final newValue = !file.isBookmarked;
                  final messenger = ScaffoldMessenger.of(ctx);
                  await DatabaseService.instance
                      .toggleBookmark(file.path, newValue);
                  await _refresh();
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
                leading: const Text('ℹ️', style: TextStyle(fontSize: 20)),
                title: const Text('File Info'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  Navigator.of(ctx)
                      .push(MaterialPageRoute(
                          builder: (_) => FilePropertiesScreen(file: file)))
                      .then((deleted) {
                        if (!mounted) return;
                        if (deleted == true) {
                          setState(() {
                            _cachedFiles.removeWhere((f) => f.path == file.path);
                            _dataFuture =
                                Future.value(List<MedFile>.from(_cachedFiles));
                          });
                        } else {
                          _refresh();
                        }
                      });
                },
              ),
              ListTile(
                leading: Text('🗑️',
                    style: TextStyle(fontSize: 20, color: cs.error)),
                title:
                    Text('Delete', style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _confirmDelete(ctx, file);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, MedFile file) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
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
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red[600]),
            onPressed: () => Navigator.pop(dCtx, true),
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
        _dataFuture = Future.value(List<MedFile>.from(_cachedFiles));
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
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withAlpha(30)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? activeColor : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : null,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── File tile ────────────────────────────────────────────────────────────────

class _AllFileTile extends StatelessWidget {
  const _AllFileTile({
    required this.file,
    required this.breadcrumb,
    required this.onTap,
    required this.onLongPress,
    required this.onInfo,
  });
  final MedFile file;
  final String breadcrumb;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final tt         = Theme.of(context).textTheme;
    final iconColor  = getFileIconColor(file);
    final badgeLabel = getFileTypeBadge(file);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    if (breadcrumb.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        breadcrumb,
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${file.formattedDate} · ${file.formattedSize}',
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.share_rounded,
                    size: 20, color: cs.primary),
                tooltip: 'Share',
                onPressed: () => ShareHelper.shareFile(context, file),
              ),
              if (file.isBookmarked)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.bookmark_rounded,
                      size: 16, color: AppColors.coral),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});
  final VoidCallback onImport;

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
            const Text('📥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No files yet',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Import a document or share any file from WhatsApp, Gmail, Telegram or any app into MedShelf',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import Documents'),
            ),
          ],
        ),
      ),
    );
  }
}
