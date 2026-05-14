import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:open_filex/open_filex.dart';

import '../models/med_file.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../utils/share_helper.dart';

// ─── 8 inline-highlight tints (applied to selected text) ──────────────────────

const _kHighlights = <Color>[
  Color(0xFFFFFFFF), // 0 clear
  Color(0xFFFFF59D), // 1 yellow
  Color(0xFFC8E6C9), // 2 mint
  Color(0xFFB3E5FC), // 3 sky
  Color(0xFFF8BBD0), // 4 pink
  Color(0xFFD1C4E9), // 5 lavender
  Color(0xFFFFCCBC), // 6 peach
  Color(0xFFD7CCC8), // 7 taupe
];

const _kAccent = Color(0xFF006B74);

// ─── Entry point ──────────────────────────────────────────────────────────────

class NoteViewerScreen extends StatelessWidget {
  const NoteViewerScreen({super.key, required this.file});
  final MedFile file;

  static bool _isNote(MedFile f) {
    final p = f.path.toLowerCase();
    return f.isNote || p.endsWith('.txt') || p.endsWith('.md');
  }

  /// Open a note in the rich Quill editor, or fall back to the system viewer
  /// for PDFs / images / videos.
  static void open(BuildContext context, MedFile file) {
    if (_isNote(file)) {
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (ctx, anim, sec) => _NoteEditorPage(file: file),
          transitionsBuilder: (ctx, anim, sec, child) {
            final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: c,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(c),
                child: child,
              ),
            );
          },
        ),
      );
    } else {
      OpenFilex.open(file.path);
    }
  }

  @override
  Widget build(BuildContext context) => _NoteEditorPage(file: file);
}

// ─── Editor page ──────────────────────────────────────────────────────────────

class _NoteEditorPage extends StatefulWidget {
  const _NoteEditorPage({required this.file});
  final MedFile file;

  @override
  State<_NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<_NoteEditorPage> {
  QuillController? _quill;
  final _editorFocus = FocusNode();
  final _editorScroll = ScrollController();

  bool _loaded = false;
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isPinned = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _isPinned = widget.file.isBookmarked;
    _load();
  }

  @override
  void dispose() {
    _quill?.removeListener(_onEdit);
    _quill?.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  void _onEdit() {
    if (_loaded && !_hasChanges) setState(() => _hasChanges = true);
  }

  // ── Load: parse Delta JSON, fall back to plain text ────────────────────────

  Future<void> _load() async {
    String text = '';
    try {
      text = await File(widget.file.path).readAsString();
    } catch (_) {}
    if (!mounted) return;

    Document doc;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      doc = Document();
    } else if (trimmed.startsWith('[')) {
      try {
        final parsed = jsonDecode(trimmed);
        if (parsed is List) {
          doc = Document.fromJson(parsed);
        } else {
          doc = Document()..insert(0, text);
        }
      } catch (_) {
        doc = Document()..insert(0, text);
      }
    } else {
      doc = Document()..insert(0, text);
    }

    final ctrl = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    ctrl.addListener(_onEdit);

    setState(() {
      _quill = ctrl;
      _loaded = true;
    });
  }

  // ── Save: serialize Delta JSON to disk ─────────────────────────────────────

  Future<void> _save() async {
    final q = _quill;
    if (q == null || _isSaving) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final deltaJson = jsonEncode(q.document.toDelta().toJson());
      await File(widget.file.path).writeAsString(deltaJson);

      final updated = widget.file.copyWith(
        isBookmarked: _isPinned,
        sizeBytes: deltaJson.length,
      );
      await DatabaseService.instance.updateFile(updated);
      FileNotifier.instance.notifyFileChanged();

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Saved ✓'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
            backgroundColor: _kAccent,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Pin / delete ───────────────────────────────────────────────────────────

  Future<void> _togglePin() async {
    setState(() => _isPinned = !_isPinned);
    await DatabaseService.instance
        .toggleBookmark(widget.file.path, _isPinned);
    FileNotifier.instance.notifyFileChanged();
  }

  Future<void> _confirmDelete() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete note?'),
        content: Text('"${widget.file.name}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final f = File(widget.file.path);
      if (await f.exists()) await f.delete();
      await DatabaseService.instance.deleteFile(widget.file.path);
      FileNotifier.instance.notifyFileChanged();
      if (mounted) navigator.pop();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not delete note')),
        );
      }
    }
  }

  // ── Highlight tint application ─────────────────────────────────────────────

  void _applyHighlight(Color c, {required bool clear}) {
    final q = _quill;
    if (q == null) return;
    final hex = clear
        ? null
        : '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    q.formatSelection(BackgroundAttribute(hex));
  }

  // ── Date helper ────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (_hasChanges) await _save();
        if (mounted) nav.pop();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: _kAccent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.file.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(widget.file.savedAt),
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save_rounded, color: Colors.white),
                tooltip: 'Save',
                onPressed: _save,
              ),
            IconButton(
              icon: Icon(
                _isPinned
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _isPinned ? Colors.amber : Colors.white,
              ),
              tooltip: _isPinned ? 'Unpin' : 'Pin',
              onPressed: _togglePin,
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              tooltip: 'Share',
              onPressed: () async {
                final ctx = context;
                if (_hasChanges) await _save();
                if (!mounted) return;
                if (!ctx.mounted) return;
                await ShareHelper.shareFile(ctx, widget.file);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: !_loaded || _quill == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ── Single-row toolbar (horizontal scroll) ───────────
                  Container(
                    color: cs.surface,
                    child: QuillSimpleToolbar(
                      controller: _quill!,
                      config: const QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        toolbarSize: 36,
                        showFontFamily: false,
                        showFontSize: false,
                        showCodeBlock: false,
                        showInlineCode: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showAlignmentButtons: false,
                        showCenterAlignment: false,
                        showLeftAlignment: false,
                        showRightAlignment: false,
                        showJustifyAlignment: false,
                        showSearchButton: false,
                        showColorButton: false,
                        showBackgroundColorButton: false,
                        showLink: true,
                        showClearFormat: true,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showStrikeThrough: true,
                        showListBullets: true,
                        showListNumbers: true,
                        showListCheck: false,
                        showIndent: true,
                        showHeaderStyle: true,
                        showQuote: true,
                        showUndo: true,
                        showRedo: true,
                        showDirection: false,
                        showDividers: false,
                      ),
                    ),
                  ),

                  // ── Compact 8-tint highlight strip ──────────────────
                  Container(
                    color: cs.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _kHighlights.length,
                      itemBuilder: (_, i) {
                        final c = _kHighlights[i];
                        final isClear = i == 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Tooltip(
                            message:
                                isClear ? 'Clear highlight' : 'Highlight',
                            child: GestureDetector(
                              onTap: () =>
                                  _applyHighlight(c, clear: isClear),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: isClear
                                    ? Icon(Icons.format_color_reset,
                                        size: 12,
                                        color: cs.onSurfaceVariant)
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),

                  // ── Editor body — takes all remaining space ──────────
                  Expanded(
                    child: Container(
                      color: cs.surface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: QuillEditor.basic(
                        controller: _quill!,
                        focusNode: _editorFocus,
                        scrollController: _editorScroll,
                        config: QuillEditorConfig(
                          placeholder: 'Start writing…',
                          padding: const EdgeInsets.all(8),
                          autoFocus: true,
                          expands: false,
                          scrollable: true,
                          customStyles: DefaultStyles(
                            paragraph: DefaultTextBlockStyle(
                              TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: cs.onSurface,
                              ),
                              const HorizontalSpacing(0, 0),
                              const VerticalSpacing(6, 6),
                              const VerticalSpacing(0, 0),
                              null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
