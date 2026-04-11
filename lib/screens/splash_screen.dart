import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/onboarding_service.dart';
import 'auth_screen.dart';
import 'main_shell.dart';
import 'specialty_onboarding_screen.dart';
import 'tutorial_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTeal  = Color(0xFF006B74);
const _kCoral = Color(0xFFE8835A);
const _kTotalMs = 1400;

double _t(int ms) => ms / _kTotalMs;

// ─── SplashScreen ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Step 1 (0–400ms): "Med" slides in from left + fades in
  late final Animation<double> _medOpacity;
  late final Animation<Offset>  _medSlide;

  // Step 2 (200–600ms): "Shelf" slides in from right + fades in
  late final Animation<double> _shelfOpacity;
  late final Animation<Offset>  _shelfSlide;

  // Step 3 (700–900ms): underline grows 0 → 1
  late final Animation<double> _lineWidth;

  // Step 4 (900–1100ms): subtitle fades in
  late final Animation<double> _subOpacity;

  CurvedAnimation _interval(int startMs, int endMs, [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(_t(startMs), _t(endMs), curve: curve),
      );

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: _kTotalMs),
    );

    // "Med" — slides in from left
    _medOpacity = _interval(0, 400);
    _medSlide   = Tween<Offset>(
      begin: const Offset(-0.6, 0),
      end:   Offset.zero,
    ).animate(_interval(0, 400, Curves.easeOutCubic));

    // "Shelf" — slides in from right
    _shelfOpacity = _interval(200, 600);
    _shelfSlide   = Tween<Offset>(
      begin: const Offset(0.6, 0),
      end:   Offset.zero,
    ).animate(_interval(200, 600, Curves.easeOutCubic));

    // Underline grows
    _lineWidth = _interval(700, 900, Curves.easeOut);

    // Subtitle fades
    _subOpacity = _interval(900, 1100);

    _ctrl.forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _navigate();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration:        Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder:               (ctx, a1, a2) => screen,
      ),
    );
  }

  Future<void> _navigate() async {
    final svc = OnboardingService.instance;

    final tutorial   = await svc.hasSeenTutorial();
    final auth       = await svc.hasSeenAuth();
    final onboarding = await svc.hasCompletedOnboarding();

    debugPrint('=== SPLASH FLAGS ===');
    debugPrint('tutorial=$tutorial');
    debugPrint('auth=$auth');
    debugPrint('onboarding=$onboarding');
    debugPrint('====================');

    if (!mounted) return;

    if (!tutorial) {
      _go(const TutorialScreen());
    } else if (!onboarding) {
      _go(const SpecialtyOnboardingScreen());
    } else {
      _go(const MainShell());
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kTeal,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── "Med" + "Shelf" row ──────────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // "Med" — slides from left
                    FractionalTranslation(
                      translation: _medSlide.value,
                      child: Opacity(
                        opacity: _medOpacity.value.clamp(0.0, 1.0),
                        child: Text(
                          'Med',
                          style: GoogleFonts.nunito(
                            fontSize:   56,
                            fontWeight: FontWeight.w900,
                            color:      Colors.white,
                            height:     1.0,
                          ),
                        ),
                      ),
                    ),
                    // "Shelf" — slides from right
                    FractionalTranslation(
                      translation: _shelfSlide.value,
                      child: Opacity(
                        opacity: _shelfOpacity.value.clamp(0.0, 1.0),
                        child: Text(
                          'Shelf',
                          style: GoogleFonts.nunito(
                            fontSize:   56,
                            fontWeight: FontWeight.w900,
                            color:      _kCoral,
                            height:     1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Underline ──────────────────────────────────────────────────
                Container(
                  width:  200 * _lineWidth.value,
                  height: 2,
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Subtitle ───────────────────────────────────────────────────
                Opacity(
                  opacity: _subOpacity.value.clamp(0.0, 1.0),
                  child: Text(
                    'Your Medical Library',
                    style: GoogleFonts.nunito(
                      fontSize:      14,
                      fontWeight:    FontWeight.w400,
                      color:         Colors.white.withAlpha(191), // ~0.75
                      letterSpacing: 2.0,
                      height:        1.0,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
