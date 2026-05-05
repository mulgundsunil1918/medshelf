import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/med_file.dart';
import '../models/topic.dart';
import 'database_service.dart';

class FileStorageService {
  FileStorageService._();
  static final FileStorageService instance = FileStorageService._();

  // ─── Directory helpers ────────────────────────────────────────────────────

  Future<String> _baseDir() async {
    // iOS / macOS: apps are sandboxed. The only writable location that
    // also shows up in the Files app is the app's own Documents folder
    // (because Info.plist sets UIFileSharingEnabled and
    // LSSupportsOpeningDocumentsInPlace).
    if (Platform.isIOS || Platform.isMacOS) {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'MedShelf'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }

    // Android: try to write to /storage/emulated/0/MedShelf so the user
    // can see the folder via any Files app. Falls back to the app's
    // private external folder if MANAGE_EXTERNAL_STORAGE was denied.
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final rootPath = extDir.path.split('Android')[0]; // ends with '/'
        final medshelfDir = Directory('${rootPath}MedShelf');
        if (!await medshelfDir.exists()) {
          await medshelfDir.create(recursive: true);
        }
        return medshelfDir.path;
      }
    } catch (_) {}

    final fallback = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(fallback.path, 'MedShelf'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> _topicDir(String topicId) async {
    final base = await _baseDir();
    final segments = await DatabaseService.instance.getTopicPathNames(topicId);
    final folderPath = segments.isEmpty
        ? topicId
        : segments
            .map((s) => s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim())
            .join('/');
    final dir = Directory('$base/$folderPath');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Public — make sure the physical folder for [topicId] exists on disk.
  /// Called after a topic is created so the user can see it in their Files
  /// app immediately, even before any file is imported into it.
  Future<String> ensureTopicDir(String topicId) => _topicDir(topicId);

  /// Permanently delete the physical folder for [topicId] and everything
  /// inside it (files + subfolders). Best-effort — returns whether the
  /// folder is verifiably gone afterwards.
  Future<bool> deleteTopicDir(String topicId) async {
    try {
      final base = await _baseDir();
      final segments =
          await DatabaseService.instance.getTopicPathNames(topicId);
      if (segments.isEmpty) return true; // nothing on disk to remove
      final folderPath = segments
          .map((s) => s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim())
          .join('/');
      final dir = Directory('$base/$folderPath');
      if (!await dir.exists()) return true;
      await dir.delete(recursive: true);
      return !await dir.exists();
    } catch (e) {
      debugPrint('Storage: deleteTopicDir error=$e');
      return false;
    }
  }

  // ─── Core operations ──────────────────────────────────────────────────────

  Future<MedFile> storeFile({
    required String sourcePath,
    required Topic topic,
    required String customName,
  }) async {
    final source = File(sourcePath);
    final ext = p.extension(sourcePath); // includes leading dot, e.g. ".pdf"
    final cleanBase = _sanitizeFileName(customName);

    final destDir = await _topicDir(topic.id);
    String destName = '$cleanBase$ext';
    String destPath = p.join(destDir, destName);

    // Append timestamp if a file with the same name already exists
    if (await File(destPath).exists()) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      destName = '${cleanBase}_$ts$ext';
      destPath = p.join(destDir, destName);
    }

    final copied = await source.copy(destPath);
    final stat = await copied.stat();

    return MedFile(
      name: destName,
      path: copied.path,
      topicId: topic.id,
      fileType: MedFile.typeFromExtension(ext.replaceAll('.', '')),
      sizeBytes: stat.size,
      savedAt: DateTime.now(),
    );
  }

  Future<MedFile> createNote({
    required String title,
    required String content,
    required Topic topic,
  }) async {
    final cleanTitle = _sanitizeFileName(title);
    final destDir = await _topicDir(topic.id);
    String fileName = '$cleanTitle.txt';
    String filePath = p.join(destDir, fileName);

    // Avoid collision
    if (await File(filePath).exists()) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      fileName = '${cleanTitle}_$ts.txt';
      filePath = p.join(destDir, fileName);
    }

    await File(filePath).writeAsString(content);
    final stat = await File(filePath).stat();

    // Note: we deliberately do NOT pass `content` as `description` —
    // notes save Quill Delta JSON to disk, and stuffing the raw JSON
    // into description leaks into list-row previews. Callers that want
    // a preview snippet should derive one from the Delta themselves.
    return MedFile(
      name: title,
      path: filePath,
      topicId: topic.id,
      fileType: FileType.document,
      sizeBytes: stat.size,
      savedAt: DateTime.now(),
      isNote: true,
    );
  }

  Future<String> moveFile(String currentPath, String newTopicId) async {
    final source = File(currentPath);
    final destDir = await _topicDir(newTopicId);
    final fileName = p.basename(currentPath);
    String destPath = p.join(destDir, fileName);

    // Avoid overwriting an existing file at the destination
    if (await File(destPath).exists()) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final base = p.basenameWithoutExtension(fileName);
      final ext = p.extension(fileName);
      destPath = p.join(destDir, '${base}_$ts$ext');
    }

    await source.rename(destPath);
    return destPath;
  }

  /// Legacy — kept for backward compatibility.
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Delete the physical file at [filePath] from device storage.
  ///
  /// Returns `true` only when the file is verifiably gone afterwards
  /// (deleted now, or already missing). Returns `false` if an error
  /// occurred and the file still exists on disk — callers should keep
  /// the DB record in that case so app and disk stay in sync.
  Future<bool> deleteFileFromStorage(String filePath) async {
    try {
      final file = File(filePath);
      final existsBefore = await file.exists();
      debugPrint('Storage: file exists=$existsBefore  path=$filePath');
      if (!existsBefore) {
        debugPrint('Storage: file already missing — treating as deleted');
        return true;
      }
      await file.delete();
      // Verify the OS actually removed it (catches silent permission /
      // I/O failures that don't throw).
      final stillExists = await file.exists();
      if (stillExists) {
        debugPrint('Storage: delete returned but file still on disk');
        return false;
      }
      debugPrint('Storage: deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Storage: delete error=$e');
      // Best-effort: even if delete threw, the file might be gone now.
      try {
        return !await File(filePath).exists();
      } catch (_) {
        return false;
      }
    }
  }

  /// Returns whether [filePath] currently exists on disk. Used to keep
  /// the DB in sync with the filesystem (e.g. when the user deletes a
  /// file via their Files app).
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (_) {
      return false;
    }
  }

  Future<int> getTotalStorageUsed() async {
    final base = await _baseDir();
    final dir = Directory(base);
    if (!await dir.exists()) return 0;

    int total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final stat = await entity.stat();
        total += stat.size;
      }
    }
    return total;
  }

  // ─── Filename sanitization ────────────────────────────────────────────────

  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
}
