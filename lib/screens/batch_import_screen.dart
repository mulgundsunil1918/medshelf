import 'dart:io';

import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/med_file.dart';
import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/topic_service.dart';
import '../widgets/file_thumbnail.dart';

enum BatchMode { files, folder }

class BatchImportScreen extends StatefulWidget {
  const BatchImportScreen({
    super.key,
    required this.mode,
    this.preloadedPaths,
  });
  final BatchMode mode;

  /// If provided, the file picker is skipped on mount and these paths
  /// are pre-populated. Used by the share-intent flow when the user
  /// shares multiple files into MedShelf at once.
  final List<String>? preloadedPaths;

  @override
  State<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends State<BatchImportScreen> {
  List<_ImportItem> _items = [];
  Topic? _destination;
  bool _importing = false;
  int _progress = 0;
  int _failed = 0;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedPaths != null && widget.preloadedPaths!.isNotEmpty) {
      _items = widget.preloadedPaths!
          .map((p) => _ImportItem(path: p))
          .toList();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
    }
  }

  Future<void> _pick() async {
    if (widget.mode == BatchMode.files) {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform
            .pickFiles(allowMultiple: true);
      } catch (_) {}
      if (result == null || !mounted) return;
      setState(() {
        _items = result!.files
            .where((f) => f.path != null)
            .map((f) => _ImportItem(path: f.path!))
            .toList();
      });
    } else {
      String? dir;
      try {
        dir = await FilePicker.platform.getDirectoryPath();
      } catch (_) {}
      if (dir == null || !mounted) return;
      final found = <_ImportItem>[];
      try {
        await for (final e in Directory(dir).list(recursive: true)) {
          if (e is File) found.add(_ImportItem(path: e.path));
        }
      } catch (_) {}
      setState(() => _items = found);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get _selectedCount => _items.where((i) => i.selected).length;

  Future<void> _import() async {
    final dest = _destination;
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination folder')),
      );
      return;
    }
    final toImport = _items.where((i) => i.selected).toList();
    if (toImport.isEmpty) return;

    setState(() { _importing = true; _progress = 0; _failed = 0; });

    for (final item in toImport) {
      try {
        final name = item.path.split('/').last;
        final medFile = await FileStorageService.instance.storeFile(
          sourcePath: item.path,
          topic: dest,
          customName: name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name,
        );
        await DatabaseService.instance.saveFile(medFile);
      } catch (_) {
        if (mounted) setState(() => _failed++);
      }
      if (!mounted) break;
      setState(() => _progress++);
    }

    FileNotifier.instance.notifyFileChanged();

    if (mounted) {
      final ok = toImport.length - _failed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _failed == 0
                ? '✓ $ok file${ok == 1 ? '' : 's'} imported to ${dest.name}'
                : '✓ $ok imported, $_failed failed',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = context.watch<TopicService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == BatchMode.files
            ? 'Import Files'
            : 'Import Folder'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              for (final i in _items) { i.selected = true; }
            }),
            child: const Text('All'),
          ),
          TextButton(
            onPressed: () => setState(() {
              for (final i in _items) { i.selected = false; }
            }),
            child: const Text('None'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Destination picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<Topic>(
              initialValue: _destination,
              hint: const Text('Select destination folder'),
              decoration: InputDecoration(
                labelText: 'Destination',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              items: ts.flatTopics
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          '${t.emoji}  ${t.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (t) => setState(() => _destination = t),
            ),
          ),

          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Found ${_items.length} file${_items.length == 1 ? '' : 's'}  ·  $_selectedCount selected',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ),

          if (_importing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _selectedCount > 0
                        ? _progress / _selectedCount
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Importing $_progress of $_selectedCount...',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),

          const Divider(height: 16),

          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded,
                            size: 56, color: cs.outline),
                        const SizedBox(height: 12),
                        const Text('No files selected'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _pick,
                          child: const Text('Pick files'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      final name = item.path.split('/').last;
                      final ext = name.contains('.')
                          ? name.split('.').last
                          : '';
                      final medFile = MedFile(
                        name: name,
                        path: item.path,
                        topicId: 'unsorted',
                        fileType: MedFile.typeFromExtension(ext),
                        sizeBytes: 0,
                        savedAt: DateTime.now(),
                      );
                      return Card(
                        margin: EdgeInsets.zero,
                        child: CheckboxListTile(
                          value: item.selected,
                          onChanged: _importing
                              ? null
                              : (v) => setState(
                                  () => item.selected = v ?? false),
                          secondary: FileThumbnail(file: medFile, size: 44),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: FutureBuilder<FileStat>(
                            future: FileStat.stat(item.path),
                            builder: (_, snap) {
                              if (!snap.hasData) return const SizedBox();
                              return Text(
                                _formatBytes(snap.data!.size),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant),
                              );
                            },
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _importing || _selectedCount == 0 ? null : _import,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFFE8835A),
            ),
            child: Text(
              _importing
                  ? 'Importing...'
                  : 'Import $_selectedCount file${_selectedCount == 1 ? '' : 's'}',
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportItem {
  _ImportItem({required this.path}) : selected = true;
  final String path;
  bool selected;
}
