import 'dart:convert';

/// Decodes Quill Delta JSON into a plain-text snippet for list previews.
///
/// Notes are saved as Delta JSON, e.g.:
///   [{"insert":"Hello\n","attributes":{"bold":true}}, {"insert":"World"}]
///
/// This class extracts just the text so file-list rows can show a preview
/// without depending on flutter_quill.
class NoteText {
  NoteText._();

  /// Returns a plain-text preview (max [maxLength] chars) from a raw
  /// description string that may be Quill Delta JSON or legacy plain text.
  /// Returns empty string if [raw] is null / empty / not parseable.
  static String snippet(String? raw, {int maxLength = 120}) {
    if (raw == null || raw.trim().isEmpty) return '';

    final trimmed = raw.trim();

    // Try to decode as Quill Delta JSON (starts with '[')
    if (trimmed.startsWith('[')) {
      try {
        final List<dynamic> ops = json.decode(trimmed) as List<dynamic>;
        final buffer = StringBuffer();
        for (final op in ops) {
          if (op is Map<String, dynamic>) {
            final insert = op['insert'];
            if (insert is String) {
              buffer.write(insert);
            }
          }
          if (buffer.length >= maxLength) break;
        }
        final text = buffer.toString().replaceAll('\n', ' ').trim();
        if (text.isEmpty) return '';
        return text.length > maxLength ? '${text.substring(0, maxLength)}…' : text;
      } catch (_) {
        // Fall through to plain-text path
      }
    }

    // Legacy plain text — return as-is (trimmed)
    final plain = trimmed.replaceAll('\n', ' ');
    return plain.length > maxLength ? '${plain.substring(0, maxLength)}…' : plain;
  }
}
