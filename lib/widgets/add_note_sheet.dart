import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../services/file_storage_service.dart';
import '../models/topic.dart';
import 'topic_selector_widget.dart';

class AddNoteSheet extends StatefulWidget {
  const AddNoteSheet({super.key});

  @override
  State<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<AddNoteSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  Topic? _selectedTopic;
  bool _isBookmarked = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ─── Save logic ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('Please enter a note title.');
      return;
    }
    final content = _contentController.text.trim();
    if (content.isEmpty) {
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
      final medFile = await FileStorageService.instance.createNote(
        title: title,
        content: content,
        topic: topic,
      );

      final fileToSave =
          _isBookmarked ? medFile.copyWith(isBookmarked: true) : medFile;
      await DatabaseService.instance.saveFile(fileToSave);
      FileNotifier.instance.notifyFileChanged();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note saved to ${topic.name} ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
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
          // ── Drag handle ────────────────────────────────────────────────
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
              'New Note 📝',
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
                  // ── Note title ────────────────────────────────────────
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Note Title',
                      hintText: 'Enter a title for your note',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 20),

                  // ── Note content ──────────────────────────────────────
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      hintText: 'Write your note...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: null,
                    minLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 20),

                  // ── Topic selector ────────────────────────────────────
                  TopicSelectorWidget(
                    onChanged: (t) =>
                        setState(() => _selectedTopic = t),
                  ),
                  const SizedBox(height: 20),

                  // ── Bookmark toggle ───────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🔖',
                              style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text('Bookmark this note',
                              style: tt.bodyMedium),
                        ],
                      ),
                      Switch(
                        value: _isBookmarked,
                        onChanged: (v) =>
                            setState(() => _isBookmarked = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Save / Cancel ─────────────────────────────────────
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Text('Save Note'),
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
