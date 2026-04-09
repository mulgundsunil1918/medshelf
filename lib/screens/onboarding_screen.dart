import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/onboarding_service.dart';
import 'specialty_onboarding_screen.dart';

// ─── Page data ────────────────────────────────────────────────────────────────

class _Page {
  const _Page({
    required this.emoji,
    required this.title,
    required this.description,
    required this.accent,
    required this.items,
    this.useAppIcon = false,
    this.showShareFlow = false,
    this.footnote,
  });
  final String emoji;
  final String title;
  final String description;
  final Color accent;
  final List<String> items;
  final bool useAppIcon;
  final bool showShareFlow;
  final String? footnote;
}

const _kPages = [
  _Page(
    emoji: '📚',
    title: 'Welcome to MedShelf 📚',
    description: 'Your personal medical knowledge library.',
    accent: Color(0xFF007A85),
    items: [],
    useAppIcon: true,
  ),
  _Page(
    emoji: '📤',
    title: 'Save from Any App',
    description:
        'Open any file in WhatsApp, Gmail, Telegram or any app → tap Share → choose MedShelf → choose folder → saved!',
    accent: Color(0xFF6A1B9A),
    items: [],
    showShareFlow: true,
  ),
  _Page(
    emoji: '📁',
    title: 'Organised by Specialty',
    description:
        'Files are organised into Specialties → Topics → Subtopics. '
        'You can create your own folders or use our pre-built medical hierarchy.',
    accent: Color(0xFF00695C),
    items: [
      '🏥  Specialties (e.g. Cardiology)',
      '📂  Topics (e.g. Heart Failure)',
      '📄  Subtopics (e.g. Management)',
    ],
    footnote: 'You can edit, add, or delete specialties anytime in Settings ⚙️',
  ),
  _Page(
    emoji: '🔍',
    title: 'Find Anything Instantly',
    description:
        'Search across all your files, notes, and documents in one tap.',
    accent: Color(0xFF1565C0),
    items: [
      '🔖  Bookmark critical references',
      '📝  Quick clinical notes anywhere',
      '⚡  All offline — no internet needed',
    ],
  ),
];

// ─── Onboarding Screen ────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.fromSettings = false});

  /// When true (opened from Settings), tapping "Get Started" just pops back.
  final bool fromSettings;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const int _total = 4;

  void _nextPage() {
    if (_currentPage < _total - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    if (widget.fromSettings) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await OnboardingService.instance.markTutorialSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SpecialtyOnboardingScreen(),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _kPages[_currentPage];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // ── Hero area ──────────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _total,
              itemBuilder: (context, index) =>
                  _HeroPage(page: _kPages[index], pageIndex: index),
            ),
          ),

          // ── Content card ───────────────────────────────────────────────────
          Expanded(
            flex: 6,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position:
                      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                          .animate(anim),
                  child: child,
                ),
              ),
              child: _ContentCard(
                key: ValueKey(_currentPage),
                page: page,
              ),
            ),
          ),

          // ── Prev / Dots / Next ─────────────────────────────────────────────
          _BottomBar(
            currentPage: _currentPage,
            total: _total,
            accent: page.accent,
            isFirst: _currentPage == 0,
            isLast: _currentPage == _total - 1,
            onPrevious: _prevPage,
            onNext: _nextPage,
          ),
        ],
      ),
    );
  }
}

// ─── Hero Page ────────────────────────────────────────────────────────────────

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.page, required this.pageIndex});

  final _Page page;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    // Page 0 (welcome with app icon) uses its own full layout
    if (page.useAppIcon) {
      return _AppIconHero(pageIndex: pageIndex);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [page.accent, page.accent.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: -20, left: -30,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),

          // Hero content
          Center(
            child: page.showShareFlow
                ? _ShareFlowHero(pageIndex: pageIndex)
                : _EmojiHero(emoji: page.emoji, pageIndex: pageIndex),
          ),
        ],
      ),
    );
  }
}

class _EmojiHero extends StatelessWidget {
  const _EmojiHero({required this.emoji, required this.pageIndex});
  final String emoji;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(40),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 64)),
    )
        .animate(key: ValueKey('emoji_$pageIndex'))
        .scale(
          begin: const Offset(0.6, 0.6), end: const Offset(1, 1),
          duration: 500.ms, curve: Curves.elasticOut,
        )
        .fade(duration: 300.ms);
  }
}

class _AppIconHero extends StatelessWidget {
  const _AppIconHero({required this.pageIndex});
  final int pageIndex;

  static const _kTeal     = Color(0xFF006B74);
  static const _kTealDark = Color(0xFF003D45);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      height: size.height * 0.42,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kTeal, _kTealDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon with glow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withAlpha(60),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 140, height: 140,
              ),
            ),
          )
              .animate(key: ValueKey('icon_$pageIndex'))
              .scale(
                begin: const Offset(0.6, 0.6), end: const Offset(1, 1),
                duration: 500.ms, curve: Curves.elasticOut,
              )
              .fade(duration: 300.ms),
          const SizedBox(height: 24),
          const Text(
            'Welcome, Doctor! 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ).animate().fade(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            "Let's set up your personal",
            style: TextStyle(
              color: Colors.white.withAlpha(217),
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ).animate().fade(delay: 300.ms, duration: 400.ms),
          Text(
            'medical library 📚',
            style: TextStyle(
              color: Colors.white.withAlpha(217),
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ).animate().fade(delay: 380.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

class _ShareFlowHero extends StatelessWidget {
  const _ShareFlowHero({required this.pageIndex});
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FlowBox(label: 'WhatsApp\n/ Gmail', emoji: '💬', color: const Color(0xFF25D366)),
            _FlowArrow(),
            _FlowBox(label: 'Share', emoji: '📤', color: Colors.white.withAlpha(60)),
            _FlowArrow(),
            _FlowBox(label: 'MedShelf', emoji: '📚', color: const Color(0xFF007A85)),
          ],
        ),
      ],
    )
        .animate(key: ValueKey('flow_$pageIndex'))
        .fade(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}

class _FlowBox extends StatelessWidget {
  const _FlowBox({required this.label, required this.emoji, required this.color});
  final String label;
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.arrow_forward_rounded, color: Colors.white.withAlpha(200), size: 20),
    );
  }
}

// ─── Welcome feature cards (page 0 only) ─────────────────────────────────────

class _WelcomeFeatureCards extends StatelessWidget {
  const _WelcomeFeatureCards({required this.page});
  final _Page page;

  static const _kTeal = Color(0xFF006B74);

  static const _features = [
    ('📤', 'Share from any app', 'WhatsApp, Gmail, Telegram & more'),
    ('📁', 'Organised by specialty', 'Your folders, your structure'),
    ('🔍', 'Find anything instantly', 'Search across all your files'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._features.asMap().entries.map((e) {
            final delay = Duration(milliseconds: 80 + e.key * 80);
            final (emoji, title, subtitle) = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _kTeal.withAlpha(18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _kTeal.withAlpha(40), width: 1),
                ),
                child: Row(
                  children: [
                    Text(emoji,
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withAlpha(140),
                            )),
                      ],
                    ),
                  ],
                ),
              ).animate().fade(delay: delay, duration: 350.ms).slideY(
                    begin: 0.15,
                    end: 0,
                    delay: delay,
                    duration: 350.ms,
                    curve: Curves.easeOut,
                  ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'You can edit specialties anytime in Settings ⚙️',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withAlpha(100),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Content Card ─────────────────────────────────────────────────────────────

class _ContentCard extends StatelessWidget {
  const _ContentCard({super.key, required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    if (page.useAppIcon) return _WelcomeFeatureCards(page: page);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page.title,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: cs.onSurface,
            ),
          )
              .animate()
              .fade(duration: 400.ms, delay: 50.ms)
              .slide(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
                duration: 400.ms,
                delay: 50.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 10),
          Text(
            page.description,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          )
              .animate()
              .fade(duration: 400.ms, delay: 120.ms)
              .slide(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
                duration: 400.ms,
                delay: 120.ms,
                curve: Curves.easeOut,
              ),
          if (page.items.isNotEmpty) ...[
            const SizedBox(height: 18),
            ...page.items.asMap().entries.map((e) {
              final delay = Duration(milliseconds: 200 + e.key * 80);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  e.value,
                  style: tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: cs.onSurface.withAlpha(222),
                  ),
                )
                    .animate()
                    .fade(duration: 350.ms, delay: delay)
                    .slide(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                      duration: 350.ms,
                      delay: delay,
                      curve: Curves.easeOut,
                    ),
              );
            }),
          ],
          if (page.footnote != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                page.footnote!,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ).animate().fade(duration: 400.ms, delay: 400.ms),
          ],
        ],
      ),
    );
  }
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.total,
    required this.accent,
    required this.isFirst,
    required this.isLast,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int total;
  final Color accent;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            // Previous button (hidden on first page, but keeps space)
            SizedBox(
              width: 96,
              child: AnimatedOpacity(
                opacity: isFirst ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: TextButton.icon(
                  onPressed: isFirst ? null : onPrevious,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Prev'),
                ),
              ),
            ),

            // Dot indicators — centred
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final isActive = i == currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? accent
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Next / Get Started button
            SizedBox(
              width: 130,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? 'Get Started' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (!isLast) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
