import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/med_file.dart';
import '../models/topic.dart';
import '../services/camera_scan_service.dart';
import '../services/database_service.dart';
import '../services/file_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/onboarding_service.dart';
import '../services/topic_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../utils/share_helper.dart';
import '../widgets/add_note_sheet.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/file_thumbnail.dart';
import '../widgets/save_file_sheet.dart';
import '../widgets/support_banner.dart';
import 'all_files_screen.dart';
import 'file_properties_screen.dart';
import 'note_viewer_screen.dart';
import 'batch_import_screen.dart';
import 'file_list_screen.dart';
import 'device_file_search_screen.dart';

// ─── Data holder ─────────────────────────────────────────────────────────────

class _HomeData {
  const _HomeData({
    required this.files,
    required this.bookmarkedFiles,
    required this.storageBytes,
  });
  final List<MedFile> files;
  final List<MedFile> bookmarkedFiles;
  final int storageBytes;
}

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final void Function(int tabIndex) onNavigate;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _dataFuture;

  /// Public — called by MainShell when the home tab gains focus, so the
  /// coach-mark tour can re-run after the user resets it in Settings.
  Future<void> triggerCoachMarksIfNeeded() => _maybeRunCoachMarks();

  // Keys used to anchor the interactive coach-mark walkthrough on the
  // first home-screen visit.
  final GlobalKey _kImportBtn  = GlobalKey();
  final GlobalKey _kSearchBtn  = GlobalKey();
  final GlobalKey _kScanBtn    = GlobalKey();
  final GlobalKey _kQuickNote  = GlobalKey();
  final GlobalKey _kSpecialty  = GlobalKey();

  bool _coachMarksRunning = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    FileNotifier.instance.addListener(_onRefresh);

    // After the first frame, run the coach-mark tour if the user hasn't
    // seen it yet. The 600 ms delay gives the lazy-loaded content time
    // to settle so the GlobalKeys resolve to real on-screen rects.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRunCoachMarks());
  }

  Future<void> _maybeRunCoachMarks() async {
    if (_coachMarksRunning || !mounted) return;
    final seen = await OnboardingService.instance.hasSeenCoachMarks();
    if (seen || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _coachMarksRunning) return;
    _coachMarksRunning = true;
    try {
      await _runCoachMarks();
    } finally {
      _coachMarksRunning = false;
    }
  }

  @override
  void dispose() {
    FileNotifier.instance.removeListener(_onRefresh);
    super.dispose();
  }

  Future<void> _runCoachMarks() async {
    await showCoachMarks(
      context,
      steps: [
        CoachStep(
          targetKey: _kImportBtn,
          icon: Icons.upload_file_rounded,
          title: 'Import Files 📥',
          description:
              'Tap here to add PDFs, images, videos, or documents to '
              'your library. Choose a single file, multiple files, or an '
              'entire folder at once.',
        ),
        // "Find on Device" pill is Android-only — skip the matching step
        // on iOS so the spotlight has something real to point at.
        if (Platform.isAndroid)
          CoachStep(
            targetKey: _kSearchBtn,
            icon: Icons.phone_android_rounded,
            title: 'Search Your Device 🔍',
            description:
                'MedShelf can scan WhatsApp, Telegram, Downloads and more — '
                'finding all your scattered medical files in seconds.',
          ),
        CoachStep(
          targetKey: _kScanBtn,
          icon: Icons.document_scanner_rounded,
          title: 'Scan Documents 📷',
          description:
              'Snap photos of paper notes, prescriptions or printouts and '
              'MedShelf turns them into clean PDFs — all on-device, '
              'nothing uploaded.',
        ),
        CoachStep(
          targetKey: _kQuickNote,
          icon: Icons.edit_note_rounded,
          title: 'Quick Rich Note ⚡',
          description:
              'Capture a richly-formatted study note with bold, italic, '
              'underline, highlights, lists and more — saved into the '
              'specialty of your choice.',
        ),
        CoachStep(
          targetKey: _kSpecialty,
          icon: Icons.local_hospital_rounded,
          title: 'Browse by Specialty 🏥',
          description:
              'Tap a specialty to see all your files inside it. Your '
              'library mirrors the way medical knowledge is structured.',
          tooltipPosition: TooltipPosition.above,
        ),
      ],
    );
    if (!mounted) return;
    await OnboardingService.instance.setCoachMarksSeen();
  }

  Future<_HomeData> _loadData() async {
    final files = await DatabaseService.instance.getAllFiles();
    final bookmarkedFiles =
        await DatabaseService.instance.getBookmarkedFiles();
    final storageBytes =
        await FileStorageService.instance.getTotalStorageUsed();
    return _HomeData(
      files: files,
      bookmarkedFiles: bookmarkedFiles,
      storageBytes: storageBytes,
    );
  }

  Future<void> _onRefresh() async {
    final next = _loadData();
    setState(() { _dataFuture = next; });
    await next;
  }

  String _formatStorage(int bytes) {
    if (bytes == 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return mb < 1
        ? '${(bytes / 1024).toStringAsFixed(1)} KB'
        : '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _scanCamera() async {
    String? scanned;
    try {
      scanned = await CameraScanService.instance.scanDocument();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start the camera scanner.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (scanned == null || !mounted) return; // user cancelled

    // Hand the scanned file path to the existing save-file flow.
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SaveFileSheet(sourcePath: scanned!),
    );
    if (saved == true) await _onRefresh();
  }

  Future<void> _importDocuments() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(allowMultiple: false);
    } catch (_) {
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SaveFileSheet(sourcePath: pickedFile.path!),
    );
    if (saved == true) await _onRefresh();
  }

  void _showAddNoteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddNoteSheet(),
    ).then((_) => _onRefresh());
  }

  void _showImportOptions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_rounded),
              title: const Text('Single File'),
              subtitle: const Text('Pick one file'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _importDocuments();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_copy_rounded),
              title: const Text('Multiple Files'),
              subtitle: const Text('Pick several files at once'),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) =>
                      const BatchImportScreen(mode: BatchMode.files),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Entire Folder'),
              subtitle: const Text('Import all files from a folder'),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) =>
                      const BatchImportScreen(mode: BatchMode.folder),
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final themeNotifier = context.watch<ThemeNotifier>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Med',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: 'Shelf',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w400,
                  fontSize: 26,
                  color: const Color(0xFFE8835A),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: themeNotifier.toggleTheme,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<TopicService>(
        builder: (context, topicService, _) {
          return FutureBuilder<_HomeData>(
            future: _dataFuture,
            builder: (context, snap) {
              final isLoading =
                  snap.connectionState == ConnectionState.waiting &&
                      snap.data == null;
              final files = snap.data?.files ?? [];
              final bookmarkedFiles =
                  snap.data?.bookmarkedFiles ?? [];
              final storageBytes = snap.data?.storageBytes ?? 0;

              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _GreetingBanner(
                            fileCount: files.length,
                            topicCount:
                                topicService.flatTopics.length,
                          ),
                          const SizedBox(height: 12),
                          const SupportBanner(),
                          const SizedBox(height: 16),

                          // ── Import + Search Device + Scan ─────────
                          Row(
                            children: [
                              Expanded(
                                child: _ActionPill(
                                  globalKey: _kImportBtn,
                                  icon: Icons.upload_file_rounded,
                                  label: 'Import',
                                  onTap: () => _showImportOptions(context),
                                ),
                              ),
                              // "Find on Device" only makes sense on Android,
                              // where MedShelf can scan WhatsApp / Telegram /
                              // Downloads folders. On iOS the OS sandbox
                              // forbids reading other apps' data, so we hide
                              // this pill entirely instead of showing a
                              // useless button that crashes when tapped.
                              if (Platform.isAndroid) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ActionPill(
                                    globalKey: _kSearchBtn,
                                    icon: Icons.phone_android_rounded,
                                    label: 'Find on Device',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const DeviceFileSearchScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ActionPill(
                                  globalKey: _kScanBtn,
                                  icon: Icons.document_scanner_rounded,
                                  label: 'Scan',
                                  onTap: _scanCamera,
                                ),
                              ),
                            ],
                          ),

                          // ── Quick Note ─────────────────────────────
                          const SizedBox(height: 12),
                          GestureDetector(
                            key: _kQuickNote,
                            onTap: _showAddNoteSheet,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF006B74),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.edit_note_rounded,
                                      color: Colors.white, size: 22),
                                  SizedBox(width: 12),
                                  Text(
                                    'Quick Note',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Stats ──────────────────────────────────
                          _StatsRow(
                            fileCount: files.length,
                            topicCount:
                                topicService.flatTopics.length,
                            storageLabel:
                                _formatStorage(storageBytes),
                            onFilesTap: () =>
                                Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AllFilesScreen()),
                            ),
                            cs: cs,
                            tt: tt,
                          ),
                          const SizedBox(height: 24),

                          _SectionHeader(
                            title: 'Browse by Specialty',
                            onSeeAll: () => widget.onNavigate(1),
                            tt: tt,
                          ),
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: _kSpecialty,
                            child: _SpecialtyRow(
                              topics: topicService.rootTopics,
                              onTap: (_) => widget.onNavigate(1),
                              cs: cs,
                              tt: tt,
                            ),
                          ),
                          const SizedBox(height: 24),

                          _SectionHeader(
                            title: 'Browse by Topic',
                            onSeeAll: () => widget.onNavigate(1),
                            tt: tt,
                          ),
                          const SizedBox(height: 12),
                          _TopicRow(
                            topics: topicService.rootTopics
                                .expand((r) => r.children)
                                .toList(),
                            cs: cs,
                            tt: tt,
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(
                            title: 'Bookmarked 🔖',
                            onSeeAll: () =>
                                Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AllFilesScreen(
                                          showBookmarkedOnly:
                                              true)),
                            ),
                            tt: tt,
                          ),
                          const SizedBox(height: 10),
                          _BookmarkedSection(
                            files: bookmarkedFiles,
                            isLoading: isLoading,
                            topicService: topicService,
                            onRefresh: _onRefresh,
                            cs: cs,
                            tt: tt,
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(
                            title: 'Recently Added',
                            onSeeAll: () =>
                                Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AllFilesScreen()),
                            ),
                            tt: tt,
                          ),
                          const SizedBox(height: 8),
                          _RecentFilesList(
                            files: files.take(8).toList(),
                            isLoading: isLoading,
                            topicService: topicService,
                            onRefresh: _onRefresh,
                            cs: cs,
                            tt: tt,
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Action pill (Import / Find / Scan) ──────────────────────────────────────

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.globalKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final GlobalKey globalKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: globalKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF006B74),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Greeting Banner ──────────────────────────────────────────────────────────

class _GreetingBanner extends StatefulWidget {
  const _GreetingBanner({
    required this.fileCount,
    required this.topicCount,
  });

  final int fileCount;
  final int topicCount;

  @override
  State<_GreetingBanner> createState() => _GreetingBannerState();
}

class _GreetingBannerState extends State<_GreetingBanner> {
  int _quoteOffset = 0;

  static const List<String> _quotes = [
    '📖 Knowledge saved today, applied tomorrow',
    '🩺 Your clinical library, always at your fingertips',
    '🌟 Every great doctor has great references',
    '🧩 Organised knowledge. Better care.',
    '🧠 Your second brain for medicine',
    '⚡ Save once. Find instantly. Always.',
    '🎓 The best doctors never stop learning',
    '💡 One saved article today, one life saved tomorrow',
    '🏥 Medicine is learned by the bedside, remembered in the library',
    '🔍 A good clinician reads. A great clinician remembers where to look',
    '🌱 Your library grows with every patient you see',
    '❤️ Keep learning. Keep healing.',
    '🤝 Great care starts with great knowledge',
    '📈 The more you save, the more you know',
    '🫀 Every PDF saved is a patient helped',
    '🏆 Organise your knowledge. Elevate your practice.',
    '⏱️ In medicine, the right reference at the right time saves lives',
    '💪 Smart doctors build smart libraries',
    '🔖 Your knowledge. Your practice. Your MedShelf.',
    '🚀 Science moves fast. Stay organised, stay ahead.',
    '🦸 Not all heroes wear capes — some organise their references',
    '🧘 A tidy library is a tidy mind',
    '🎯 The art of medicine is in the details — so is your library',
    '📚 Read more. Save more. Know more.',
    '👶 Your patients deserve a doctor who never stops growing',
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning, Doctor 👋';
    if (hour >= 12 && hour < 17) return 'Good Afternoon, Doctor 👋';
    if (hour >= 17 && hour < 21) return 'Good Evening, Doctor 👋';
    return 'Good Night, Doctor 🌙';
  }

  String get _quote {
    final idx =
        (DateTime.now().day + _quoteOffset) % _quotes.length;
    return _quotes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _quoteOffset++),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007A85), Color(0xFF003D45)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Decorative quote icon
                Positioned(
                  top: -8,
                  left: -4,
                  child: Icon(
                    Icons.format_quote_rounded,
                    size: 48,
                    color: Colors.white.withAlpha(40),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                        color: Colors.white.withAlpha(50),
                        height: 1),
                    const SizedBox(height: 10),
                    Text(
                      _quote,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(217),
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap for next',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withAlpha(100),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Dynamic subtitle below banner
        Text(
          widget.fileCount > 0
              ? '${widget.fileCount} file${widget.fileCount == 1 ? '' : 's'} '
                'across ${widget.topicCount} specialt${widget.topicCount == 1 ? 'y' : 'ies'} — ready when you are'
              : 'Start by importing your first document 📥',
          textAlign: TextAlign.center,
          style: tt.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.fileCount,
    required this.topicCount,
    required this.storageLabel,
    required this.cs,
    required this.tt,
    this.onFilesTap,
  });

  final int fileCount;
  final int topicCount;
  final String storageLabel;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback? onFilesTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
              emoji: '📄',
              value: '$fileCount',
              label: 'Files',
              onTap: onFilesTap,
              cs: cs,
              tt: tt),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              emoji: '🗂️',
              value: '$topicCount',
              label: 'Topics',
              cs: cs,
              tt: tt),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              emoji: '💾',
              value: storageLabel,
              label: 'Storage',
              cs: cs,
              tt: tt),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.cs,
    required this.tt,
    this.onTap,
  });

  final String emoji;
  final String value;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(value,
                style: tt.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(label,
                style: tt.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title, this.onSeeAll, required this.tt});

  final String title;
  final VoidCallback? onSeeAll;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

// ─── Specialty Row ────────────────────────────────────────────────────────────

class _SpecialtyRow extends StatelessWidget {
  const _SpecialtyRow({
    required this.topics,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final List<Topic> topics;
  final void Function(Topic topic) onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: topics.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final topic = topics[i];
          return _SpecialtyCard(
            topic: topic,
            onTap: () => onTap(topic),
            cs: cs,
            tt: tt,
          );
        },
      ),
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({
    required this.topic,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final Topic topic;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withAlpha(140),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(topic.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              topic.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Box ──────────────────────────────────────────────────────────────

// ─── Topic Row ────────────────────────────────────────────────────────────────

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topics,
    required this.cs,
    required this.tt,
  });
  final List<Topic> topics;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: topics.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final topic = topics[i];
          return _TopicCard(topic: topic, cs: cs, tt: tt);
        },
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.cs,
    required this.tt,
  });
  final Topic topic;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => FileListScreen(topic: topic)),
      ),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF006B74).withAlpha(100)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(topic.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              topic.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF006B74),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bookmarked Section ───────────────────────────────────────────────────────

class _BookmarkedSection extends StatelessWidget {
  const _BookmarkedSection({
    required this.files,
    required this.isLoading,
    required this.topicService,
    required this.onRefresh,
    required this.cs,
    required this.tt,
  });

  final List<MedFile> files;
  final bool isLoading;
  final TopicService topicService;
  final Future<void> Function() onRefresh;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Tap the bookmark icon on any file to pin it here',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _BookmarkCard(
          file: files[i],
          breadcrumb: topicService.getBreadcrumb(files[i].topicId),
          onRefresh: onRefresh,
          cs: cs,
          tt: tt,
        ),
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.file,
    required this.breadcrumb,
    required this.onRefresh,
    required this.cs,
    required this.tt,
  });

  final MedFile file;
  final String breadcrumb;
  final Future<void> Function() onRefresh;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final badgeColor = AppColors.getColorForFileType(file.fileType);
    return InkWell(
      onTap: () => NoteViewerScreen.open(context, file),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(file.fileTypeIcon,
                    style: const TextStyle(fontSize: 22)),
                const Spacer(),
                Icon(Icons.bookmark_rounded,
                    size: 18, color: badgeColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              breadcrumb,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Files List ────────────────────────────────────────────────────────

class _RecentFilesList extends StatelessWidget {
  const _RecentFilesList({
    required this.files,
    required this.isLoading,
    required this.topicService,
    required this.onRefresh,
    required this.cs,
    required this.tt,
  });

  final List<MedFile> files;
  final bool isLoading;
  final TopicService topicService;
  final Future<void> Function() onRefresh;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Text('📲', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No files yet. Share a PDF from WhatsApp to get started! 📲',
              textAlign: TextAlign.center,
              style:
                  tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: files
          .map(
            (file) => _FileListTile(
              file: file,
              breadcrumb: topicService.getBreadcrumb(file.topicId),
              onRefresh: onRefresh,
              cs: cs,
              tt: tt,
            ),
          )
          .toList(),
    );
  }
}

// ─── File List Tile ───────────────────────────────────────────────────────────

class _FileListTile extends StatelessWidget {
  const _FileListTile({
    required this.file,
    required this.breadcrumb,
    required this.onRefresh,
    required this.cs,
    required this.tt,
  });

  final MedFile file;
  final String breadcrumb;
  final Future<void> Function() onRefresh;
  final ColorScheme cs;
  final TextTheme tt;

  Future<void> _toggleBookmark(BuildContext context) async {
    final newValue = !file.isBookmarked;
    await DatabaseService.instance.toggleBookmark(file.path, newValue);
    await onRefresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              newValue ? '🔖 Added to bookmarks' : 'Removed from bookmarks'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showMoveDialog(BuildContext ctx) async {
    final topicService = Provider.of<TopicService>(ctx, listen: false);
    final flat = topicService.flatTopics;

    final picked = await showDialog<Topic>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: flat.length,
            itemBuilder: (context, i) {
              final t = flat[i];
              return ListTile(
                leading: Text(t.emoji,
                    style: const TextStyle(fontSize: 20)),
                title: Text(t.name),
                onTap: () => Navigator.of(dCtx).pop(t),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (picked == null) return;
    final oldPath = file.path;
    final newPath =
        await FileStorageService.instance.moveFile(oldPath, picked.id);
    await DatabaseService.instance
        .moveFile(oldPath, picked.id, newPath: newPath);
    await onRefresh();
  }

  Future<void> _showDeleteDialog(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete File',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${file.name}"?\nThis cannot be undone.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red[600]),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 1. Delete physical file from storage.
    await FileStorageService.instance.deleteFileFromStorage(file.path);

    // 2. Delete database record — primary: by path; secondary: by id.
    await DatabaseService.instance.deleteFile(file.path);
    if (file.id != null) {
      await DatabaseService.instance.deleteFileById(file.id!);
    }

    // 3. Refresh parent list.
    await onRefresh();
  }

  void _showActions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open file'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  NoteViewerScreen.open(ctx, file);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.info_outline_rounded),
                title: const Text('File Info'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  Navigator.of(ctx)
                      .push(MaterialPageRoute(
                          builder: (_) =>
                              FilePropertiesScreen(file: file)))
                      .then((_) => onRefresh());
                },
              ),
              ListTile(
                leading: Icon(
                  file.isBookmarked
                      ? Icons.bookmark_remove_rounded
                      : Icons.bookmark_add_rounded,
                ),
                title: Text(
                  file.isBookmarked ? 'Remove bookmark' : 'Bookmark',
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _toggleBookmark(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  ShareHelper.shareFile(ctx, file);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.drive_file_move_rounded),
                title: const Text('Move to folder'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showMoveDialog(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_rounded,
                    color: Theme.of(sheetCtx).colorScheme.error),
                title: Text(
                  'Delete',
                  style: TextStyle(
                      color: Theme.of(sheetCtx)
                          .colorScheme
                          .error),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showDeleteDialog(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = AppColors.getColorForFileType(file.fileType);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => NoteViewerScreen.open(context, file),
        onLongPress: () => _showActions(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: Row(
            children: [
              FileThumbnail(file: file, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$breadcrumb · ${file.formattedDate}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Share — visible action so users can send to any app.
              IconButton(
                icon: Icon(Icons.share_rounded,
                    size: 20, color: cs.primary),
                tooltip: 'Share',
                onPressed: () => ShareHelper.shareFile(context, file),
              ),
              if (file.isBookmarked)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.bookmark_rounded,
                      size: 16, color: badgeColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
