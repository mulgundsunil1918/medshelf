import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/topic.dart';
import 'database_service.dart';
import 'file_storage_service.dart';

class TopicService extends ChangeNotifier {
  TopicService._();
  static final TopicService instance = TopicService._();

  final _db = DatabaseService.instance;

  List<Topic> _topics = [];
  final Map<String, Topic> _flatMap = {};

  static const String _kDeletedTopicIds = 'deleted_default_topic_ids';

  /// Default root specialty IDs that should be hidden after onboarding.
  /// The 'unsorted' topic is intentionally excluded — it is always kept.
  static const List<String> _kDefaultRootsToHide = [
    'peds', 'im', 'surg', 'obgyn', 'em', 'pharma', 'research',
  ];

  // ─── Load ─────────────────────────────────────────────────────────────────

  Future<void> loadTopics() async {
    // Deep-copy so we never mutate the shared defaultTopics global.
    _topics = defaultTopics.map((t) => _deepCopy(t, depth: 0)).toList();
    _rebuildFlatMap();

    // Remove default topics that the user previously deleted
    final prefs = await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_kDeletedTopicIds) ?? [];
    for (final id in deleted) {
      _removeNode(id);
    }
    if (deleted.isNotEmpty) _rebuildFlatMap();

    final customs = await _db.getCustomTopics();
    _mergeCustomTopics(customs);

    notifyListeners();
  }

  Topic _deepCopy(Topic t, {required int depth}) => Topic(
        id: t.id,
        name: t.name,
        parentId: t.parentId,
        emoji: t.emoji,
        depth: depth,
        children: t.children
            .map((c) => _deepCopy(c, depth: depth + 1))
            .toList(),
        isCustom: t.isCustom,
      );

  /// Inserts custom topics into the tree.
  /// If a custom topic's ID already exists (i.e. it overrides a default topic),
  /// it updates that node in place while preserving its children.
  void _mergeCustomTopics(List<Topic> customs) {
    final unresolved = {for (final t in customs) t.id: t};

    bool progress = true;
    while (progress && unresolved.isNotEmpty) {
      progress = false;
      for (final id in unresolved.keys.toList()) {
        final t = unresolved[id]!;

        // Override an existing node (default topic being renamed/emoji'd)
        if (_flatMap.containsKey(t.id)) {
          final existing = _flatMap[t.id]!;
          final updated = Topic(
            id: t.id,
            name: t.name,
            parentId: t.parentId ?? existing.parentId,
            emoji: t.emoji,
            depth: existing.depth,
            children: existing.children, // keep the default children
            isCustom: true,
          );
          _replaceNode(t.id, updated);
          progress = true;
          unresolved.remove(id);
        } else if (t.parentId == null || _flatMap.containsKey(t.parentId)) {
          _insertLeaf(t);
          progress = true;
          unresolved.remove(id);
        }
      }
    }

    // Any remaining orphans (parent was deleted) surface at root
    for (final t in unresolved.values) {
      final withDepth = _topicWithDepth(t, 0);
      _topics.add(withDepth);
      _flatMap[t.id] = withDepth;
    }
  }

  /// Insert a topic leaf, computing its depth from the parent already in flatMap.
  void _insertLeaf(Topic t) {
    final parentDepth =
        (t.parentId != null ? _flatMap[t.parentId]?.depth : null) ?? -1;
    final withDepth = _topicWithDepth(t, parentDepth + 1);

    if (t.parentId != null && _flatMap.containsKey(t.parentId)) {
      _flatMap[t.parentId]!.children.add(withDepth);
    } else {
      _topics.add(withDepth);
    }
    _flatMap[t.id] = withDepth;
  }

  Topic _topicWithDepth(Topic t, int depth) => Topic(
        id: t.id,
        name: t.name,
        parentId: t.parentId,
        emoji: t.emoji,
        depth: depth,
        children: t.children,
        isCustom: t.isCustom,
      );

  void _rebuildFlatMap() {
    _flatMap.clear();
    for (final t in _topics) {
      _visitAll(t, (node) => _flatMap[node.id] = node);
    }
  }

  void _visitAll(Topic t, void Function(Topic) fn) {
    fn(t);
    for (final child in t.children) {
      _visitAll(child, fn);
    }
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  List<Topic> get allTopics => List.unmodifiable(_topics);

  List<Topic> get flatTopics => _flatMap.values.toList();

  List<Topic> get rootTopics => List.unmodifiable(_topics);

  Topic? getTopicById(String id) => _flatMap[id];

  List<Topic> getChildren(String parentId) =>
      List.unmodifiable(_flatMap[parentId]?.children ?? const []);

  String getBreadcrumb(String topicId) {
    final parts = <String>[];
    String? currentId = topicId;
    while (currentId != null) {
      final topic = _flatMap[currentId];
      if (topic == null) break;
      parts.insert(0, topic.name);
      currentId = topic.parentId;
    }
    return parts.join(' › ');
  }

  /// Returns all descendant ids (children, grandchildren, etc.) of [id].
  List<String> getAllDescendantIds(String id) {
    final result = <String>[];
    final topic = _flatMap[id];
    if (topic == null) return result;
    _collectDescendants(topic, result);
    return result;
  }

  void _collectDescendants(Topic t, List<String> ids) {
    for (final child in t.children) {
      ids.add(child.id);
      _collectDescendants(child, ids);
    }
  }

  // ─── Write ────────────────────────────────────────────────────────────────

  /// Add a new topic under [parentId] (or at root if null).
  /// Returns the newly created [Topic].
  Future<Topic> addTopic({
    required String name,
    String? parentId,
    String emoji = '📁',
  }) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final topic = Topic(
      id: id,
      name: name,
      parentId: parentId,
      emoji: emoji,
      isCustom: true,
    );
    await _db.saveCustomTopic(topic);
    _insertLeaf(topic);
    notifyListeners();

    // Create the matching physical folder on disk so the user can see it
    // in their Files app immediately. Best-effort — silently ignore I/O
    // errors so a permission issue doesn't block topic creation.
    try {
      await FileStorageService.instance.ensureTopicDir(id);
    } catch (e) {
      debugPrint('TopicService: ensureTopicDir failed for $id: $e');
    }

    return _flatMap[id] ?? topic; // return the inserted node (has correct depth)
  }

  /// Rename ANY topic (default or custom). Persists to DB.
  Future<void> renameTopic(String id, String newName) async {
    final topic = _flatMap[id];
    if (topic == null) return;

    final updated = Topic(
      id: topic.id,
      name: newName,
      parentId: topic.parentId,
      emoji: topic.emoji,
      depth: topic.depth,
      children: topic.children,
      isCustom: true, // mark as custom so it persists
    );
    await _db.saveCustomTopic(updated);
    _replaceNode(id, updated);
    notifyListeners();
  }

  /// Update name and/or emoji in one call. Persists to DB.
  Future<void> updateTopic(String id,
      {String? newName, String? newEmoji}) async {
    if (newName != null) await renameTopic(id, newName);
    if (newEmoji != null) await changeTopicEmoji(id, newEmoji);
  }

  /// Change emoji for ANY topic. Persists to DB.
  Future<void> changeTopicEmoji(String id, String newEmoji) async {
    final topic = _flatMap[id];
    if (topic == null) return;

    final updated = Topic(
      id: topic.id,
      name: topic.name,
      parentId: topic.parentId,
      emoji: newEmoji,
      depth: topic.depth,
      children: topic.children,
      isCustom: true, // mark as custom so it persists
    );
    await _db.saveCustomTopic(updated);
    _replaceNode(id, updated);
    notifyListeners();
  }

  /// Delete ANY topic and ALL its descendants.
  ///
  /// By default this is a **destructive** operation: every file that lives
  /// under [id] (or any of its sub-topics) is permanently removed from
  /// disk and the database, and the matching MedShelf folder tree is
  /// deleted from device storage. Pass [moveFilesToUnsorted] to keep the
  /// files instead — they will be reassigned to the "Unsorted" topic.
  ///
  /// Default topics persist their deletion via SharedPreferences so they
  /// don't come back on the next app launch.
  Future<void> deleteTopic(
    String id, {
    bool moveFilesToUnsorted = false,
  }) async {
    final topic = _flatMap[id];
    if (topic == null) return;

    final descendantIds = getAllDescendantIds(id);
    final allIds = [id, ...descendantIds];

    // 1. Resolve the on-disk folder path NOW, before the DB rows go away
    //    (deleteTopicDir uses the DB to build that path).
    if (!moveFilesToUnsorted) {
      // Permanently delete every physical file inside these topics.
      final files = await _db.getFilesForTopics(allIds);
      for (final f in files) {
        await FileStorageService.instance.deleteFileFromStorage(f.path);
      }
      // Delete the empty MedShelf subtree on disk while the path
      // resolver still works.
      await FileStorageService.instance.deleteTopicDir(id);
    }

    // 2. Update the DB — delete file rows (or move them) + delete topic rows
    await _db.deleteTopicAndChildren(
      id,
      allIds,
      moveFilesToUnsorted: moveFilesToUnsorted,
    );

    // For default topics, persist deletion so they don't reappear on reload
    final defaultIds =
        allIds.where((i) => _flatMap[i]?.isCustom != true).toList();
    if (defaultIds.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_kDeletedTopicIds) ?? [];
      final merged = {...existing, ...defaultIds}.toList();
      await prefs.setStringList(_kDeletedTopicIds, merged);
    }

    _removeNode(id);
    _rebuildFlatMap();
    notifyListeners();
  }

  /// Hides all default specialty folders so only user-created ones show in the
  /// Library. Safe to call multiple times — idempotent.
  Future<void> hideDefaultSpecialties() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = Set<String>.from(
        prefs.getStringList(_kDeletedTopicIds) ?? []);

    // Nothing to do if all roots are already hidden
    if (_kDefaultRootsToHide.every(existing.contains)) return;

    existing.addAll(_kDefaultRootsToHide);
    await prefs.setStringList(_kDeletedTopicIds, existing.toList());

    for (final id in _kDefaultRootsToHide) {
      _removeNode(id);
    }
    _rebuildFlatMap();
    notifyListeners();
  }

  /// Returns true if the topic exists (all topics are editable).
  bool canEdit(String id) => _flatMap.containsKey(id);

  /// Returns true if the topic exists (file-count check happens in the UI).
  bool canDelete(String id) => _flatMap.containsKey(id);

  // ─── Tree-mutation helpers ────────────────────────────────────────────────

  void _replaceNode(String id, Topic replacement) {
    final rootIdx = _topics.indexWhere((t) => t.id == id);
    if (rootIdx != -1) {
      _topics[rootIdx] = replacement;
      _flatMap[id] = replacement;
      return;
    }
    for (final root in _topics) {
      if (_replaceInChildren(root, id, replacement)) return;
    }
  }

  bool _replaceInChildren(Topic parent, String id, Topic replacement) {
    final idx = parent.children.indexWhere((t) => t.id == id);
    if (idx != -1) {
      parent.children[idx] = replacement;
      _flatMap[id] = replacement;
      return true;
    }
    for (final child in parent.children) {
      if (_replaceInChildren(child, id, replacement)) return true;
    }
    return false;
  }

  void _removeNode(String id) {
    _topics.removeWhere((t) => t.id == id);
    for (final root in _topics) {
      _pruneChildren(root, id);
    }
  }

  void _pruneChildren(Topic parent, String id) {
    parent.children.removeWhere((t) => t.id == id);
    for (final child in parent.children) {
      _pruneChildren(child, id);
    }
  }
}
