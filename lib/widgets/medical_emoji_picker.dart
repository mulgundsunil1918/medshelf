import 'package:flutter/material.dart';

// ─── Emoji data ───────────────────────────────────────────────────────────────

const _kCategories = [
  _EmojiCategory(
    label: 'Body & Organs',
    icon: '🏥',
    emojis: [
      '🫀', '🫁', '🧠', '🦷', '🦴', '👁️', '👂', '👃',
      '🫃', '🫄', '🤰', '🤱', '💪', '🦵', '🦶', '🖐️',
      '🫶', '🧬', '🩻', '🫂',
    ],
  ),
  _EmojiCategory(
    label: 'Medical',
    icon: '🩺',
    emojis: [
      '🩺', '💉', '🩸', '🩹', '🩼', '🩻', '💊', '🧪',
      '🧫', '🔬', '🔭', '⚕️', '🏥', '🚑', '🩴', '🧲',
      '⚗️', '🫙', '🧴', '🛏️', '🪑', '🚿', '🧹', '🧺',
      '🩱',
    ],
  ),
  _EmojiCategory(
    label: 'Specialties',
    icon: '👶',
    emojis: [
      '👶', '🍼', '🤱', '🧒', '👦', '👧', '🧑', '👩',
      '👨', '🧓', '👴', '👵', '🚨', '❤️', '💔', '❤️‍🔥',
      '🫀', '🧠', '🦴', '🦷', '👁️', '👂', '🫁', '🩸',
      '🦠',
    ],
  ),
  _EmojiCategory(
    label: 'Study',
    icon: '📚',
    emojis: [
      '📚', '📖', '📝', '📄', '📃', '📑', '🗒️', '📋',
      '📌', '📍', '📎', '🔍', '🔎', '📊', '📈', '📉',
      '🗂️', '🗃️', '📰', '🗞️',
    ],
  ),
  _EmojiCategory(
    label: 'Folders',
    icon: '📁',
    emojis: [
      '📁', '📂', '🗂️', '📦', '📥', '📤', '🔖', '🏷️',
      '🔗', '📎', '🖇️', '✅', '❌', '⚠️', '💡', '🔋',
      '⭐', '🌟', '🏆', '🎯',
    ],
  ),
];

// ─── All 110 emojis for search ────────────────────────────────────────────────

final _kAllEmojis =
    _kCategories.expand((c) => c.emojis).toSet().toList();

// ─── Keyword search map ───────────────────────────────────────────────────────

const _kKeywords = <String, List<String>>{
  'heart':      ['❤️', '🫀', '💔', '❤️‍🔥'],
  'lung':       ['🫁'],
  'brain':      ['🧠'],
  'bone':       ['🦴'],
  'eye':        ['👁️'],
  'ear':        ['👂'],
  'blood':      ['🩸', '💉'],
  'baby':       ['👶', '🍼', '🤱'],
  'needle':     ['💉'],
  'pill':       ['💊'],
  'folder':     ['📁', '📂', '🗂️'],
  'book':       ['📚', '📖', '📕', '📗', '📘', '📙'],
  'note':       ['📝', '🗒️', '📋'],
  'hospital':   ['🏥', '🚑', '⚕️'],
  'microscope': ['🔬'],
  'dna':        ['🧬'],
  'bacteria':   ['🦠'],
  'stethoscope':['🩺'],
  'xray':       ['🩻'],
  'syringe':    ['💉'],
  'bandage':    ['🩹'],
  'crutch':     ['🩼'],
  'trophy':     ['🏆'],
  'star':       ['⭐', '🌟'],
  'warning':    ['⚠️'],
  'check':      ['✅'],
};

class _EmojiCategory {
  const _EmojiCategory({
    required this.label,
    required this.icon,
    required this.emojis,
  });
  final String label;
  final String icon;
  final List<String> emojis;
}

// ─── Trigger button ───────────────────────────────────────────────────────────

/// A rounded square showing the current emoji with a pencil overlay.
/// Tapping opens [MedicalEmojiPicker] as a bottom sheet.
class EmojiPickerButton extends StatelessWidget {
  const EmojiPickerButton({
    super.key,
    required this.emoji,
    required this.onChanged,
    this.size = 52,
  });

  final String emoji;
  final ValueChanged<String> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => MedicalEmojiPicker.show(
        context: context,
        initialEmoji: emoji,
        onEmojiSelected: onChanged,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withAlpha(80)),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
          ),
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.edit_rounded, size: 11, color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Picker bottom sheet ──────────────────────────────────────────────────────

class MedicalEmojiPicker extends StatefulWidget {
  const MedicalEmojiPicker({
    super.key,
    required this.initialEmoji,
    required this.onEmojiSelected,
  });

  final String initialEmoji;
  final ValueChanged<String> onEmojiSelected;

  /// Opens the picker as a modal bottom sheet (55% screen height).
  static Future<void> show({
    required BuildContext context,
    required String initialEmoji,
    required ValueChanged<String> onEmojiSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MedicalEmojiPicker(
        initialEmoji: initialEmoji,
        onEmojiSelected: onEmojiSelected,
      ),
    );
  }

  @override
  State<MedicalEmojiPicker> createState() => _MedicalEmojiPickerState();
}

class _MedicalEmojiPickerState extends State<MedicalEmojiPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialEmoji;
    _tabCtrl = TabController(length: _kCategories.length, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _searchResults {
    if (_searchQuery.isEmpty) return const [];
    // Keyword-first match
    for (final entry in _kKeywords.entries) {
      if (entry.key.contains(_searchQuery) ||
          _searchQuery.contains(entry.key)) {
        return entry.value;
      }
    }
    // Fallback: search across all emojis' category labels
    final results = <String>[];
    for (final cat in _kCategories) {
      if (cat.label.toLowerCase().contains(_searchQuery)) {
        results.addAll(cat.emojis);
      }
    }
    return results.isEmpty ? _kAllEmojis : results;
  }

  void _pick(String emoji) {
    widget.onEmojiSelected(emoji);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final height = MediaQuery.of(context).size.height * 0.55;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choose Emoji',
              style:
                  tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),

          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search (heart, lung, folder…)',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: _searchCtrl.clear,
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Tabs (hidden while searching) ─────────────────────────────
          if (_searchQuery.isEmpty)
            TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              tabs: _kCategories
                  .map(
                    (c) => Tab(
                      height: 36,
                      child: Text(
                        '${c.icon} ${c.label}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const Divider(height: 1),

          // ── Grid ─────────────────────────────────────────────────────────
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _EmojiGrid(
                    emojis: _searchResults,
                    selected: _selected,
                    onTap: _pick,
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: _kCategories
                        .map(
                          (cat) => _EmojiGrid(
                            emojis: cat.emojis,
                            selected: _selected,
                            onTap: _pick,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Grid ─────────────────────────────────────────────────────────────────────

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({
    required this.emojis,
    required this.selected,
    required this.onTap,
  });

  final List<String> emojis;
  final String selected;
  final ValueChanged<String> onTap;

  static const _teal = Color(0xFF006D77);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, i) {
        final e = emojis[i];
        final isSelected = e == selected;
        return GestureDetector(
          onTap: () => onTap(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected ? _teal : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(e, style: const TextStyle(fontSize: 24)),
          ),
        );
      },
    );
  }
}
