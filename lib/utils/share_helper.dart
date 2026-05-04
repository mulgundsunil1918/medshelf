import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/med_file.dart';

/// Centralised "share this file" action used by the visible share button
/// on every file row plus the bottom-sheet action menus.
class ShareHelper {
  ShareHelper._();

  static Future<void> shareFile(BuildContext context, MedFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    final f = File(file.path);
    if (!await f.exists()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('File no longer exists on disk.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: file.name,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not share this file.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
