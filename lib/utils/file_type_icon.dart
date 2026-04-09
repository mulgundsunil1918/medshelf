import 'package:flutter/material.dart';

import '../models/med_file.dart';

// ─── File-type icon helper ────────────────────────────────────────────────────
//
// A single place that maps MedFile → distinct Icon (with colour).
// Import this wherever you render file tiles: SearchScreen, AllFilesScreen,
// FileListScreen, etc.

/// Returns a distinct [Icon] widget for the given [file].
///
/// • PDF    → red    picture_as_pdf
/// • PPT    → orange slideshow
/// • Word   → blue   description
/// • Excel  → green  table_chart
/// • Image  → green  image
/// • Video  → purple play_circle_filled
/// • Note   → amber  sticky_note_2
/// • Other  → grey   insert_drive_file
Icon getFileIcon(MedFile file) {
  if (file.isNote) {
    return Icon(Icons.sticky_note_2, color: Colors.amber[700]);
  }
  switch (file.fileType) {
    case FileType.pdf:
      return Icon(Icons.picture_as_pdf, color: Colors.red[700]);
    case FileType.image:
      return Icon(Icons.image, color: Colors.green[600]);
    case FileType.video:
      return Icon(Icons.play_circle_filled, color: Colors.purple[600]);
    case FileType.document:
      final lower = file.name.toLowerCase();
      if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
        return Icon(Icons.slideshow, color: Colors.orange[700]);
      }
      if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
        return Icon(Icons.description, color: Colors.blue[700]);
      }
      if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
        return Icon(Icons.table_chart, color: Colors.green[800]);
      }
      return Icon(Icons.insert_drive_file, color: Colors.grey[600]);
    case FileType.other:
      return Icon(Icons.insert_drive_file, color: Colors.grey[600]);
  }
}

/// Matching background / accent colour for the icon container.
Color getFileIconColor(MedFile file) {
  if (file.isNote) return Colors.amber[700]!;
  switch (file.fileType) {
    case FileType.pdf:
      return Colors.red[700]!;
    case FileType.image:
      return Colors.green[600]!;
    case FileType.video:
      return Colors.purple[600]!;
    case FileType.document:
      final lower = file.name.toLowerCase();
      if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
        return Colors.orange[700]!;
      }
      if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
        return Colors.blue[700]!;
      }
      if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
        return Colors.green[800]!;
      }
      return Colors.grey[600]!;
    case FileType.other:
      return Colors.grey[600]!;
  }
}

/// Short uppercase badge label (e.g. "PDF", "PPT", "WORD", "NOTE").
String getFileTypeBadge(MedFile file) {
  if (file.isNote) return 'NOTE';
  switch (file.fileType) {
    case FileType.pdf:
      return 'PDF';
    case FileType.image:
      return 'IMAGE';
    case FileType.video:
      return 'VIDEO';
    case FileType.document:
      final lower = file.name.toLowerCase();
      if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return 'PPT';
      if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'WORD';
      if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return 'EXCEL';
      return 'DOC';
    case FileType.other:
      return 'FILE';
  }
}

/// Returns [true] when [file] matches the given search-screen filter label.
///
/// Labels: 'All' | 'PDF' | 'PPT' | 'Image' | 'Video' | 'Word' | 'Notes'
bool fileMatchesFilter(MedFile file, String filter) {
  switch (filter) {
    case 'All':
      return true;
    case 'Notes':
      return file.isNote;
    case 'PDF':
      return file.fileType == FileType.pdf && !file.isNote;
    case 'Image':
      return file.fileType == FileType.image;
    case 'Video':
      return file.fileType == FileType.video;
    case 'PPT':
      final lower = file.name.toLowerCase();
      return lower.endsWith('.ppt') || lower.endsWith('.pptx');
    case 'Word':
      final lower = file.name.toLowerCase();
      return lower.endsWith('.doc') || lower.endsWith('.docx');
    case 'Excel':
      final lower = file.name.toLowerCase();
      return lower.endsWith('.xls') || lower.endsWith('.xlsx');
    default:
      return true;
  }
}
