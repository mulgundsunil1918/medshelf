import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTeal  = Color(0xFF006B74);
const _kCoral = Color(0xFFE8835A);

// ─── About Screen ─────────────────────────────────────────────────────────────

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launch(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:  Text('Could not open link.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor:   _kTeal,
        foregroundColor:   Colors.white,
        iconTheme:         const IconThemeData(color: Colors.white),
        title: const Text(
          'About MedShelf',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── App icon + version ──────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/icon/app_icon.jpg',
                      width:  72,
                      height: 72,
                      fit:    BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 13,
                      color:    cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Story text ──────────────────────────────────────────────────
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  height:   1.6,
                  color:    cs.onSurface,
                ),
                children: const [
                  TextSpan(
                    text:
                      'During my training, I constantly struggled with scattered '
                      'notes, screenshots, and multiple apps that slowed me down '
                      'when I needed information quickly 📚\n\n'
                      'Nothing really worked the way a doctor thinks or works '
                      'in real life ⚡\n\n'
                      'So I decided to build something for myself — simple, fast, '
                      'and always accessible 🛠️\n\n',
                  ),
                  TextSpan(
                    text:
                      'I built MedShelf on my own, without any developers, while '
                      'learning basic coding and using AI along the way 🤖',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                      '\n\nIt\'s a clean, offline-first space where I can store, '
                      'organize, and instantly find important clinical notes '
                      'without distractions 🧠\n\n'
                      'Every feature in MedShelf comes from a real problem I '
                      'faced on duty 🏥\n\n'
                      'This app is my attempt to make daily clinical life a '
                      'little smoother and more efficient 🚀',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Doctor credit ───────────────────────────────────────────────
            Text(
              '— Dr. Sunil Mulgund, MBBS, MD, DNB (Pediatrics and Neonatology), '
              'Fellowship in Neonatology '
              '(KIMS Cuddles, Kondapur, Hyderabad)',
              style: TextStyle(
                fontSize:  13,
                fontStyle: FontStyle.italic,
                color:     cs.onSurfaceVariant,
                height:    1.5,
              ),
            ),

            const SizedBox(height: 32),
            const Divider(height: 1),
            const SizedBox(height: 32),

            // ── Social links ────────────────────────────────────────────────
            _SocialRow(
              icon:  Icons.camera_alt_rounded,
              label: 'Instagram',
              url:   'https://www.instagram.com/sunilmulgund',
              onTap: (url) => _launch(context, url),
            ),
            const SizedBox(height: 16),
            _SocialRow(
              icon:  Icons.play_circle_outline_rounded,
              label: 'YouTube',
              url:   'https://youtube.com/@atpproductionssdm',
              onTap: (url) => _launch(context, url),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Social row ───────────────────────────────────────────────────────────────

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    required this.icon,
    required this.label,
    required this.url,
    required this.onTap,
  });

  final IconData              icon;
  final String                label;
  final String                url;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        () => onTap(url),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: _kCoral, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color:      _kCoral,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
