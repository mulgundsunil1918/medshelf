import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/med_file.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';

// ─── Note background colours ───────────────────────────────────────────────────

const _kColors = [
  Color(0xFFFFFFFF), // 0 – white (default)
  Color(0xFFFFF9C4), // 1 – yellow
  Color(0xFFDCEDC8), // 2 – mint
  Color(0xFFB3E5FC), // 3 – sky blue
  Color(0xFFFFCDD2), // 4 – blush pink
  Color(0xFFE1BEE7), // 5 – lavender
  Color(0xFFFFE0B2), // 6 – peach
  Color(0xFFD7CCC8), // 7 – taupe
];

const _kAccent = Color(0xFF006B74);

// ─── Format types ──────────────────────────────────────────────────────────────

enum _FmtType { bold, underline, highlight }

// ─── In-memory format range ────────────────────────────────────────────────────

class _Fmt {
  _Fmt(this.start, this.end, this.type);
  int start;
  int end;
  final _FmtType type;
}

// ─── Custom rich-text controller ──────────────────────────────────────────────
//
// The underlying [text] is always plain — zero markup symbols are stored or
// displayed.  Bold, underline and highlight are kept as in-memory [_Fmt]
// ranges and rendered via the [buildTextSpan] override.

class _RichCtrl extends TextEditingController {
  final List<_Fmt> _fmts = [];

  // ── Toggle a format on the current selection ────────────────────────────────

  void toggleFormat(_FmtType type) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;

    // If any existing range already fully covers the selection with this
    // type, remove it (i.e. toggle off).
    final covering = _fmts
        .where((f) =>
            f.type == type && f.start <= sel.start && f.end >= sel.end)
        .toList();

    if (covering.isNotEmpty) {
      _fmts.removeWhere((f) =>
          f.type == type && f.start <= sel.start && f.end >= sel.end);
    } else {
      _fmts.add(_Fmt(sel.start, sel.end, type));
    }
    notifyListeners();
  }

  void clearFormats() {
    _fmts.clear();
    notifyListeners();
  }

  // ── Render ──────────────────────────────────────────────────────────────────

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final txt = text;
    if (txt.isEmpty || _fmts.isEmpty) {
      return TextSpan(text: txt, style: style);
    }

    // Clamp every format range to the current text length;
    // discard zero-length or inverted ranges.
    final valid = <_Fmt>[];
    for (final f in _fmts) {
      final s = f.start.clamp(0, txt.length);
      final e = f.end.clamp(0, txt.length);
      if (s < e) valid.add(_Fmt(s, e, f.type));
    }
    if (valid.isEmpty) return TextSpan(text: txt, style: style);

    // Collect all boundary positions, then walk segment-by-segment so that
    // overlapping formats on the same character are all applied at once.
    final bounds = <int>{0, txt.length};
    for (final f in valid) {
      bounds.add(f.start);
      bounds.add(f.end);
    }
    final pts = bounds.toList()..sort();

    final children = <TextSpan>[];
    for (int i = 0; i < pts.length - 1; i++) {
      final s = pts[i];
      final e = pts[i + 1];
      if (s >= e) continue;

      bool bold = false;
      bool ul   = false;
      bool hl   = false;

      for (final f in valid) {
        if (f.start <= s && f.end >= e) {
          switch (f.type) {
            case _FmtType.bold:
              bold = true;
            case _FmtType.underline:
              ul = true;
            case _FmtType.highlight:
              hl = true;
          }
        }
      }

      children.add(TextSpan(
        text: txt.substring(s, e),
        style: TextStyle(
          fontWeight:      bold ? FontWeight.bold      : FontWeight.normal,
          decoration:      ul   ? TextDecoration.underline
                                : TextDecoration.none,
          decorationColor: ul   ? (style?.color ?? Colors.black87) : null,
          backgroundColor: hl   ? const Color(0xFFFFEB3B).withAlpha(170)
                                : null,
        ),
      ));
    }

    return TextSpan(children: children, style: style);
  }
}

// ─── Entry point ───────────────────────────────────────────────────────────────

class NoteViewerScreen extends StatelessWidget {
  const NoteViewerScreen({super.key, required this.file});
  final MedFile file;

  static bool _isNote(MedFile f) {
    final p = f.path.toLowerCase();
    return f.isNote || p.endsWith('.txt') || p.endsWith('.md');
  }

  /// Open a note in the rich editor, or fall back to the system viewer for
  /// PDFs / images / videos.
  static void open(BuildContext context, MedFile file) {
    if (_isNote(file)) {
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration:        const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (ctx, anim, sec) => _NoteEditorPage(file: file),
          transitionsBuilder: (ctx, anim, sec, child) {
            final c = CurvedAnimation(
              parent: anim,
              curve:  Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: c,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end:   Offset.zero,
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

// ─── Note editor page ──────────────────────────────────────────────────────────

class _NoteEditorPage extends StatefulWidget {
  const _NoteEditorPage({required this.file});
  final MedFile file;

  @override
  State<_NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<_NoteEditorPage> {
  late final _RichCtrl _controller;

  bool   _loaded     = false;
  bool   _hasChanges = false;
  bool   _isSaving   = false;
  bool   _isPinned   = false;
  int    _colorIdx   = 0;
  double _fontSize   = 16;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _controller     = _RichCtrl();
    _isPinned = widget.file.isBookmarked;

    // Restore saved background colour stored as "c:N" in MedFile.notes.
    final raw = widget.file.notes;
    if (raw != null) {
      final m = RegExp(r'^c:(\d)$').firstMatch(raw.trim());
      if (m != null) {
        final idx = int.parse(m.group(1)!);
        if (idx < _kColors.length) _colorIdx = idx;
      }
    }

    _load();
    _controller.addListener(_onEdit);
  }

  @override
  void dispose() {
    _controller.removeListener(_onEdit);
    _controller.dispose();
    super.dispose();
  }

  void _onEdit() {
    if (_loaded && !_hasChanges) setState(() => _hasChanges = true);
  }

  // ── I/O ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    String text = '';
    try {
      text = await File(widget.file.path).readAsString();
    } catch (_) {}
    if (!mounted) return;

    // Suppress listener while setting initial text.
    _controller.removeListener(_onEdit);
    _controller.text = text;
    _controller.addListener(_onEdit);

    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    // Capture before any async gap to satisfy use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Only plain text is written to disk — no markup symbols whatsoever.
      await File(widget.file.path).writeAsString(_controller.text);

      final updated = widget.file.copyWith(
        isBookmarked: _isPinned,
        notes:        'c:$_colorIdx',
        sizeBytes:    _controller.text.length,
      );
      await DatabaseService.instance.updateFile(updated);
      FileNotifier.instance.notifyFileChanged();

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving   = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content:         Text('Saved ✓'),
            behavior:        SnackBarBehavior.floating,
            duration:        Duration(seconds: 1),
            backgroundColor: Color(0xFF006B74),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Pin / delete ──────────────────────────────────────────────────────────

  Future<void> _togglePin() async {
    setState(() => _isPinned = !_isPinned);
    await DatabaseService.instance.toggleBookmark(
        widget.file.path, _isPinned);
    FileNotifier.instance.notifyFileChanged();
  }

  Future<void> _confirmDelete() async {
    // Capture before any async gap.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title:   const Text('Delete note?'),
        content: Text(
            '"${widget.file.name}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:     const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child:     const Text('Delete'),
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

  // ── Bullet toggle ─────────────────────────────────────────────────────────

  void _toggleBullet() {
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final text      = _controller.text;
    final lineStart = text.lastIndexOf('\n', sel.start - 1) + 1;

    if (text.substring(lineStart).startsWith('• ')) {
      // Remove bullet prefix
      final newText =
          text.substring(0, lineStart) + text.substring(lineStart + 2);
      _controller.value = TextEditingValue(
        text:      newText,
        selection: TextSelection.collapsed(
          offset: (sel.start - 2).clamp(lineStart, newText.length),
        ),
      );
    } else {
      // Add bullet prefix
      final newText =
          '${text.substring(0, lineStart)}• ${text.substring(lineStart)}';
      _controller.value = TextEditingValue(
        text:      newText,
        selection: TextSelection.collapsed(offset: sel.start + 2),
      );
    }
  }

  // ── Date helper ───────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours   < 24) return '${d.inHours}h ago';
    if (d.inDays    < 7)  return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg  = _kColors[_colorIdx];
    final fg  = bg.computeLuminance() < 0.5 ? Colors.white : Colors.black87;
    final sub = fg.withAlpha(140);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context); // capture before async gap
        if (_hasChanges) await _save();
        if (mounted) nav.pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor:        const Color(0xFF006B74),
          elevation:               0,
          scrolledUnderElevation:  0,
          foregroundColor:         Colors.white,
          iconTheme:               const IconThemeData(color: Colors.white),
          actionsIconTheme:        const IconThemeData(color: Colors.white),
          titleSpacing:            0,
          title: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.file.name,
                  style: const TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w600,
                    color:      Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(widget.file.savedAt),
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withAlpha(180)),
                ),
              ],
            ),
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width:  18,
                  height: 18,
                  child:  CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ),
                ),
              )
            else if (_hasChanges)
              IconButton(
                icon:      const Icon(Icons.save_rounded, color: Colors.white),
                tooltip:   'Save',
                onPressed: _save,
              ),
            IconButton(
              icon: Icon(
                _isPinned
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _isPinned ? Colors.amber : Colors.white,
              ),
              tooltip:   _isPinned ? 'Unpin' : 'Pin',
              onPressed: _togglePin,
            ),
            IconButton(
              icon:      const Icon(Icons.delete_outline_rounded,
                  color: Colors.white),
              tooltip:   'Delete',
              onPressed: _confirmDelete,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ── Colour picker ──────────────────────────────────────────
                  _ColorPicker(
                    selected: _colorIdx,
                    onSelect: (i) => setState(() {
                      _colorIdx   = i;
                      _hasChanges = true;
                    }),
                  ),
                  Divider(height: 1, color: fg.withAlpha(30)),

                  // ── Text field with rich-text controller ───────────────────
                  Expanded(
                    child: TextField(
                      controller:        _controller,
                      autofocus:         true,
                      maxLines:          null,
                      expands:           true,
                      keyboardType:      TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        fontSize: _fontSize,
                        height:   1.75,
                        color:    fg,
                      ),
                      cursorColor: _kAccent,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.fromLTRB(
                            18, 14, 18, 14),
                        border:    InputBorder.none,
                        hintText:  'Start writing…',
                        hintStyle: TextStyle(color: sub),
                      ),
                    ),
                  ),

                  // ── Formatting toolbar ─────────────────────────────────────
                  _buildToolbar(bg, fg),
                ],
              ),
      ),
    );
  }

  // ── Formatting toolbar ─────────────────────────────────────────────────────

  Widget _buildToolbar(Color bg, Color fg) {
    final tbBg = Color.alphaBlend(Colors.black.withAlpha(18), bg);
    return Container(
      color:   tbBg,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Bold: FontWeight.bold on selected text
          _TBtn(
            icon:    Icons.format_bold,
            tooltip: 'Bold',
            fg:      const Color(0xFF333333),
            onTap:   () => _controller.toggleFormat(_FmtType.bold),
          ),
          // Underline: TextDecoration.underline on selected text
          _TBtn(
            icon:    Icons.format_underline,
            tooltip: 'Underline',
            fg:      const Color(0xFF333333),
            onTap:   () => _controller.toggleFormat(_FmtType.underline),
          ),
          // Highlight: yellow backgroundColor on selected text
          _TBtn(
            icon:    Icons.highlight,
            tooltip: 'Highlight',
            fg:      Colors.amber,
            onTap:   () => _controller.toggleFormat(_FmtType.highlight),
          ),
          // Bullet: prepend "• " to the current line
          _TBtn(
            icon:    Icons.format_list_bulleted,
            tooltip: 'Bullet',
            fg:      const Color(0xFF333333),
            onTap:   _toggleBullet,
          ),
          const Spacer(),
          // Font size — changes entire editor, not just selection
          _TBtn(
            icon:    Icons.text_decrease_rounded,
            tooltip: 'Smaller text',
            fg:      const Color(0xFF333333),
            onTap:   () => setState(
              () => _fontSize = (_fontSize - 2).clamp(12, 28),
            ),
          ),
          _TBtn(
            icon:    Icons.text_increase_rounded,
            tooltip: 'Larger text',
            fg:      const Color(0xFF333333),
            onTap:   () => setState(
              () => _fontSize = (_fontSize + 2).clamp(12, 28),
            ),
          ),
          const SizedBox(width: 4),
        ]),
      ),
    );
  }
}

// ─── Colour picker strip ───────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        itemCount: _kColors.length,
        itemBuilder: (ctx, i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width:  30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color:  _kColors[i],
                shape:  BoxShape.circle,
                border: Border.all(
                  color: active ? _kAccent : Colors.grey.shade400,
                  width: active ? 2.5 : 1.0,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color:        _kAccent.withAlpha(90),
                          blurRadius:   6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: active
                  ? Icon(Icons.check_rounded,
                      size: 15, color: _kAccent.withAlpha(210))
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─── Toolbar icon button ──────────────────────────────────────────────────────

class _TBtn extends StatelessWidget {
  const _TBtn({
    required this.icon,
    required this.tooltip,
    required this.fg,
    required this.onTap,
  });

  final IconData     icon;
  final String       tooltip;
  final Color        fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child:   Icon(icon, size: 21, color: fg.withAlpha(190)),
        ),
      ),
    );
  }
}
