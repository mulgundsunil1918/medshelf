import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../services/file_notifier.dart';
import '../services/permission_service.dart';
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

  // ── Support popup ─────────────────────────────────────────────────────────
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

    // Show support popup after 35 s if not yet shown this session.
    _supportTimer = Timer(const Duration(seconds: 35), () {
      if (!_popupShownThisSession && mounted) _showSupportPopup();
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
    // Show popup when app goes to background (if not already shown).
    if (state == AppLifecycleState.paused &&
        !_popupShownThisSession &&
        mounted) {
      _showSupportPopup();
    }
  }

  void _showSupportPopup() {
    if (_popupShownThisSession || !mounted) return;
    _popupShownThisSession = true;
    _supportTimer?.cancel();
    SupportPopup.show(context);
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
      HomeScreen(onNavigate: _navigateTo),
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
          setState(() => _selectedIndex = index);
        },
        destinations: _destinations,
      ),
    );
  }
}
