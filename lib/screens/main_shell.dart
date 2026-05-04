import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_notifier.dart';
import '../services/permission_service.dart';
import '../utils/constants.dart';
import '../widgets/save_file_sheet.dart';
import '../widgets/support_popup.dart';
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

    // Request storage permission after the first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _requestStoragePermission();
    });

    // Listen for files shared while app is running
    _intentSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleSharedFiles);

    // Handle files shared when app was cold-started
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(files);
      }
    });
  }

  Future<void> _requestStoragePermission() async {
    final granted =
        await PermissionService.instance.requestStoragePermission();
    if (!granted && mounted) {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Storage Permission Needed'),
        content: const Text(
          'MedShelf needs storage permission to save your files to '
          'Internal Storage so you can find them in your Files app '
          'under Internal Storage › MedShelf.\n\n'
          'Please grant "All files access" in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not Now'),
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
    final path = files.first.path;
    ReceiveSharingIntent.instance.reset();
    // Defer showing the sheet until after the current frame
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => SaveFileSheet(sourcePath: path),
      );
      if (saved == true && mounted) {
        FileNotifier.instance.notifyFileChanged();
        setState(() {});
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
