import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/splash_screen.dart';
import 'services/topic_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _handleOnboardingReset();

  // Desktop platforms need the FFI implementation
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final themeNotifier = ThemeNotifier();
  final topicService = TopicService.instance;

  await themeNotifier.loadTheme();
  await topicService.loadTopics();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
        ChangeNotifierProvider<TopicService>.value(value: topicService),
      ],
      child: const MedShelfApp(),
    ),
  );
}

Future<void> _handleOnboardingReset() async {
  final prefs = await SharedPreferences.getInstance();
  final info = await PackageInfo.fromPlatform();
  final currentBuild = info.buildNumber;
  final savedBuild = prefs.getString('installed_build') ?? '';

  if (savedBuild != currentBuild) {
    await prefs.remove('has_seen_tutorial');
    await prefs.remove('has_completed_onboarding');
    // Re-show the home-screen coach marks so users see the new
    // Scan / Share buttons after upgrade.
    await prefs.remove('has_seen_coach_marks');
    await prefs.setString('installed_build', currentBuild);
    debugPrint('New build detected — onboarding + coach marks reset');
  }
}

class MedShelfApp extends StatelessWidget {
  const MedShelfApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    return MaterialApp(
      title: 'MedShelf',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeNotifier.themeMode,
      // flutter_quill v11+ requires its own localization delegate AND the
      // standard Material/Widgets/Cupertino delegates to render its
      // toolbar (Bold / Italic / Underline / Strike / Lists etc.).
      // Without this block the toolbar silently fails — visible bug
      // until v1.0.4.
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const SplashScreen(),
    );
  }
}
