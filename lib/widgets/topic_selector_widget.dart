import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../models/topic.dart';
import '../services/topic_service.dart';

/// A self-contained topic selector that shows up to three cascading rows of
/// filter chips (Specialty → Topic → Subtopic) and emits the selected leaf
/// topic via [onChanged].
///
/// Pass [initialTopicId] (and a [ValueKey] that changes when it changes) to
/// auto-select a freshly created topic without user interaction.
class TopicSelectorWidget extends StatefulWidget {
  const TopicSelectorWidget({
    super.key,
    required this.onChanged,
    this.initialTopicId,
  });

  final void Function(Topic? selectedTopic) onChanged;

  /// When set, the widget will auto-select this topic on first build
  /// by walking up the ancestor chain to populate all chip rows.
  final String? initialTopicId;

  @override
  State<TopicSelectorWidget> createState() => _TopicSelectorWidgetState();
}

class _TopicSelectorWidgetState extends State<TopicSelectorWidget> {
  Topic? _l1;
  Topic? _l2;
  Topic? _l3;

  /// Prevents the auto-select from firing more than once per widget instance.
  bool _didAutoSelect = false;

  Topic? get _leaf => _l3 ?? _l2 ?? _l1;

  String _breadcrumb() {
    final parts = [
      if (_l1 != null) _l1!.name,
      if (_l2 != null) _l2!.name,
      if (_l3 != null) _l3!.name,
    ];
    return parts.join(' › ');
  }

  // ─── Auto-select ──────────────────────────────────────────────────────────

  void _autoSelect(TopicService ts, String topicId) {
    // Walk up from the target topic to build the ancestor chain.
    final chain = <Topic>[];
    String? cur = topicId;
    while (cur != null) {
      final t = ts.getTopicById(cur);
      if (t == null) break;
      chain.insert(0, t); // prepend → root first
      cur = t.parentId;
    }
    setState(() {
      _l1 = chain.isNotEmpty ? chain[0] : null;
      _l2 = chain.length > 1 ? chain[1] : null;
      _l3 = chain.length > 2 ? chain[2] : null;
    });
    widget.onChanged(_leaf);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Consumer<TopicService>(
      builder: (context, topicService, _) {
        // Fire auto-select once after topics are loaded.
        if (!_didAutoSelect && widget.initialTopicId != null) {
          _didAutoSelect = true;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) _autoSelect(topicService, widget.initialTopicId!);
          });
        }

        final l1Topics = topicService.rootTopics;
        final l2Topics = _l1 != null ? _l1!.children : <Topic>[];
        final l3Topics = _l2 != null ? _l2!.children : <Topic>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save to Folder',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Level 1 — Specialty
            _ChipRow(
              label: 'Specialty',
              topics: l1Topics,
              selected: _l1,
              onSelect: (t) {
                setState(() {
                  _l1 = t;
                  _l2 = null;
                  _l3 = null;
                });
                widget.onChanged(_leaf);
              },
              cs: cs,
              tt: tt,
            ),

            // Level 2 — Topic
            if (_l1 != null && l2Topics.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ChipRow(
                label: 'Topic',
                topics: l2Topics,
                selected: _l2,
                onSelect: (t) {
                  setState(() {
                    _l2 = t;
                    _l3 = null;
                  });
                  widget.onChanged(_leaf);
                },
                cs: cs,
                tt: tt,
              ),
            ],

            // Level 3 — Subtopic
            if (_l2 != null && l3Topics.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ChipRow(
                label: 'Subtopic',
                topics: l3Topics,
                selected: _l3,
                onSelect: (t) {
                  setState(() => _l3 = t);
                  widget.onChanged(_leaf);
                },
                cs: cs,
                tt: tt,
              ),
            ],

            // Breadcrumb
            if (_leaf != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _breadcrumb(),
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── Chip Row ─────────────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.topics,
    required this.selected,
    required this.onSelect,
    required this.cs,
    required this.tt,
  });

  final String label;
  final List<Topic> topics;
  final Topic? selected;
  final void Function(Topic) onSelect;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: topics.map((topic) {
              final isSelected = selected?.id == topic.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('${topic.emoji} ${topic.name}'),
                  selected: isSelected,
                  onSelected: (on) {
                    if (on) onSelect(topic);
                  },
                  selectedColor: cs.primaryContainer,
                  checkmarkColor: cs.onPrimaryContainer,
                  labelStyle: tt.labelMedium?.copyWith(
                    color: isSelected
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
