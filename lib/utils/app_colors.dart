import 'package:flutter/material.dart';

import '../models/med_file.dart';

abstract final class AppColors {
  // ── MedShelf brand palette ─────────────────────────────────────────────────
  static const Color teal = Color(0xFF006D77);
  static const Color tealDark = Color(0xFF003D45);
  static const Color coral = Color(0xFFE8835A);

  // ── File-type badge colours ────────────────────────────────────────────────
  static const Color pdfColor = Color(0xFFE53935);
  static const Color imageColor = Color(0xFF43A047);
  static const Color videoColor = Color(0xFF8E24AA);
  static const Color documentColor = Color(0xFF1E88E5);
  static const Color otherColor = Color(0xFF757575);

  static Color getColorForFileType(FileType type) => switch (type) {
        FileType.pdf => pdfColor,
        FileType.image => imageColor,
        FileType.video => videoColor,
        FileType.document => documentColor,
        FileType.other => otherColor,
      };

  // ── Book shelf colors (splash screen) ─────────────────────────────────────
  static const List<Color> bookColors = [
    Color(0xFFFF7B6B),
    Color(0xFF58D9C0),
    Color(0xFFFFB733),
    Color(0xFF8BAFF0),
    Color(0xFFC3ADEB),
    Color(0xFFFF7BAA),
    Color(0xFF5ECFA5),
  ];
}
