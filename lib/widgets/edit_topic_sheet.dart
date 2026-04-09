import 'package:flutter/material.dart';

import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/topic_service.dart';
import 'medical_emoji_picker.dart';

/// Combined "Edit Folder" bottom sheet — name field + emoji picker in one place.
class EditTopicSheet extends StatefulWidget {
  const EditTopicSheet({
    super.key,
    required this.topic,
    required this.topicService,
    this.onSaved,
  });

  final Topic topic;
  final TopicService topicService;
  final VoidCallback? onSaved;

  @override
  State<EditTopicSheet> createState() => _EditTopicSheetState();
}

class _EditTopicSheetState extends State<EditTopicSheet> {
  late final TextEditingController _nameCtrl;
  late String _emoji;
  bool _saving = false;
  int? _fileCount;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.topic.name);
    _emoji = widget.topic.emoji;
    _nameCtrl.addListener(() => setState(() {}));
    // Load recursive file count (this topic + all descendant folders)
    final allIds = [
      widget.topic.id,
      ...widget.topicService.getAllDescendantIds(widget.topic.id),
    ];
    DatabaseService.instance
        .getFileCountForTopics(allIds)
        .then((count) {
      if (mounted) setState(() => _fileCount = count);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.topicService.updateTopic(
        widget.topic.id,
        newName: name,
        newEmoji: _emoji,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $_emoji $name updated'),
            duration: const Duration(seconds: 2),
          ),
        );
        widget.onSaved?.call();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final previewName =
        _nameCtrl.text.trim().isEmpty ? widget.topic.name : _nameCtrl.text.trim();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle (tappable → dismiss) ───────────────────────────
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: double.infinity,
                height: 32,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            // ── Title ──────────────────────────────────────────────────────
            Text(
              'Edit Folder',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // ── File count card ────────────────────────────────────────────
            if (_fileCount == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF006B74),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      '$_fileCount ${_fileCount == 1 ? 'file' : 'files'} in this folder',
                      style: tt.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // ── Icon ───────────────────────────────────────────────────────
            Text(
              'Icon',
              style:
                  tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Center(
              child: EmojiPickerButton(
                emoji: _emoji,
                size: 80,
                onChanged: (e) => setState(() => _emoji = e),
              ),
            ),
            const SizedBox(height: 24),

            // ── Name ───────────────────────────────────────────────────────
            Text(
              'Folder Name',
              style:
                  tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Cardiology, Pediatrics…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _nameCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: _nameCtrl.clear,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // ── Live preview ───────────────────────────────────────────────
            Text(
              'Preview',
              style:
                  tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(_emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      previewName,
                      style: tt.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Save button ────────────────────────────────────────────────
            FilledButton(
              onPressed:
                  (_saving || _nameCtrl.text.trim().isEmpty) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
