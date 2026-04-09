import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../models/med_file.dart';

class FileThumbnail extends StatefulWidget {
  const FileThumbnail({super.key, required this.file, this.size = 56});

  final MedFile file;
  final double size;

  @override
  State<FileThumbnail> createState() => _FileThumbnailState();
}

class _FileThumbnailState extends State<FileThumbnail> {
  // Shared across all instances so PDFs aren't re-rendered.
  static final Map<int, Uint8List> _cache = {};

  Uint8List? _pdfBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_isPdf && widget.file.id != null) {
      final cached = _cache[widget.file.id];
      if (cached != null) {
        _pdfBytes = cached;
      } else {
        _renderPdf();
      }
    }
  }

  bool get _isPdf => widget.file.fileType == FileType.pdf && !widget.file.isNote;

  Future<void> _renderPdf() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      final page = await doc.getPage(1);
      final rendered = await page.render(
        width: 120,
        height: 120,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await doc.close();
      if (rendered?.bytes != null && mounted) {
        final bytes = rendered!.bytes;
        if (widget.file.id != null) _cache[widget.file.id!] = bytes;
        setState(() {
          _pdfBytes = bytes;
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final r = BorderRadius.circular(10);

    // IMAGE
    if (widget.file.fileType == FileType.image && !widget.file.isNote) {
      final lower = widget.file.name.toLowerCase();
      if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.bmp')) {
        return ClipRRect(
          borderRadius: r,
          child: Image.file(
            File(widget.file.path),
            width: s,
            height: s,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _iconBox(
              s, r,
              Colors.green[600]!.withAlpha(30),
              Icons.image,
              Colors.green[600]!,
            ),
          ),
        );
      }
    }

    // PDF
    if (_isPdf) {
      if (_pdfBytes != null) {
        return ClipRRect(
          borderRadius: r,
          child: Image.memory(
            _pdfBytes!,
            width: s,
            height: s,
            fit: BoxFit.cover,
          ),
        );
      }
      // Shimmer placeholder while loading
      return ClipRRect(
        borderRadius: r,
        child: Container(
          width: s,
          height: s,
          color: Colors.grey[300],
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(Icons.picture_as_pdf,
                  color: Colors.red[700], size: s * 0.55),
        ),
      );
    }

    final lower = widget.file.name.toLowerCase();

    // PPT / PPTX
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return _labelBox(s, r, const Color(0xFFD04A02),
          Icons.slideshow, 'PPT');
    }

    // DOC / DOCX
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return _labelBox(s, r, const Color(0xFF2B5797),
          Icons.description, 'DOC');
    }

    // XLS / XLSX
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return _labelBox(s, r, const Color(0xFF1D6F42),
          Icons.table_chart, 'XLS');
    }

    // Video
    if (widget.file.fileType == FileType.video) {
      return ClipRRect(
        borderRadius: r,
        child: Container(
          width: s,
          height: s,
          color: Colors.black87,
          alignment: Alignment.center,
          child: Icon(Icons.play_circle_filled,
              color: const Color(0xFFE8835A), size: s * 0.6),
        ),
      );
    }

    // Note / TXT
    if (widget.file.isNote ||
        lower.endsWith('.txt') ||
        lower.endsWith('.rtf')) {
      return ClipRRect(
        borderRadius: r,
        child: Container(
          width: s,
          height: s,
          color: const Color(0xFF006B74),
          alignment: Alignment.center,
          child: Icon(Icons.notes, color: Colors.white, size: s * 0.55),
        ),
      );
    }

    // Default
    return _iconBox(
      s, r, Colors.grey[300]!, Icons.insert_drive_file, Colors.grey[600]!);
  }

  Widget _labelBox(
      double s, BorderRadius r, Color bg, IconData icon, String label) {
    return ClipRRect(
      borderRadius: r,
      child: Container(
        width: s,
        height: s,
        color: bg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: s * 0.45),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(
      double s, BorderRadius r, Color bg, IconData icon, Color iconColor) {
    return ClipRRect(
      borderRadius: r,
      child: Container(
        width: s,
        height: s,
        color: bg,
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: s * 0.55),
      ),
    );
  }
}
