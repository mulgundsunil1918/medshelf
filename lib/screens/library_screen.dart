import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../services/topic_service.dart';
import '../widgets/medical_emoji_picker.dart';
import '../widgets/topic_tree_widget.dart';
import 'file_list_screen.dart';

// ─── Card-view edit helpers ───────────────────────────────────────────────────

/// Shows a rename+emoji bottom sheet for [topic].  Calls [onDone] on success.
Future<void> _showEditCardSheet(
  BuildContext context,
  Topic topic,
  Future<void> Function() onDone,
) async {
  final ts       = Provider.of<TopicService>(context, listen: false);
  final nameCtrl = TextEditingController(text: topic.name);
  String emoji   = topic.emoji;
  bool   saving  = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text('Edit Folder',
                    style: tt.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 1),
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus:  true,
                      decoration: const InputDecoration(
                          labelText: 'Folder Name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 20),
                    Text('Icon',
                        style: tt.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Center(
                      child: EmojiPickerButton(
                        emoji: emoji,
                        size:  80,
                        onChanged: (e) => setS(() => emoji = e),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;
                              setS(() => saving = true);
                              try {
                                await ts.updateTopic(
                                    topic.id,
                                    newName:  name,
                                    newEmoji: emoji);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                await onDone();
                              } finally {
                                if (ctx.mounted) setS(() => saving = false);
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Text('Save Changes'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  nameCtrl.dispose();
}

/// Shows an emoji-only picker sheet for [topic].  Calls [onDone] on success.
Future<void> _showEmojiCardSheet(
  BuildContext context,
  Topic topic,
  Future<void> Function() onDone,
) async {
  final ts   = Provider.of<TopicService>(context, listen: false);
  String emoji = topic.emoji;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text('Change Emoji',
                    style: tt.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Center(
                      child: EmojiPickerButton(
                        emoji: emoji,
                        size:  100,
                        onChanged: (e) => setS(() => emoji = e),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        await ts.updateTopic(topic.id, newEmoji: emoji);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await onDone();
                      },
                      child: const Text('Save'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Opens the add-subfolder sheet with [parentTopic] pre-selected.
Future<void> _showAddSubfolderCardSheet(
  BuildContext context,
  Topic parentTopic,
  Future<void> Function() onDone,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AddTopicSheet(
      onAdded:           onDone,
      preselectedParent: parentTopic,
    ),
  );
}

/// Shows a delete-confirmation dialog for [topic].  Calls [onDone] on success.
Future<void> _confirmDeleteCard(
  BuildContext context,
  Topic topic,
  Future<void> Function() onDone,
) async {
  final ts = Provider.of<TopicService>(context, listen: false);

  // Tally everything that will be wiped — files inside the topic and all
  // its descendants — so the disclaimer can be specific.
  final descendantIds = ts.getAllDescendantIds(topic.id);
  final allIds = [topic.id, ...descendantIds];
  final files = await DatabaseService.instance.getFilesForTopics(allIds);
  final fileCount = files.length;
  final subfolderCount = descendantIds.length;

  if (!context.mounted) return;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.warning_amber_rounded,
          color: Colors.red, size: 36),
      title: const Text(
        'Delete this specialty?',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(ctx).style.copyWith(height: 1.5),
              children: [
                const TextSpan(text: 'This will '),
                const TextSpan(
                  text: 'permanently delete',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' "'),
                TextSpan(
                  text: '${topic.emoji} ${topic.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '" along with:\n'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (fileCount > 0)
            _BulletLine(
              icon: '📄',
              text:
                  '$fileCount file${fileCount == 1 ? '' : 's'} (PDFs, notes, images, videos)',
            ),
          if (subfolderCount > 0)
            _BulletLine(
              icon: '📁',
              text:
                  '$subfolderCount subfolder${subfolderCount == 1 ? '' : 's'} and everything inside',
            ),
          if (fileCount == 0 && subfolderCount == 0)
            const _BulletLine(icon: 'ℹ️', text: 'No files inside.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 16, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This action cannot be undone. Files will be removed from your device too.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.delete_forever_rounded, size: 18),
          label: Text(
            fileCount > 0 ? 'Delete $fileCount files' : 'Delete',
          ),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ts.deleteTopic(topic.id);
  await onDone();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fileCount > 0
              ? '🗑️ Deleted "${topic.name}" and $fileCount file${fileCount == 1 ? '' : 's'}'
              : '🗑️ Deleted "${topic.name}"',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTeal     = Color(0xFF006B74);
const _kTealDark = Color(0xFF004A52);
const _kPrefKey  = 'library_view_mode';

// ─── Library Screen ───────────────────────────────────────────────────────────

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  late Future<Map<String, int>> _countsFuture;
  bool _editMode   = false;
  bool _isListView = true; // overridden by saved pref on init

  @override
  void initState() {
    super.initState();
    FileNotifier.instance.addListener(_refresh);
    _loadViewMode();
  }

  @override
  void dispose() {
    FileNotifier.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _countsFuture = _loadCounts();
  }

  /// Called by MainShell via GlobalKey when the Library tab is tapped.
  void refresh() => _refresh();

  // ── Preference persistence ──────────────────────────────────────────────────

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_kPrefKey) ?? true;
    if (mounted) setState(() => _isListView = saved);
  }

  Future<void> _saveViewMode(bool isListView) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, isListView);
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<Map<String, int>> _loadCounts() async {
    final files = await DatabaseService.instance.getAllFiles();
    final direct = <String, int>{};
    for (final f in files) {
      direct[f.topicId] = (direct[f.topicId] ?? 0) + 1;
    }
    return direct;
  }

  Future<void> _refresh() async {
    final next = _loadCounts();
    setState(() { _countsFuture = next; });
    await next;
  }

  // ── Add topic sheet ─────────────────────────────────────────────────────────

  void _openAddTopicSheet(BuildContext context,
      {required Topic? preselectedParent}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddTopicSheet(
        onAdded: _refresh,
        preselectedParent: preselectedParent,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns all descendant topic IDs (not including [topic] itself).
  static List<String> _descendantIds(Topic topic, TopicService ts) {
    final result = <String>[];
    for (final c in ts.flatTopics.where((t) => t.parentId == topic.id)) {
      result.add(c.id);
      result.addAll(_descendantIds(c, ts));
    }
    return result;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library 📚'),
        leading: (_isListView && _editMode)
            ? IconButton(
                icon:    const Icon(Icons.close_rounded),
                tooltip: 'Exit edit mode',
                onPressed: () => setState(() => _editMode = false),
              )
            : null,
        actions: [
          // ── View-mode toggle ───────────────────────────────────────────────
          IconButton(
            icon:    Icon(_isListView
                ? Icons.grid_view_rounded
                : Icons.list_rounded),
            tooltip: _isListView ? 'Card view' : 'List view',
            onPressed: () {
              final next = !_isListView;
              setState(() {
                _isListView = next;
                if (next) _editMode = false; // reset edit when switching to cards
              });
              _saveViewMode(next);
            },
          ),
          // ── Edit / Done (list view only) ───────────────────────────────────
          if (_isListView)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _editMode
                  ? TextButton.icon(
                      key:      const ValueKey('done'),
                      onPressed: () => setState(() => _editMode = false),
                      icon:     const Icon(Icons.check_rounded),
                      label:    const Text('Done'),
                    )
                  : IconButton(
                      key:      const ValueKey('edit'),
                      icon:     const Icon(Icons.edit_rounded),
                      tooltip:  'Edit Library',
                      onPressed: () => setState(() => _editMode = true),
                    ),
            ),
          // ── Add button (always in card view; in list view hide while editing)
          if (!_isListView || !_editMode)
            IconButton(
              icon:    const Icon(Icons.add_rounded),
              tooltip: 'Add specialty',
              onPressed: () =>
                  _openAddTopicSheet(context, preselectedParent: null),
            ),
        ],
      ),
      body: Consumer<TopicService>(
        builder: (context, topicService, _) {
          return FutureBuilder<Map<String, int>>(
            future: _countsFuture,
            builder: (context, snap) {
              final direct = snap.data ?? {};
              return RefreshIndicator(
                color:     _kTeal,
                onRefresh: _refresh,
                child: AnimatedSwitcher(
                  duration:        const Duration(milliseconds: 280),
                  switchInCurve:   Curves.easeOutCubic,
                  switchOutCurve:  Curves.easeInCubic,
                  child: _isListView
                      ? _buildListView(context, topicService, direct)
                      : _buildCardView(context, topicService, direct),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── List view (existing tree) ───────────────────────────────────────────────

  Widget _buildListView(
    BuildContext context,
    TopicService topicService,
    Map<String, int> direct,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      key: const ValueKey('list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
      children: [
        // Hierarchy legend
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 2),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        cs.surfaceContainerHighest.withAlpha(120),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🏥 Specialty  →  📁 Topic  →  📂 Subtopic',
                style: tt.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),

        // Edit-mode hint banner
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve:    Curves.easeInOut,
          child: _editMode
              ? Container(
                  margin:  const EdgeInsets.only(top: 8, bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:        cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size:  16,
                          color: cs.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap ＋ to add · ✏️ to rename · 🗑️ to delete',
                          style: tt.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(height: 8),
        ),

        // Full topic tree
        ...topicService.rootTopics.map(
          (root) => TopicTreeWidget(
            topics:       [root],
            directCounts: direct,
            topicService: topicService,
            onRefresh:    _refresh,
            editMode:     _editMode,
            onAddSubfolder: (parent) =>
                _openAddTopicSheet(context, preselectedParent: parent),
          ),
        ),

        // Add Specialty button
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              _openAddTopicSheet(context, preselectedParent: null),
          icon:  const Icon(Icons.add_rounded),
          label: const Text('Add New Specialty'),
        ),
      ],
    );
  }

  // ── Card / grid view ────────────────────────────────────────────────────────

  Widget _buildCardView(
    BuildContext context,
    TopicService topicService,
    Map<String, int> direct,
  ) {
    final roots = topicService.rootTopics;

    return GridView.builder(
      key:     const ValueKey('cards'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing:  12,
      ),
      itemCount: roots.length,
      itemBuilder: (ctx, i) {
        final topic    = roots[i];
        final descIds  = _descendantIds(topic, topicService);
        final count    = (direct[topic.id] ?? 0) +
            descIds.fold<int>(0, (sum, id) => sum + (direct[id] ?? 0));
        final children = topicService.flatTopics
            .where((t) => t.parentId == topic.id)
            .toList();

        return _TopicCard(
          topic:     topic,
          fileCount: count,
          onTap: () {
            if (children.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _TopicCardsScreen(
                    parentTopic:  topic,
                    topicService: topicService,
                    directCounts: direct,
                    onChanged:    _refresh,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FileListScreen(topic: topic),
                ),
              );
            }
          },
          onEdit:         () => _showEditCardSheet(context, topic, _refresh),
          onChangeEmoji:  () => _showEmojiCardSheet(context, topic, _refresh),
          onAddSubfolder: () => _showAddSubfolderCardSheet(context, topic, _refresh),
          onDelete:       () => _confirmDeleteCard(context, topic, _refresh),
        );
      },
    );
  }
}

// ─── Topic Card ───────────────────────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.fileCount,
    required this.onTap,
    this.onEdit,
    this.onChangeEmoji,
    this.onAddSubfolder,
    this.onDelete,
  });

  final Topic          topic;
  final int            fileCount;
  final VoidCallback   onTap;
  final VoidCallback?  onEdit;
  final VoidCallback?  onChangeEmoji;
  final VoidCallback?  onAddSubfolder;
  final VoidCallback?  onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:       onTap,
      onLongPress: onEdit, // long-press = quick rename
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kTeal, _kTealDark],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      _kTeal.withAlpha(80),
              blurRadius: 8,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Card body (centred) ─────────────────────────────────────────
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(topic.emoji,
                      style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      topic.name,
                      textAlign: TextAlign.center,
                      maxLines:  2,
                      overflow:  TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        height:     1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$fileCount ${fileCount == 1 ? 'file' : 'files'}',
                    style: TextStyle(
                      color:    Colors.white.withAlpha(190),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // ── 3-dot popup menu ────────────────────────────────────────────
            Positioned(
              top:   4,
              right: 4,
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white70,
                  size:  18,
                ),
                padding:      EdgeInsets.zero,
                iconSize:     18,
                splashRadius: 16,
                itemBuilder:  (_) => [
                  if (onEdit != null)
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: ListTile(
                        leading:  Icon(Icons.edit_rounded, size: 18),
                        title:    Text('Rename'),
                        dense:    true,
                      ),
                    ),
                  if (onChangeEmoji != null)
                    const PopupMenuItem<String>(
                      value: 'emoji',
                      child: ListTile(
                        leading:  Icon(Icons.emoji_emotions_rounded,
                            size: 18),
                        title:    Text('Change Emoji'),
                        dense:    true,
                      ),
                    ),
                  if (onAddSubfolder != null)
                    const PopupMenuItem<String>(
                      value: 'add',
                      child: ListTile(
                        leading:  Icon(Icons.create_new_folder_rounded,
                            size: 18),
                        title:    Text('Add Subfolder'),
                        dense:    true,
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        leading:  Icon(Icons.delete_rounded,
                            size: 18, color: Colors.red),
                        title:    Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        dense:    true,
                      ),
                    ),
                ],
                onSelected: (val) {
                  if (val == 'rename') onEdit?.call();
                  if (val == 'emoji')  onChangeEmoji?.call();
                  if (val == 'add')    onAddSubfolder?.call();
                  if (val == 'delete') onDelete?.call();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Topic Cards Screen ───────────────────────────────────────────────────────
//
// Shown when a card is tapped in the grid view.
// Continues the card-based hierarchy: specialty → topics → subtopics → files.

class _TopicCardsScreen extends StatefulWidget {
  const _TopicCardsScreen({
    required this.parentTopic,
    required this.topicService,
    required this.directCounts,
    required this.onChanged,
  });

  final Topic                      parentTopic;
  final TopicService               topicService;
  final Map<String, int>           directCounts;
  final Future<void> Function()    onChanged; // bubbles up to LibraryScreen

  @override
  State<_TopicCardsScreen> createState() => _TopicCardsScreenState();
}

class _TopicCardsScreenState extends State<_TopicCardsScreen> {
  late Map<String, int> _counts;

  @override
  void initState() {
    super.initState();
    _counts = widget.directCounts;
  }

  Future<void> _reload() async {
    final files = await DatabaseService.instance.getAllFiles();
    final next  = <String, int>{};
    for (final f in files) {
      next[f.topicId] = (next[f.topicId] ?? 0) + 1;
    }
    if (mounted) setState(() => _counts = next);
    await widget.onChanged(); // also refresh parent screen
  }

  List<String> _descendantIds(Topic topic) {
    final result = <String>[];
    for (final c in widget.topicService.flatTopics
        .where((t) => t.parentId == topic.id)) {
      result.add(c.id);
      result.addAll(_descendantIds(c));
    }
    return result;
  }

  Future<void> _addSubfolder() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddTopicSheet(
        onAdded: _reload,
        preselectedParent: widget.parentTopic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.topicService.flatTopics
        .where((t) => t.parentId == widget.parentTopic.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.parentTopic.emoji} ${widget.parentTopic.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            tooltip: 'Add subfolder',
            onPressed: _addSubfolder,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubfolder,
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('New Folder'),
        backgroundColor: const Color(0xFFE8835A),
        foregroundColor: Colors.white,
      ),
      body: children.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📁', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'No subfolders yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "+ New Folder" to add one.',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing:  12,
              ),
              itemCount: children.length,
              itemBuilder: (ctx, i) {
                final child         = children[i];
                final grandChildren = widget.topicService.flatTopics
                    .where((t) => t.parentId == child.id)
                    .toList();
                final descIds = _descendantIds(child);
                final count   = (_counts[child.id] ?? 0) +
                    descIds.fold<int>(0,
                        (sum, id) => sum + (_counts[id] ?? 0));

                return _TopicCard(
                  topic:     child,
                  fileCount: count,
                  onTap: () {
                    if (grandChildren.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _TopicCardsScreen(
                            parentTopic:  child,
                            topicService: widget.topicService,
                            directCounts: _counts,
                            onChanged:    _reload,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FileListScreen(topic: child),
                        ),
                      );
                    }
                  },
                  onEdit:         () => _showEditCardSheet(
                      context, child, _reload),
                  onChangeEmoji:  () => _showEmojiCardSheet(
                      context, child, _reload),
                  onAddSubfolder: () => _showAddSubfolderCardSheet(
                      context, child, _reload),
                  onDelete:       () => _confirmDeleteCard(
                      context, child, _reload),
                );
              },
            ),
    );
  }
}

// ─── Add Topic Sheet ──────────────────────────────────────────────────────────

class _AddTopicSheet extends StatefulWidget {
  const _AddTopicSheet({
    required this.onAdded,
    this.preselectedParent,
  });

  final Future<void> Function() onAdded;
  final Topic? preselectedParent;

  @override
  State<_AddTopicSheet> createState() => _AddTopicSheetState();
}

class _AddTopicSheetState extends State<_AddTopicSheet> {
  final _nameCtrl = TextEditingController();
  String _emoji = '📁';
  late Topic? _parent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parent = widget.preselectedParent;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    // Capture ts BEFORE setState — calling Provider.of after setState
    // races with the scheduled rebuild and causes _dependents.isEmpty crash.
    final ts = context.read<TopicService>();
    setState(() => _saving = true);
    try {
      await ts.addTopic(
          name: name, parentId: _parent?.id, emoji: _emoji);
      if (mounted) {
        Navigator.of(context).pop();
        await widget.onAdded();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickParent() async {
    final ts = Provider.of<TopicService>(context, listen: false);
    final result = await showDialog<(bool, Topic?)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Parent Folder'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop((true, null)),
            child: const ListTile(
              leading: Text('📂', style: TextStyle(fontSize: 20)),
              title: Text('Root (no parent)'),
            ),
          ),
          ...ts.flatTopics.map(
            (t) => SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop((true, t)),
              child: ListTile(
                leading: Text(t.emoji,
                    style: const TextStyle(fontSize: 20)),
                title: Text(t.name),
                subtitle: ts.getBreadcrumb(t.id).isNotEmpty
                    ? Text(
                        ts.getBreadcrumb(t.id),
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
    if (result == null) return;
    final (_, picked) = result;
    setState(() => _parent = picked);
  }

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
            child: Text('New Folder',
                style:
                    tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Folder Name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),
                  Text('Icon',
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Center(
                    child: EmojiPickerButton(
                      emoji: _emoji,
                      size: 80,
                      onChanged: (e) => setState(() => _emoji = e),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _pickParent,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Parent Folder',
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        _parent != null
                            ? '${_parent!.emoji} ${_parent!.name}'
                            : 'Root (no parent)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Text('Create Folder'),
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
