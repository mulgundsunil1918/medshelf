import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/onboarding_service.dart';
import '../services/permission_service.dart';
import 'main_shell.dart';
import 'specialty_onboarding_screen.dart';

const _kTeal  = Color(0xFF006B74);
const _kTealDark = Color(0xFF003D45);

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  Future<void> _handleAllow(BuildContext context) async {
    final granted =
        await PermissionService.instance.requestStoragePermission();
    await OnboardingService.instance.setPermissionExplained();

    if (!context.mounted) return;

    if (granted) {
      _navigateNext(context);
    } else {
      _showDeniedDialog(context);
    }
  }

  Future<void> _navigateNext(BuildContext context) async {
    final showSpecialty =
        !(await OnboardingService.instance.hasCompletedOnboarding());
    if (!context.mounted) return;

    final destination = showSpecialty
        ? const SpecialtyOnboardingScreen()
        : const MainShell();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _showDeniedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Storage Access Needed'),
        content: const Text(
          'MedShelf needs storage access to save and organise your medical files.\n\n'
          'Without it, you won\'t be able to import or save any documents.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateNext(context);
            },
            child: const Text('Continue Without'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLearnMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant
                      .withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Why storage access?',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text(
              'MedShelf creates a "MedShelf" folder in your internal storage '
              'to save all your imported medical files. This folder is visible '
              'in your Files app so you always know exactly where your files are.\n\n'
              'On Android 11 and above, the "All Files Access" permission is '
              'required to manage files in custom app folders. This is a standard '
              'Android requirement for file management apps.\n\n'
              'MedShelf is 100% offline — your files never leave your device.',
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // ── Teal gradient background ─────────────────────────────────────
          Container(
            height: size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kTeal, _kTealDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ── White card bottom ─────────────────────────────────────────────
          Positioned(
            top: size.height * 0.40,
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ),

          // ── Full scrollable content ───────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // TOP: shield + title
                  SizedBox(
                    height: size.height * 0.38,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(25),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Your Privacy Matters 🔒',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // BOTTOM: white card content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MedShelf needs storage access',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Here's exactly what we do and don't do:",
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ✅ bullets
                        _Bullet(
                          icon: '✅',
                          text:
                              'Save your files to a MedShelf folder in your internal storage — visible in your Files app',
                        ),
                        _Bullet(
                          icon: '✅',
                          text:
                              'Keep all files 100% on your device — no cloud upload, no servers',
                        ),
                        _Bullet(
                          icon: '✅',
                          text:
                              'Let you import documents from any app into your organised library',
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(),
                        ),

                        // ❌ bullets
                        _Bullet(
                          icon: '❌',
                          text:
                              'We never read your personal photos or messages',
                        ),
                        _Bullet(
                          icon: '❌',
                          text: 'We never upload your files anywhere',
                        ),
                        _Bullet(
                          icon: '❌',
                          text: 'We never collect any personal data',
                        ),

                        const SizedBox(height: 20),

                        // footnote
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'All your medical files stay on your phone.\n'
                            'MedShelf works completely offline.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Allow button
                        FilledButton(
                          onPressed: () => _handleAllow(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kTeal,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Allow Storage Access',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Learn more
                        Center(
                          child: TextButton(
                            onPressed: () => _showLearnMoreSheet(context),
                            child: const Text('Learn More'),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
