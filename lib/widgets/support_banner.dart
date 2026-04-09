import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_colors.dart';
import '../utils/constants.dart';

/// Small warm banner shown on the HomeScreen.
/// Tapping it opens [kSupportLink]; the X button dismisses for the session.
class SupportBanner extends StatefulWidget {
  const SupportBanner({super.key});

  @override
  State<SupportBanner> createState() => _SupportBannerState();
}

class _SupportBannerState extends State<SupportBanner> {
  bool _dismissed = false;

  Future<void> _open() async {
    final uri = Uri.parse(kSupportLink);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      child: _dismissed
          ? const SizedBox.shrink()
          : _BannerContent(
              onTap:    _open,
              onDismiss: () => setState(() => _dismissed = true),
            ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.onTap, required this.onDismiss});
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.coral.withAlpha(70),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('☕', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Like MedShelf? Buy me a chai!',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to support the developer 🙏',
                    style: TextStyle(
                      color:    Colors.white.withAlpha(210),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Dismiss button
            GestureDetector(
              onTap:    onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size:  18,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
