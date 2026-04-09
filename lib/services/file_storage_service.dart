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
    try {
      // getExternalStorageDirectory() returns something like:
      //   /storage/emulated/0/Android/data/com.medshelf.medshelf/files
      // We navigate UP past the "Android/" subfolder to reach
      //   /storage/emulated/0/
      // then create /storage/emulated/0/MedShelf/ — fully visible in Files app.
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

    // Fallback: app-specific external storage (always accessible, no permission needed)
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

    return MedFile(
      name: title,
      path: filePath,
      topicId: topic.id,
      fileType: FileType.document,
      sizeBytes: stat.size,
      savedAt: DateTime.now(),
      description: content,
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
  /// Returns [true] whether the file was deleted or was already missing
  /// (both are clean outcomes). Returns [false] only on an unexpected error.
  Future<bool> deleteFileFromStorage(String filePath) async {
    try {
      final file = File(filePath);
      final exists = await file.exists();
      debugPrint('Storage: file exists=$exists  path=$filePath');
      if (exists) {
        await file.delete();
        debugPrint('Storage: deleted successfully');
      } else {
        debugPrint('Storage: file already missing — treating as deleted');
      }
      return true;
    } catch (e) {
      debugPrint('Storage: delete error=$e');
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
