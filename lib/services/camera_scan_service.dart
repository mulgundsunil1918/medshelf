import 'dart:io';
import 'dart:typed_data';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Wraps cunning_document_scanner (Google ML Kit on Android, VisionKit
/// on iOS). Returns ONE file path the rest of the app can save to its
/// vault: a JPG for single-page captures, a stitched PDF for multi-page
/// captures, or null if the user cancelled.
class CameraScanService {
  CameraScanService._();
  static final CameraScanService instance = CameraScanService._();

  /// Open the system document-scanner UI and return the captured page(s)
  /// as a single file. Single-page → JPG, multi-page → stitched PDF.
  /// Returns `null` if the user cancelled out of the scanner.
  Future<String?> scanDocument({int maxPages = 10}) async {
    final pages = await CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      isGalleryImportAllowed: false,
    );
    if (pages == null || pages.isEmpty) return null;
    if (pages.length == 1) return pages.first;
    return _stitchToPdf(pages);
  }

  /// Combine [imagePaths] into a single A4 PDF in the temp directory.
  /// The returned path lives until the OS clears the cache.
  Future<String> _stitchToPdf(List<String> imagePaths) async {
    final doc = pw.Document();
    for (final pathStr in imagePaths) {
      final bytes = await File(pathStr).readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final tmp = await getTemporaryDirectory();
    final fname = 'Scan-${DateTime.now().millisecondsSinceEpoch}.pdf';
    final out = File(p.join(tmp.path, fname));
    final Uint8List pdfBytes = await doc.save();
    await out.writeAsBytes(pdfBytes);
    return out.path;
  }
}
