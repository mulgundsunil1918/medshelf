import 'package:intl/intl.dart';

enum FileType { pdf, image, video, document, other }

class MedFile {
  final int? id;
  final String name;
  final String path;
  final String topicId;
  final FileType fileType;
  final int sizeBytes;
  final DateTime savedAt;
  final String? notes;
  final bool isBookmarked;

  /// User-written description or note about this file.
  final String? description;

  /// True when this entry is a quick text note (not a shared/imported file).
  final bool isNote;

  const MedFile({
    this.id,
    required this.name,
    required this.path,
    required this.topicId,
    required this.fileType,
    required this.sizeBytes,
    required this.savedAt,
    this.notes,
    this.isBookmarked = false,
    this.description,
    this.isNote = false,
  });

  // ─── Type resolution ────────────────────────────────────────────────────────

  static FileType typeFromExtension(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    if ({'pdf'}.contains(e)) return FileType.pdf;
    if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'}
        .contains(e)) { return FileType.image; }
    if ({'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'flv'}.contains(e)) {
      return FileType.video;
    }
    if ({'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'rtf', 'odt'}
        .contains(e)) { return FileType.document; }
    return FileType.other;
  }

  // ─── Helper getters ─────────────────────────────────────────────────────────

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate => DateFormat('MMM d, yyyy').format(savedAt);

  String get fileTypeIcon {
    if (isNote) return '📝';
    switch (fileType) {
      case FileType.pdf:
        return '📄';
      case FileType.image:
        return '🖼️';
      case FileType.video:
        return '🎬';
      case FileType.document:
        return '📝';
      case FileType.other:
        return '📎';
    }
  }

  // ─── SQLite serialization ───────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'path': path,
        'topicId': topicId,
        'fileType': fileType.name,
        'sizeBytes': sizeBytes,
        'savedAt': savedAt.toIso8601String(),
        'notes': notes,
        'isBookmarked': isBookmarked ? 1 : 0,
        'description': description,
        'isNote': isNote ? 1 : 0,
      };

  factory MedFile.fromMap(Map<String, dynamic> map) => MedFile(
        id: map['id'] as int?,
        name: map['name'] as String,
        path: map['path'] as String,
        topicId: map['topicId'] as String,
        fileType: FileType.values.firstWhere(
          (e) => e.name == map['fileType'],
          orElse: () => FileType.other,
        ),
        sizeBytes: map['sizeBytes'] as int,
        savedAt: DateTime.parse(map['savedAt'] as String),
        notes: map['notes'] as String?,
        isBookmarked: (map['isBookmarked'] as int? ?? 0) == 1,
        description: map['description'] as String?,
        isNote: (map['isNote'] as int? ?? 0) == 1,
      );

  MedFile copyWith({
    int? id,
    String? name,
    String? path,
    String? topicId,
    FileType? fileType,
    int? sizeBytes,
    DateTime? savedAt,
    String? notes,
    bool? isBookmarked,
    String? description,
    bool? isNote,
  }) =>
      MedFile(
        id: id ?? this.id,
        name: name ?? this.name,
        path: path ?? this.path,
        topicId: topicId ?? this.topicId,
        fileType: fileType ?? this.fileType,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        savedAt: savedAt ?? this.savedAt,
        notes: notes ?? this.notes,
        isBookmarked: isBookmarked ?? this.isBookmarked,
        description: description ?? this.description,
        isNote: isNote ?? this.isNote,
      );
}
