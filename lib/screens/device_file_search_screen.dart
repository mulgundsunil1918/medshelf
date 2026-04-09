import 'dart:io';

import 'package:flutter/material.dart';

import '../models/med_file.dart';
import '../widgets/file_thumbnail.dart';
import '../widgets/save_file_sheet.dart';

const _kSearchDirs = [
  '/storage/emulated/0/WhatsApp/Media',
  '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media',
  '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media',
  '/storage/emulated/0/Telegram',
  '/storage/emulated/0/Android/media/org.telegram.messenger',
  '/storage/emulated/0/Download',
  '/storage/emulated/0/Downloads',
  '/storage/emulated/0/Documents',
  '/storage/emulated/0/DCIM',
  '/storage/emulated/0/Pictures',
  '/storage/emulated/0/Movies',
];

const _kFilters = ['All', 'PDF', 'PPT', 'DOC', 'Image', 'Video'];

class DeviceFileSearchScreen extends StatefulWidget {
  const DeviceFileSearchScreen({super.key});

  @override
  State<DeviceFileSearchScreen> createState() =>
      _DeviceFileSearchScreenState();
}

class _DeviceFileSearchScreenState extends State<DeviceFileSearchScreen> {
  final _ctrl = TextEditingController();
  String _filter = 'All';
  List<FileSystemEntity> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() { _searching = true; _results = []; });

    final found = <FileSystemEntity>[];
    for (final dirPath in _kSearchDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is! File) continue;
          final name = entity.path.split('/').last.toLowerCase();
          if (!name.contains(query.toLowerCase())) continue;
          if (!_matchesFilter(entity.path)) continue;
          found.add(entity);
        }
      } catch (_) {}
    }

    if (mounted) setState(() { _results = found; _searching = false; });
  }

  bool _matchesFilter(String path) {
    if (_filter == 'All') return true;
    final lower = path.toLowerCase();
    switch (_filter) {
      case 'PDF':   return lower.endsWith('.pdf');
      case 'PPT':   return lower.endsWith('.ppt') || lower.endsWith('.pptx');
      case 'DOC':   return lower.endsWith('.doc') || lower.endsWith('.docx');
      case 'Image': return lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
                           lower.endsWith('.png') || lower.endsWith('.webp');
      case 'Video': return lower.endsWith('.mp4') || lower.endsWith('.mkv') ||
                           lower.endsWith('.mov') || lower.endsWith('.avi');
      default:      return true;
    }
  }

  MedFile _toMedFile(FileSystemEntity e) {
    final path = e.path;
    final name = path.split('/').last;
    final ext = name.contains('.') ? name.split('.').last : '';
    return MedFile(
      name: name,
      path: path,
      topicId: 'unsorted',
      fileType: MedFile.typeFromExtension(ext),
      sizeBytes: 0,
      savedAt: DateTime.now(),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _import(FileSystemEntity entity) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SaveFileSheet(sourcePath: entity.path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _ctrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF006B74),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Search Device Files',
            style: TextStyle(color: Colors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search PDFs, docs, videos...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Colors.white70),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Colors.white70),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withAlpha(30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: _kFilters.map((f) {
                final active = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _filter = f);
                      if (query.length >= 2) _search(query);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? cs.primary.withAlpha(30)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? cs.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: active ? cs.primary : cs.onSurfaceVariant,
                          fontWeight:
                              active ? FontWeight.w600 : null,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          const Divider(height: 1),
          // Result count
          if (!_searching && query.length >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Found ${_results.length} file${_results.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          Expanded(child: _buildBody(cs, query)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, String query) {
    if (query.length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android_rounded, size: 56, color: cs.outline),
            const SizedBox(height: 12),
            Text('Type 2+ characters to search',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (!_searching && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('No files found',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (ctx, i) {
        final entity = _results[i];
        final name = entity.path.split('/').last;
        final medFile = _toMedFile(entity);

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                FileThumbnail(file: medFile, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      FutureBuilder<FileStat>(
                        future: FileStat.stat(entity.path),
                        builder: (_, snap) {
                          if (!snap.hasData) return const SizedBox();
                          final stat = snap.data!;
                          return Text(
                            '${_formatBytes(stat.size)}  ·  '
                            '${stat.modified.day}/${stat.modified.month}/${stat.modified.year}',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant),
                          );
                        },
                      ),
                      Text(
                        entity.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_to_photos_rounded),
                  color: const Color(0xFFE8835A),
                  tooltip: 'Import to MedShelf',
                  onPressed: () => _import(entity),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
