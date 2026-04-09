import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Brand colours ────────────────────────────────────────────────────────────

const _seedColor = Color(0xFF006D77);

const _lightBackground = Color(0xFFF4F9FA);
const _lightSurface = Color(0xFFFFFFFF);

const _darkBackground = Color(0xFF0A1A1E);
const _darkSurface = Color(0xFF0F2428);
const _darkCard = Color(0xFF142C32);

// ─── Typography ───────────────────────────────────────────────────────────────

TextTheme _buildTextTheme(TextTheme base) {
  final display = GoogleFonts.nunitoTextTheme(base);
  final body = GoogleFonts.dmSansTextTheme(base);

  return base.copyWith(
    displayLarge: display.displayLarge,
    displayMedium: display.displayMedium,
    displaySmall: display.displaySmall,
    headlineLarge: display.headlineLarge,
    headlineMedium: display.headlineMedium,
    headlineSmall: display.headlineSmall,
    titleLarge: display.titleLarge,
    titleMedium: display.titleMedium,
    titleSmall: display.titleSmall,
    bodyLarge: body.bodyLarge,
    bodyMedium: body.bodyMedium,
    bodySmall: body.bodySmall,
    labelLarge: body.labelLarge,
    labelMedium: body.labelMedium,
    labelSmall: body.labelSmall,
  );
}

// ─── Component themes ─────────────────────────────────────────────────────────

AppBarTheme _appBarThemeLight() => const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Color(0xFF006D77),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    );

AppBarTheme _appBarThemeDark() => const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Color(0xFF003D45),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    );

CardThemeData _cardThemeLight() => CardThemeData(
      elevation: 0,
      color: Colors.white,
      shadowColor: const Color(0xFF006D77).withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF006D77).withAlpha(20)),
      ),
    );

CardThemeData _cardThemeDark() => CardThemeData(
      elevation: 0,
      color: _darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );

FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF006D77),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

InputDecorationTheme _inputTheme() => InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

NavigationBarThemeData _navBarThemeLight() => NavigationBarThemeData(
      height: 68,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFF006D77).withAlpha(38),
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF006D77));
        }
        return const IconThemeData(color: Color(0xFF6B7280));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
              color: Color(0xFF006D77), fontWeight: FontWeight.w600, fontSize: 12);
        }
        return const TextStyle(color: Color(0xFF6B7280), fontSize: 12);
      }),
    );

NavigationBarThemeData _navBarThemeDark() => NavigationBarThemeData(
      height: 68,
      backgroundColor: _darkSurface,
      indicatorColor: const Color(0xFF006D77).withAlpha(60),
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF4ECDC4));
        }
        return const IconThemeData(color: Color(0xFF9BA8B0));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
              color: Color(0xFF4ECDC4), fontWeight: FontWeight.w600, fontSize: 12);
        }
        return const TextStyle(color: Color(0xFF9BA8B0), fontSize: 12);
      }),
    );

// ─── Light theme ──────────────────────────────────────────────────────────────

ThemeData get lightTheme {
  final cs = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.light,
  ).copyWith(
    surface: _lightSurface,
    onSurface: const Color(0xFF1A2E35),
    surfaceContainerHighest: const Color(0xFFE8F4F6),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: _lightBackground,
  );

  return base.copyWith(
    textTheme: _buildTextTheme(base.textTheme),
    appBarTheme: _appBarThemeLight(),
    cardTheme: _cardThemeLight(),
    filledButtonTheme: _filledButtonTheme(),
    inputDecorationTheme: _inputTheme(),
    navigationBarTheme: _navBarThemeLight(),
  );
}

// ─── Dark theme ───────────────────────────────────────────────────────────────

ThemeData get darkTheme {
  final cs = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ).copyWith(
    surface: _darkSurface,
    onSurface: const Color(0xFFE8F4F6),
    surfaceContainerHighest: const Color(0xFF1A3540),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: _darkBackground,
  );

  return base.copyWith(
    textTheme: _buildTextTheme(base.textTheme),
    appBarTheme: _appBarThemeDark(),
    cardTheme: _cardThemeDark(),
    filledButtonTheme: _filledButtonTheme(),
    inputDecorationTheme: _inputTheme(),
    navigationBarTheme: _navBarThemeDark(),
  );
}

// ─── ThemeNotifier ────────────────────────────────────────────────────────────

const _kThemeModeKey = 'theme_mode';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    _themeMode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeModeKey,
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeModeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}
