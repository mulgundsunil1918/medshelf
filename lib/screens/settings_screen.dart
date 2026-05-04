import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/file_storage_service.dart';
import '../services/onboarding_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'about_screen.dart';
import 'manage_specialties_screen.dart';
import 'tutorial_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<int> _storageFuture;
  List<String> _selectedSpecialties = [];

  @override
  void initState() {
    super.initState();
    _storageFuture = FileStorageService.instance.getTotalStorageUsed();
    _loadSpecialties();
  }

  Future<void> _loadSpecialties() async {
    final list = await OnboardingService.instance.getSelectedSpecialties();
    if (mounted) setState(() => _selectedSpecialties = list);
  }

  void _openManageSpecialties() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => const ManageSpecialtiesScreen()),
    );
    if (changed == true) _loadSpecialties();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openTutorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const TutorialScreen(fromSettings: true)),
    );
  }

  Future<void> _replayCoachMarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_seen_coach_marks');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tour will start when you return to Home'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showImportHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How to Import Files'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Method 1 — Import Documents',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                'Tap "📥 Import Documents" on the Home screen to browse your device and pick any file.',
              ),
              SizedBox(height: 16),
              Text('Method 2 — Share from another app',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                '1. Open a file in WhatsApp, Gmail, Telegram, Chrome, or any app.\n'
                '2. Tap the Share button.\n'
                '3. Choose MedShelf from the share sheet.\n'
                '4. The file will open in MedShelf for you to name and save.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── MY SPECIALTIES ─────────────────────────────────────────────────
          _SectionHeader(label: 'MY SPECIALTIES', tt: tt, cs: cs),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedSpecialties.isEmpty)
                    Text(
                      'No specialties set up yet.',
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedSpecialties.map((name) {
                        return Chip(
                          label: Text(name),
                          labelStyle:
                              tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer,
                          ),
                          backgroundColor:
                              cs.primaryContainer.withAlpha(80),
                          side: BorderSide(
                              color: cs.primary.withAlpha(60)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.coral.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.edit_rounded,
                          size: 20, color: AppColors.coral),
                    ),
                    title: Text('Manage Specialties',
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Add or remove specialty folders'),
                    trailing:
                        const Icon(Icons.chevron_right_rounded),
                    onTap: _openManageSpecialties,
                  ),
                ],
              ),
            ),
          ),

          // ── APPEARANCE ─────────────────────────────────────────────────────
          _SectionHeader(label: 'APPEARANCE', tt: tt, cs: cs),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _LeadingBox(
                          icon: Icons.palette_rounded, cs: cs),
                      const SizedBox(width: 12),
                      Text('Theme',
                          style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeNotifier.themeMode},
                    onSelectionChanged: (selected) =>
                        themeNotifier.setThemeMode(selected.first),
                  ),
                ],
              ),
            ),
          ),

          // ── HELP ───────────────────────────────────────────────────────────
          _SectionHeader(label: 'HELP', tt: tt, cs: cs),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.menu_book_rounded,
                  emoji: null,
                  title: 'View Tutorial',
                  subtitle: 'Replay the onboarding guide',
                  cs: cs,
                  tt: tt,
                  onTap: _openTutorial,
                ),
                const Divider(height: 1, indent: 72),
                _SettingsTile(
                  icon: Icons.tour_rounded,
                  emoji: null,
                  title: 'Replay Interactive Tour',
                  subtitle: 'See feature highlights on the home screen',
                  cs: cs,
                  tt: tt,
                  onTap: _replayCoachMarks,
                ),
                const Divider(height: 1, indent: 72),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  emoji: null,
                  title: 'How to Import Files',
                  subtitle: 'Share from WhatsApp, Gmail & more',
                  cs: cs,
                  tt: tt,
                  onTap: _showImportHelp,
                ),
              ],
            ),
          ),

          // ── ABOUT ──────────────────────────────────────────────────────────
          _SectionHeader(label: 'ABOUT', tt: tt, cs: cs),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF006B74)),
              title: Text('About MedShelf',
                  style: tt.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AboutScreen()),
              ),
            ),
          ),

          // ── FEEDBACK ───────────────────────────────────────────────────────
          _SectionHeader(label: 'FEEDBACK', tt: tt, cs: cs),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  subtitle: 'mulgundsunil@gmail.com',
                  cs: cs,
                  tt: tt,
                  onTap: () => _launchUrl(
                    'mailto:mulgundsunil@gmail.com'
                    '?subject=MedShelf%20Feedback',
                  ),
                ),
                const Divider(height: 1, indent: 72),
                _SettingsTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Report a Bug',
                  subtitle: 'Help us improve MedShelf',
                  cs: cs,
                  tt: tt,
                  onTap: () => _launchUrl(
                    'mailto:mulgundsunil@gmail.com'
                    '?subject=MedShelf%20Bug%20Report',
                  ),
                ),
                const Divider(height: 1, indent: 72),
                _SettingsTile(
                  icon: Icons.share_rounded,
                  title: 'Share with Colleagues',
                  subtitle: 'Recommend to fellow doctors',
                  cs: cs,
                  tt: tt,
                  onTap: () => Share.share(
                    'Check out MedShelf — Your personal medical '
                    'knowledge library 📚\n'
                    'https://play.google.com/store/apps/details'
                    '?id=com.medshelf.medshelf',
                  ),
                ),
                const Divider(height: 1, indent: 72),
                _SettingsTile(
                  icon: Icons.star_border_rounded,
                  title: 'Rate the App',
                  subtitle: 'Leave a review on Play Store',
                  cs: cs,
                  tt: tt,
                  onTap: () => _launchUrl(
                    'https://play.google.com/store/apps/details'
                    '?id=com.medshelf.medshelf',
                  ),
                ),
              ],
            ),
          ),

          // ── SUPPORT ────────────────────────────────────────────────────────
          _SectionHeader(label: 'SUPPORT', tt: tt, cs: cs),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.coral.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.favorite_rounded,
                    size: 20, color: AppColors.coral),
              ),
              title: Text(
                'Support the Developer',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle:
                  const Text('Help keep MedShelf free and ad-free 🙏'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _launchUrl(kSupportLink),
            ),
          ),

          // ── STORAGE ────────────────────────────────────────────────────────
          _SectionHeader(label: 'STORAGE', tt: tt, cs: cs),
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            child: FutureBuilder<int>(
              future: _storageFuture,
              builder: (context, snap) {
                final label =
                    snap.hasData ? _formatBytes(snap.data!) : '—';
                return ListTile(
                  leading: _LeadingBox(
                      icon: Icons.storage_rounded, cs: cs),
                  title: Text('MedShelf Storage Used',
                      style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700)),
                  trailing: Text(
                    label,
                    style: tt.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),

          // ── CREATED BY ─────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text(
                  'Created by Dr. Sunil Mulgund',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _launchUrl(
                      'mailto:mulgundsunil@gmail.com'),
                  child: Text(
                    'mulgundsunil@gmail.com',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.tt,
    required this.cs,
  });

  final String label;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Leading box ──────────────────────────────────────────────────────────────

class _LeadingBox extends StatelessWidget {
  const _LeadingBox({required this.icon, required this.cs});
  final IconData icon;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: cs.primary),
    );
  }
}

// ─── Settings tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.cs,
    required this.tt,
    this.emoji,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String? emoji;
  final String title;
  final String? subtitle;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _LeadingBox(icon: icon, cs: cs),
      title: Text(title,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
