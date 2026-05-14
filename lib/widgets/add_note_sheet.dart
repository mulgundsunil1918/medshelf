import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/med_file.dart';
import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../services/file_storage_service.dart';
import 'topic_selector_widget.dart';

// ─── 8 background-tint chips for highlighting selected text ───────────────────

const _kHighlights = <Color>[
  Color(0xFFFFFFFF), // 0 white (clear)
  Color(0xFFFFF59D), // 1 yellow
  Color(0xFFC8E6C9), // 2 mint
  Color(0xFFB3E5FC), // 3 sky
  Color(0xFFF8BBD0), // 4 pink
  Color(0xFFD1C4E9), // 5 lavender
  Color(0xFFFFCCBC), // 6 peach
  Color(0xFFD7CCC8), // 7 taupe
];

const _kTeal = Color(0xFF006B74);

class AddNoteSheet extends StatefulWidget {
  const AddNoteSheet({super.key});

  @override
  State<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<AddNoteSheet> {
  final _titleController = TextEditingController();
  final _quill = QuillController.basic();
  final _editorFocus = FocusNode();
  final _editorScroll = ScrollController();

  Topic? _selectedTopic;
  bool _isBookmarked = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _quill.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('Please enter a note title.');
      return;
    }
    if (_quill.document.isEmpty()) {
      _showError('Please write something in your note.');
      return;
    }
    final topic = _selectedTopic;
    if (topic == null) {
      _showError('Please select a folder.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final deltaJson = jsonEncode(_quill.document.toDelta().toJson());
      final medFile = await FileStorageService.instance.createNote(
        title: title,
        content: deltaJson,
        topic: topic,
      );
      MedFile fileToSave = medFile.copyWith(isNote: true);
      if (_isBookmarked) {
        fileToSave = fileToSave.copyWith(isBookmarked: true);
      }
      await DatabaseService.instance.saveFile(fileToSave);
      FileNotifier.instance.notifyFileChanged();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📝 Note saved to ${topic.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) _showError('Failed to save note.');
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

  // ── Highlight chip → Quill background attribute ────────────────────────────

  void _applyHighlight(Color c, {required bool clear}) {
    final hex = clear
        ? null
        : '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    _quill.formatSelection(BackgroundAttribute(hex));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Use a fixed-height container instead of DraggableScrollableSheet —
    // Quill's editor needs a deterministic parent height to render its
    // scrolling content correctly. Without this the body collapses to
    // zero height and looks "empty".
    final sheetHeight = mq.size.height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header: title + Save button ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
              child: Row(
                children: [
                  const Text('📝', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      autofocus: true,
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Note title…',
                        hintStyle: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kTeal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save'),
                  ),
                ],
              ),
            ),

            // ── Single-row Quill toolbar (horizontal scroll, compact) ──
            Container(
              color: cs.surface,
              child: QuillSimpleToolbar(
                controller: _quill,
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

            // ── Compact 8-tint highlight strip ──────────────────────────
            Container(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _kHighlights.length,
                itemBuilder: (_, i) {
                  final c = _kHighlights[i];
                  final isWhite = i == 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    child: Tooltip(
                      message: isWhite ? 'Clear highlight' : 'Highlight',
                      child: GestureDetector(
                        onTap: () => _applyHighlight(c, clear: isWhite),
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
                          child: isWhite
                              ? Icon(Icons.format_color_reset,
                                  size: 12, color: cs.onSurfaceVariant)
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

            // ── Editor body ──────────────────────────────────────────────
            Expanded(
              child: Container(
                color: cs.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: QuillEditor.basic(
                  controller: _quill,
                  focusNode: _editorFocus,
                  scrollController: _editorScroll,
                  config: QuillEditorConfig(
                    placeholder: 'Start writing your note…',
                    padding: const EdgeInsets.all(8),
                    autoFocus: false,
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

            // ── Footer: topic picker + bookmark toggle ──────────────────
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                border: Border(
                    top: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.5))),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TopicSelectorWidget(
                    onChanged: (t) => setState(() => _selectedTopic = t),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🔖',
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('Bookmark this note', style: tt.bodyMedium),
                        ],
                      ),
                      Switch(
                        value: _isBookmarked,
                        onChanged: (v) =>
                            setState(() => _isBookmarked = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
