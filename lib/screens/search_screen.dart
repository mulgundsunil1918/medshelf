import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/med_file.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/topic_service.dart';
import '../utils/app_colors.dart';
import '../utils/file_type_icon.dart';
import '../widgets/file_thumbnail.dart';
import 'file_properties_screen.dart';
import 'note_viewer_screen.dart';

// ─── Filter labels ─────────────────────────────────────────────────────────
const _kFilters = ['All', 'PDF', 'PPT', 'Excel', 'Image', 'Video', 'Word', 'Notes'];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<MedFile> _allFiles = [];
  List<MedFile> _filteredFiles = [];
  String _selectedFilter = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllFiles();
    _searchController.addListener(_onTextChanged);
    FileNotifier.instance.addListener(_loadAllFiles);
  }

  @override
  void dispose() {
    FileNotifier.instance.removeListener(_loadAllFiles);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAllFiles() async {
    final files = await DatabaseService.instance.getAllFiles();
    if (!mounted) return;
    setState(() {
      _allFiles = files;
      _filteredFiles = _applyChipFilter(files);
      _isLoading = false;
    });
  }

  // ─── Filtering ─────────────────────────────────────────────────────────────

  void _onTextChanged() {
    final query = _searchController.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() => _filteredFiles = _applyChipFilter(_allFiles));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
  }

  void _runSearch(String query) {
    final lower = query.toLowerCase();
    final matched = _allFiles.where((f) {
      return f.name.toLowerCase().contains(lower) ||
          (f.description ?? '').toLowerCase().contains(lower);
    }).toList();
    if (mounted) setState(() => _filteredFiles = _applyChipFilter(matched));
  }

  List<MedFile> _applyChipFilter(List<MedFile> source) =>
      source.where((f) => fileMatchesFilter(f, _selectedFilter)).toList();

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        _filteredFiles = _applyChipFilter(_allFiles);
      } else {
        final lower = query.toLowerCase();
        final matched = _allFiles.where((f) {
          return f.name.toLowerCase().contains(lower) ||
              (f.description ?? '').toLowerCase().contains(lower);
        }).toList();
        _filteredFiles = _applyChipFilter(matched);
      }
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final tt    = Theme.of(context).textTheme;
    final ts    = context.watch<TopicService>();
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Search 🔍'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search files, notes, topics...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filter chips ────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                for (final label in _kFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _TypeChip(
                      label: label,
                      selected: _selectedFilter == label,
                      onTap: () => _setFilter(label),
                      color: _chipColor(label, cs),
                      cs: cs,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Results count ────────────────────────────────────────────────
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                query.isNotEmpty
                    ? '${_filteredFiles.length} result${_filteredFiles.length == 1 ? '' : 's'} for "$query"'
                    : '${_filteredFiles.length} file${_filteredFiles.length == 1 ? '' : 's'} total',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(child: _buildBody(cs, tt, ts, query)),
        ],
      ),
    );
  }

  // Assign a colour to each chip label
  Color? _chipColor(String label, ColorScheme cs) {
    switch (label) {
      case 'All':    return null;
      case 'PDF':    return AppColors.pdfColor;
      case 'PPT':    return Colors.orange[700];
      case 'Image':  return AppColors.imageColor;
      case 'Video':  return AppColors.videoColor;
      case 'Excel':  return Colors.green[800];
      case 'Word':   return AppColors.documentColor;
      case 'Notes':  return cs.tertiary;
      default:       return null;
    }
  }

  Widget _buildBody(
      ColorScheme cs, TextTheme tt, TopicService ts, String query) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allFiles.isEmpty) {
      return _EmptyLibraryState(tt: tt, cs: cs);
    }
    if (_filteredFiles.isEmpty) {
      return _NoResultsState(query: query, tt: tt, cs: cs);
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      itemCount: _filteredFiles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final file = _filteredFiles[i];
        return _SearchResultTile(
          file: file,
          breadcrumb: ts.getBreadcrumb(file.topicId),
          onTap: () => NoteViewerScreen.open(context, file),
          onInfo: () => Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (_) => FilePropertiesScreen(file: file),
              ))
              .then((deleted) {
                if (deleted == true && mounted) {
                  setState(() {
                    _allFiles.removeWhere((f) => f.path == file.path);
                    _filteredFiles.removeWhere((f) => f.path == file.path);
                  });
                }
              }),
          onLongPress: () => _showOptions(context, file),
        );
      },
    );
  }

  void _showOptions(BuildContext context, MedFile file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open File'),
              onTap: () {
                Navigator.pop(sheetCtx);
                NoteViewerScreen.open(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('File Info'),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (_) => FilePropertiesScreen(file: file),
                    ))
                    .then((deleted) {
                      if (deleted == true && mounted) {
                        setState(() {
                          _allFiles.removeWhere((f) => f.path == file.path);
                          _filteredFiles.removeWhere((f) => f.path == file.path);
                        });
                      }
                    });
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Colors.red[600]),
              title: Text('Delete',
                  style: TextStyle(color: Colors.red[600])),
              onTap: () {
                Navigator.pop(sheetCtx);
                _deleteFile(file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFile(MedFile file) async {
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

    // 3. Instantly remove from local lists — no reload needed.
    if (mounted) {
      setState(() {
        _allFiles.removeWhere((f) => f.path == file.path);
        _filteredFiles.removeWhere((f) => f.path == file.path);
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

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

// ─── Search Result Tile ───────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.file,
    required this.breadcrumb,
    required this.onTap,
    required this.onInfo,
    required this.onLongPress,
  });

  final MedFile file;
  final String breadcrumb;
  final VoidCallback onTap;
  final VoidCallback onInfo;
  final VoidCallback onLongPress;

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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              FileThumbnail(file: file, size: 56),
              const SizedBox(width: 12),

              // ── Name + breadcrumb + meta ─────────────────────────────
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
                        // File type badge chip
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

              // ── Right side ───────────────────────────────────────────
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (file.isBookmarked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.bookmark_rounded,
                          size: 16, color: AppColors.coral),
                    ),
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

// ─── Empty States ─────────────────────────────────────────────────────────────

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({required this.tt, required this.cs});
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No files yet',
                style:
                    tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Import a document or share from any app',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState(
      {required this.query, required this.tt, required this.cs});
  final String query;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              query.isEmpty
                  ? 'All your files — tap to open'
                  : 'No results for "$query"',
              style:
                  tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty ? 'Start typing to search' : 'Try a different keyword',
              textAlign: TextAlign.center,
              style:
                  tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
