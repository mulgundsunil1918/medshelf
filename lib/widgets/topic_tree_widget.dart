import 'package:flutter/material.dart';

import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/topic_service.dart';
import '../screens/file_list_screen.dart';
import 'edit_topic_sheet.dart';

// ─── Medical emoji palette ────────────────────────────────────────────────────

const kMedicalEmojis = [
  '📁', '🏥', '💊', '🩺', '🔬', '🧬', '🧪', '💉', '🩸', '🫁',
  '🧠', '❤️', '🦴', '👶', '🤰', '🚨', '🌡️', '🦷', '👁️', '🩹',
];

// ─── Recursive count helper ───────────────────────────────────────────────────

int topicRecursiveCount(Topic t, Map<String, int> direct) {
  var n = direct[t.id] ?? 0;
  for (final c in t.children) {
    n += topicRecursiveCount(c, direct);
  }
  return n;
}

// ─── TopicTreeWidget ──────────────────────────────────────────────────────────

class TopicTreeWidget extends StatelessWidget {
  const TopicTreeWidget({
    super.key,
    required this.topics,
    required this.directCounts,
    required this.topicService,
    required this.onRefresh,
    required this.onAddSubfolder,
    this.editMode = false,
  });

  final List<Topic> topics;
  final Map<String, int> directCounts;
  final TopicService topicService;
  final Future<void> Function() onRefresh;
  final void Function(Topic parent) onAddSubfolder;
  final bool editMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: topics
          .map((t) => _TopicTile(
                topic: t,
                count: topicRecursiveCount(t, directCounts),
                directCounts: directCounts,
                topicService: topicService,
                onRefresh: onRefresh,
                onAddSubfolder: onAddSubfolder,
                editMode: editMode,
                isLast: true,
                ancestorHasMore: const [],
              ))
          .toList(),
    );
  }
}

// ─── Recursive Topic Tile (StatefulWidget for expand/collapse) ────────────────

class _TopicTile extends StatefulWidget {
  const _TopicTile({
    required this.topic,
    required this.count,
    required this.directCounts,
    required this.topicService,
    required this.onRefresh,
    required this.onAddSubfolder,
    required this.editMode,
    required this.isLast,
    required this.ancestorHasMore,
  });

  final Topic topic;
  final int count;
  final Map<String, int> directCounts;
  final TopicService topicService;
  final Future<void> Function() onRefresh;
  final void Function(Topic) onAddSubfolder;
  final bool editMode;
  final bool isLast; // is this the last sibling in its parent's list
  final List<bool> ancestorHasMore; // for each ancestor level, is there a sibling below?

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _arrowCtrl;
  late final Animation<double> _arrowAnim;

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _arrowAnim = CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.editMode) return; // no expand in edit mode
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _arrowCtrl.forward();
    } else {
      _arrowCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final depth = widget.topic.depth;
    final hasChildren = widget.topic.children.isNotEmpty;

    // ── Level-based sizing ──────────────────────────────────────────────────
    final double emojiSize = depth == 0
        ? 28.0
        : depth == 1
            ? 24.0
            : 20.0;

    final TextStyle nameStyle = switch (depth) {
      0 => (tt.bodyLarge ?? const TextStyle())
          .copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      1 => (tt.bodyMedium ?? const TextStyle())
          .copyWith(fontWeight: FontWeight.w500, fontSize: 15),
      _ => (tt.bodyMedium ?? const TextStyle())
          .copyWith(fontWeight: FontWeight.w400, fontSize: 14),
    };

    // ── Level-based tile background ─────────────────────────────────────────
    final Color tileBg = switch (depth) {
      0 => cs.primaryContainer.withAlpha(80),
      1 => cs.surfaceContainerHighest,
      _ => cs.surface,
    };

    // ── Left border for depth ≥ 2 ───────────────────────────────────────────
    final Border? leftBorder = depth == 2
        ? Border(left: BorderSide(color: cs.primary, width: 3))
        : depth >= 3
            ? Border(left: BorderSide(color: cs.secondary, width: 3))
            : null;

    // ── Direct file count for this topic (not including descendants) ────────
    final directCount = widget.directCounts[widget.topic.id] ?? 0;

    void navigateToFiles() {
      Navigator.of(context)
          .push<bool>(MaterialPageRoute(
              builder: (_) => FileListScreen(topic: widget.topic)))
          .then((result) {
            // Refresh when back is pressed (null) or a file was saved (true).
            if (result == null || result == true) widget.onRefresh();
          });
    }

    // ── Build tile row ──────────────────────────────────────────────────────
    Widget tileRow = GestureDetector(
      onTap: widget.editMode
          ? null
          : (hasChildren ? _toggle : navigateToFiles),
      onLongPress: widget.editMode
          ? null
          : () => _showTopicActions(
                context,
                widget.topic,
                widget.topicService,
                widget.onRefresh,
                widget.onAddSubfolder,
              ),
      child: Container(
        decoration: BoxDecoration(
          color: tileBg,
          border: leftBorder,
        ),
        padding: EdgeInsets.only(
          left: 12,
          right: 8,
          top: depth == 0 ? 8 : depth == 1 ? 4 : 2,
          bottom: depth == 0 ? 8 : depth == 1 ? 4 : 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Emoji
                Text(widget.topic.emoji,
                    style: TextStyle(fontSize: emojiSize)),
                const SizedBox(width: 10),

                // Name
                Expanded(
                  child: Text(
                    widget.topic.name,
                    style: nameStyle.copyWith(color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // ── Trailing section ──────────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // File count badge (non-edit mode only, count > 0)
                    if (widget.count > 0 && !widget.editMode) ...[
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: navigateToFiles,
                        child: Container(
                          constraints: const BoxConstraints(
                              minWidth: 22, minHeight: 22),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${widget.count}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Edit mode: add + edit + delete
                    if (widget.editMode) ...[
                      IconButton(
                        icon: Icon(Icons.add, size: 20, color: cs.primary),
                        onPressed: () => widget.onAddSubfolder(widget.topic),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.edit_rounded,
                            size: 18, color: cs.onSurfaceVariant),
                        onPressed: () => _openEditTopicSheet(
                            context, widget.topic, widget.topicService,
                            widget.onRefresh),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.delete_rounded,
                            size: 18, color: cs.error),
                        onPressed: () => _showDeleteTopicDialog(
                            context, widget.topic, widget.topicService,
                            widget.onRefresh),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                    ] else ...[
                      // + add subtopic button
                      IconButton(
                        icon: Icon(Icons.add,
                            size: 20,
                            color: cs.onSurfaceVariant.withAlpha(150)),
                        onPressed: () => widget.onAddSubfolder(widget.topic),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 12),
                      // Expand/collapse arrow OR navigate arrow
                      if (hasChildren)
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: RotationTransition(
                              turns: Tween(begin: 0.0, end: 0.25)
                                  .animate(_arrowAnim),
                              child: Icon(Icons.chevron_right,
                                  size: 20, color: cs.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios,
                              size: 16,
                              color: cs.onSurfaceVariant.withAlpha(180)),
                          onPressed: navigateToFiles,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                    ],
                  ],
                ),
              ],
            ),

            // "View X files in this folder →" — shown when topic has children
            // AND also has files stored directly in it
            if (hasChildren && directCount > 0 && !widget.editMode)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: navigateToFiles,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2, left: 2),
                  child: Text(
                    '📄 View $directCount file${directCount == 1 ? '' : 's'} in this folder →',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // ── Wrap in tree-line connector for depth ≥ 1 ──────────────────────────
    if (depth > 0) {
      tileRow = _TreeLineWrapper(
        isLast: widget.isLast,
        ancestorHasMore: widget.ancestorHasMore,
        depth: depth,
        child: tileRow,
      );
    }

    // ── Depth 0: wrap in Card ───────────────────────────────────────────────
    if (depth == 0) {
      tileRow = Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tileRow,
            // Children (always visible at depth 0 when expanded)
            if (hasChildren)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _expanded || widget.editMode
                    ? _buildChildren(cs)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      );
    } else {
      // Depth ≥ 1: tile + children in column
      if (hasChildren) {
        tileRow = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tileRow,
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _expanded || widget.editMode
                  ? _buildChildren(cs)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      }
    }

    return tileRow;
  }

  Widget _buildChildren(ColorScheme cs) {
    final children = widget.topic.children;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.asMap().entries.map((e) {
        final i = e.key;
        final child = e.value;
        final isLastChild = i == children.length - 1;
        return _TopicTile(
          topic: child,
          count: topicRecursiveCount(child, widget.directCounts),
          directCounts: widget.directCounts,
          topicService: widget.topicService,
          onRefresh: widget.onRefresh,
          onAddSubfolder: widget.onAddSubfolder,
          editMode: widget.editMode,
          isLast: isLastChild,
          ancestorHasMore: [
            ...widget.ancestorHasMore,
            !widget.isLast,
          ],
        );
      }).toList(),
    );
  }
}

// ─── Tree Line Wrapper ────────────────────────────────────────────────────────

class _TreeLineWrapper extends StatelessWidget {
  const _TreeLineWrapper({
    required this.isLast,
    required this.ancestorHasMore,
    required this.depth,
    required this.child,
  });

  final bool isLast;
  final List<bool> ancestorHasMore;
  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineColor = cs.primary.withAlpha(76); // 0.3 opacity

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ancestor continuation lines (for grandchildren+)
          ...ancestorHasMore.map((hasMore) => SizedBox(
                width: 20,
                child: hasMore
                    ? Center(
                        child: Container(
                            width: 1.5, color: lineColor),
                      )
                    : const SizedBox.shrink(),
              )),

          // This level's connector (├── or └──)
          SizedBox(
            width: 20,
            child: Stack(
              children: [
                // Vertical part of connector
                Positioned(
                  left: 9,
                  top: 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 22 : null,
                  child: Container(width: 1.5, color: lineColor),
                ),
                // Horizontal part of connector
                Positioned(
                  left: 9,
                  top: 21,
                  right: 0,
                  height: 1.5,
                  child: Container(color: lineColor),
                ),
              ],
            ),
          ),

          // The actual tile content
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Topic action dialogs (free functions) ────────────────────────────────────

void _showTopicActions(
  BuildContext context,
  Topic topic,
  TopicService topicService,
  Future<void> Function() onRefresh,
  void Function(Topic) onAddSubfolder,
) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      final cs = Theme.of(sheetCtx).colorScheme;
      final tt = Theme.of(sheetCtx).textTheme;
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
                  Text(topic.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(topic.name,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_rounded),
              title: const Text('Add Subtopic Inside'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                onAddSubfolder(topic);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Folder'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openEditTopicSheet(
                    context, topic, topicService, onRefresh);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: cs.error),
              title: Text('Delete', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _showDeleteTopicDialog(
                    context, topic, topicService, onRefresh);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void _openEditTopicSheet(
  BuildContext context,
  Topic topic,
  TopicService topicService,
  Future<void> Function() onRefresh,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => EditTopicSheet(
      topic: topic,
      topicService: topicService,
      onSaved: onRefresh,
    ),
  );
}

/// Shows delete confirmation. Blocks if the topic or any descendant has files.
Future<void> _showDeleteTopicDialog(
  BuildContext context,
  Topic topic,
  TopicService topicService,
  Future<void> Function() onRefresh,
) async {
  final allIds = [topic.id, ...topicService.getAllDescendantIds(topic.id)];
  int fileCount = 0;
  for (final id in allIds) {
    fileCount += await DatabaseService.instance.getFileCountForTopic(id);
  }

  if (!context.mounted) return;

  if (fileCount > 0) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot Delete'),
        content: Text(
          'This folder contains $fileCount file${fileCount == 1 ? '' : 's'}.\n\n'
          'Move or delete the files first.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final hasChildren = topic.children.isNotEmpty;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Folder'),
      content: Text(
        'Delete "${topic.name}"?'
        '${hasChildren ? '\n\nAll subfolders will also be deleted.' : ''}',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () async {
            await topicService.deleteTopic(topic.id);
            if (ctx.mounted) Navigator.of(ctx).pop();
            await onRefresh();
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
