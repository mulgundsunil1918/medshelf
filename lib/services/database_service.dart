import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/med_file.dart';
import '../models/topic.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'medshelf.db');
    return openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE files (
            id           TEXT PRIMARY KEY,
            name         TEXT,
            path         TEXT,
            topicId      TEXT,
            fileType     INTEGER,
            sizeBytes    INTEGER,
            savedAt      TEXT,
            notes        TEXT,
            isBookmarked INTEGER DEFAULT 0,
            description  TEXT,
            isNote       INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE custom_topics (
            id       TEXT PRIMARY KEY,
            name     TEXT,
            parentId TEXT,
            emoji    TEXT DEFAULT "📁",
            isCustom INTEGER DEFAULT 1
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE files ADD COLUMN isBookmarked INTEGER DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE files ADD COLUMN description TEXT',
          );
          await db.execute(
            'ALTER TABLE files ADD COLUMN isNote INTEGER DEFAULT 0',
          );
        }
      },
    );
  }

  // ─── Serialization helpers ───────────────────────────────────────────────────

  Map<String, dynamic> _fileToMap(MedFile file) => {
        'id': file.id?.toString(),
        'name': file.name,
        'path': file.path,
        'topicId': file.topicId,
        'fileType': file.fileType.index,
        'sizeBytes': file.sizeBytes,
        'savedAt': file.savedAt.toIso8601String(),
        'notes': file.notes,
        'isBookmarked': file.isBookmarked ? 1 : 0,
        'description': file.description,
        'isNote': file.isNote ? 1 : 0,
      };

  MedFile _mapToFile(Map<String, dynamic> map) => MedFile(
        id: map['id'] != null ? int.tryParse(map['id'] as String) : null,
        name: map['name'] as String,
        path: map['path'] as String,
        topicId: map['topicId'] as String,
        fileType: FileType.values[map['fileType'] as int],
        sizeBytes: map['sizeBytes'] as int,
        savedAt: DateTime.parse(map['savedAt'] as String),
        notes: map['notes'] as String?,
        isBookmarked: (map['isBookmarked'] as int? ?? 0) == 1,
        description: map['description'] as String?,
        isNote: (map['isNote'] as int? ?? 0) == 1,
      );

  // ─── Files ───────────────────────────────────────────────────────────────────

  Future<void> saveFile(MedFile file) async {
    final db = await database;
    await db.insert(
      'files',
      _fileToMap(file),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing file record in place, looked up by [MedFile.path].
  /// Use this when saving edits to an existing note to avoid duplicate rows.
  Future<void> updateFile(MedFile file) async {
    final db = await database;
    await db.update(
      'files',
      _fileToMap(file),
      where: 'path = ?',
      whereArgs: [file.path],
    );
  }

  Future<List<MedFile>> getFilesForTopic(String topicId) async {
    final db = await database;
    final rows = await db.query(
      'files',
      where: 'topicId = ?',
      whereArgs: [topicId],
      orderBy: 'savedAt DESC',
    );
    return rows.map(_mapToFile).toList();
  }

  Future<List<MedFile>> searchFiles(String query) async {
    final db = await database;
    final pattern = '%$query%';
    final rows = await db.query(
      'files',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: 'savedAt DESC',
    );
    return rows.map(_mapToFile).toList();
  }

  Future<List<MedFile>> getAllFiles() async {
    final db = await database;
    final rows = await db.query('files', orderBy: 'savedAt DESC');
    return rows.map(_mapToFile).toList();
  }

  /// Delete a file record matched by its on-disk [filePath].
  Future<void> deleteFile(String filePath) async {
    final db = await database;
    final rows =
        await db.delete('files', where: 'path = ?', whereArgs: [filePath]);
    debugPrint('DB: deleted $rows row(s) for path=$filePath');
  }

  /// Delete a file record by its integer [id].
  /// Note: the `id` column is stored as TEXT so we convert before comparing.
  Future<void> deleteFileById(int id) async {
    final db = await database;
    final rows = await db.delete(
      'files',
      where: 'id = ?',
      whereArgs: [id.toString()],
    );
    debugPrint('DB: deleted $rows row(s) for file id=$id');
  }

  /// Update [topicId] (and optionally [newPath]) for the record whose
  /// current on-disk path is [oldPath].
  Future<void> moveFile(String oldPath, String newTopicId,
      {String? newPath}) async {
    final db = await database;
    final update = <String, dynamic>{'topicId': newTopicId};
    if (newPath != null) update['path'] = newPath;
    await db.update('files', update, where: 'path = ?', whereArgs: [oldPath]);
  }

  /// Toggle the bookmarked flag on the record whose on-disk path is [filePath].
  Future<void> toggleBookmark(String filePath, bool value) async {
    final db = await database;
    await db.update(
      'files',
      {'isBookmarked': value ? 1 : 0},
      where: 'path = ?',
      whereArgs: [filePath],
    );
  }

  Future<List<MedFile>> getNotes() async {
    final db = await database;
    final rows = await db.query(
      'files',
      where: 'isNote = 1',
      orderBy: 'savedAt DESC',
    );
    return rows.map(_mapToFile).toList();
  }

  Future<List<MedFile>> getBookmarkedFiles() async {
    final db = await database;
    final rows = await db.query(
      'files',
      where: 'isBookmarked = 1',
      orderBy: 'savedAt DESC',
    );
    return rows.map(_mapToFile).toList();
  }

  /// Count files directly in [topicId].
  Future<int> getFileCountForTopic(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM files WHERE topicId = ?',
      [topicId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Recursively count files in [topicId] and all its descendant folders.
  Future<int> getFileCountForTopicRecursive(String topicId) async {
    final db = await database;
    int count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM files WHERE topicId = ?', [topicId])) ??
        0;
    final children = await db.query(
      'custom_topics',
      where: 'parentId = ?',
      whereArgs: [topicId],
    );
    for (final c in children) {
      count += await getFileCountForTopicRecursive(c['id'] as String);
    }
    return count;
  }

  /// Count files in [topicIds] (a topic + all its descendants) in one query.
  Future<int> getFileCountForTopics(List<String> topicIds) async {
    if (topicIds.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(topicIds.length, '?').join(', ');
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM files WHERE topicId IN ($placeholders)',
      topicIds,
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // ─── Topic hierarchy helpers ─────────────────────────────────────────────────

  /// Looks up a topic by [id] — checks default topics first, then custom DB topics.
  Future<Topic?> getTopicById(String id) async {
    // Search the hardcoded default tree (BFS).
    final queue = List<Topic>.from(defaultTopics);
    while (queue.isNotEmpty) {
      final t = queue.removeAt(0);
      if (t.id == id) return t;
      queue.addAll(t.children);
    }
    // Fall back to the custom_topics table.
    final db = await database;
    final rows = await db.query('custom_topics', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Topic.fromMap(rows.first);
  }

  /// Returns the ordered list of topic names from root → [topicId].
  /// e.g. ['Pediatrics', 'Neonatology', 'Respiratory System']
  Future<List<String>> getTopicPathNames(String topicId) async {
    final path = <String>[];
    String? current = topicId;
    while (current != null) {
      final topic = await getTopicById(current);
      if (topic == null) break;
      path.insert(0, topic.name);
      current = topic.parentId;
    }
    return path;
  }

  // ─── Custom Topics ───────────────────────────────────────────────────────────

  Future<void> saveCustomTopic(Topic topic) async {
    final db = await database;
    await db.insert(
      'custom_topics',
      topic.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Topic>> getCustomTopics() async {
    final db = await database;
    final rows = await db.query('custom_topics');
    return rows.map(Topic.fromMap).toList();
  }

  Future<void> deleteCustomTopic(String id) async {
    final db = await database;
    await db.delete('custom_topics', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('files');
    await db.delete('custom_topics');
  }

  /// Move all files belonging to any id in [allIds] to 'unsorted', then
  /// delete all matching custom-topic rows. Works for cascade-delete of a
  /// topic and all its descendants.
  Future<void> deleteTopicAndChildren(
      String id, List<String> allIds) async {
    if (allIds.isEmpty) return;
    final db = await database;
    final placeholders = allIds.map((_) => '?').join(',');

    // Relocate files to unsorted
    await db.rawUpdate(
      'UPDATE files SET topicId = ? WHERE topicId IN ($placeholders)',
      ['unsorted', ...allIds],
    );

    // Delete all custom topic rows
    await db.rawDelete(
      'DELETE FROM custom_topics WHERE id IN ($placeholders)',
      allIds,
    );
  }
}
