import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_notifier.dart';
import '../utils/constants.dart';
import '../widgets/save_file_sheet.dart';
import '../widgets/support_popup.dart';
import 'batch_import_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  final _libraryKey = GlobalKey<LibraryScreenState>();
  final _homeKey    = GlobalKey<HomeScreenState>();

  // ── Support popup ─────────────────────────────────────────────────────────
  // Shown at most once every [kSupportPopupCooldownDays] across all
  // launches — the timestamp of the last appearance is persisted in
  // SharedPreferences so the popup doesn't re-fire on every session.
  bool   _popupShownThisSession = false;
  Timer? _supportTimer;

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _navigateTo(int index) => setState(() => _selectedIndex = index);

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder_rounded),
      label: 'Library',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search_rounded),
      label: 'Search',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];

  // ─── Share intent ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Schedule the support popup — fires after 35 s, but only if it's
    // been at least kSupportPopupCooldownDays since it last appeared.
    _supportTimer = Timer(const Duration(seconds: 35), () {
      if (mounted) _maybeShowSupportPopup();
    });

    // Listen for files shared while app is already running.
    _intentSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleSharedFiles);

    // Cold-start sequence — no storage permission flow required (scoped
    // storage + SAF cover everything MedShelf does). We jump straight to
    // checking for any files the app was launched with via Share.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final files =
          await ReceiveSharingIntent.instance.getInitialMedia();
      if (files.isEmpty || !mounted) return;
      // Small delay so the IndexedStack first paint is settled before
      // we push a modal route on top of it.
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) _handleSharedFiles(files);
    });
  }

  // ── WidgetsBindingObserver ────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Try the popup when the app is sent to background — still gated by
    // the weekly cooldown and the once-per-session flag.
    if (state == AppLifecycleState.paused &&
        !_popupShownThisSession &&
        mounted) {
      _maybeShowSupportPopup();
    }
  }

  /// Gated entry-point — checks the persisted last-shown timestamp and
  /// only fires the popup if at least [kSupportPopupCooldownDays] have
  /// elapsed. Once the popup is shown the timestamp is updated so the
  /// next prompt won't fire for another week.
  Future<void> _maybeShowSupportPopup() async {
    if (_popupShownThisSession || !mounted) return;
    final prefs    = await SharedPreferences.getInstance();
    final lastMs   = prefs.getInt(kSupportPopupLastShownPref) ?? 0;
    final nowMs    = DateTime.now().millisecondsSinceEpoch;
    final cooldown =
        Duration(days: kSupportPopupCooldownDays).inMilliseconds;
    if (lastMs > 0 && nowMs - lastMs < cooldown) return;
    if (!mounted) return;
    _popupShownThisSession = true;
    _supportTimer?.cancel();
    await prefs.setInt(kSupportPopupLastShownPref, nowMs);
    if (mounted) SupportPopup.show(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _supportTimer?.cancel();
    _intentSub?.cancel();
    super.dispose();
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final paths = files
        .map((f) => f.path)
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) return;
    ReceiveSharingIntent.instance.reset();
    // Defer routing until after the current frame so the IndexedStack
    // is settled before we push a modal / route on top.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (paths.length == 1) {
        // Single file — fast path: bottom-sheet save dialog.
        final saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => SaveFileSheet(sourcePath: paths.first),
        );
        if (saved == true && mounted) {
          FileNotifier.instance.notifyFileChanged();
          setState(() {});
        }
      } else {
        // Multi-file share — push the BatchImportScreen with the paths
        // already loaded so the user can pick a destination once and
        // import the whole set in one go.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BatchImportScreen(
              mode: BatchMode.files,
              preloadedPaths: paths,
            ),
          ),
        );
        if (mounted) {
          FileNotifier.instance.notifyFileChanged();
          setState(() {});
        }
      }
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      HomeScreen(key: _homeKey, onNavigate: _navigateTo),
      LibraryScreen(key: _libraryKey),
      const SearchScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: children,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          // Refresh Library counts whenever the Library tab is tapped.
          if (index == 1) _libraryKey.currentState?.refresh();
          // Re-run coach marks when user returns to Home (e.g. after
          // resetting the flag from Settings).
          if (index == 0) _homeKey.currentState?.triggerCoachMarksIfNeeded();
          setState(() => _selectedIndex = index);
        },
        destinations: _destinations,
      ),
    );
  }
}
