import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_colors.dart';
import '../utils/constants.dart';

/// "Support the developer" dialog. Call [SupportPopup.show] from anywhere
/// you have a [BuildContext].
class SupportPopup extends StatelessWidget {
  const SupportPopup({super.key});

  /// Convenience: show the popup as a dialog.
  static void show(BuildContext context) {
    showDialog<void>(
      context:             context,
      barrierDismissible:  true,
      builder:             (_) => const SupportPopup(),
    );
  }

  Future<void> _openLink() async {
    final uri = Uri.parse(kSupportLink);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          const Text('💛', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Enjoying MedShelf?',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        'I built this app with months of effort and kept it completely free. '
        'It costs me for server maintenance, Play Store and App Store fees. '
        'If MedShelf helps your practice, please consider supporting the '
        'developer 🙏',
        style: tt.bodyMedium?.copyWith(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:     const Text('Maybe later'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.coral,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            _openLink();
          },
          child: const Text(
            'Support the Developer',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
