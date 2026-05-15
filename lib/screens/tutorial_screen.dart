import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/onboarding_service.dart';
import 'specialty_onboarding_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTeal     = Color(0xFF006B74);
const _kDarkTeal = Color(0xFF004A52);
const _kCoral    = Color(0xFFE8835A);
const _kWaGreen  = Color(0xFF25D366);

// ─── TutorialScreen ──────────────────────────────────────────────────────────

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.fromSettings = false});

  /// When true (opened from Settings), finishing/skipping pops back instead
  /// of pushing the onboarding flow.
  final bool fromSettings;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  // Called ONLY by the final slide's "Set Up My Library →" CTA button.
  // This is the sole place where markTutorialSeen() fires.
  Future<void> _finish() async {
    if (widget.fromSettings) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await OnboardingService.instance.markTutorialSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SpecialtyOnboardingScreen(),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // Called by the Skip button on slides 1–3.
  // Does NOT mark the tutorial as seen — the user must reach the final
  // slide and tap the CTA for that to happen.
  Future<void> _skip() async {
    if (widget.fromSettings) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SpecialtyOnboardingScreen(),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _nextPage() => _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  void _prevPage() => _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kTeal, _kDarkTeal],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Skip button ───────────────────────────────────────────────
              SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _currentPage < 3 ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: _currentPage >= 3,
                      child: TextButton(
                        onPressed: _skip,
                        child: Text(
                          'Skip',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Slides ────────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _Slide1(),
                    _Slide2(),
                    _Slide3(),
                    _Slide4(onCta: _finish),
                  ],
                ),
              ),

              // ── Bottom nav ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  children: [
                    // Back
                    SizedBox(
                      width: 80,
                      child: _currentPage > 0
                          ? TextButton(
                              onPressed: _prevPage,
                              child: Text(
                                '← Back',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const Spacer(),

                    // Page dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(4, (i) {
                        final active = i == _currentPage;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: active ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? _kCoral
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),

                    const Spacer(),

                    // Next (hidden on slide 4)
                    SizedBox(
                      width: 80,
                      child: _currentPage < 3
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _kCoral,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _nextPage,
                              child: Text(
                                'Next →',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared text helpers ──────────────────────────────────────────────────────

TextStyle _headline() => GoogleFonts.nunito(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );

TextStyle _body() => GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Colors.white.withValues(alpha: 0.85),
      height: 1.6,
    );

TextStyle _subtext() => GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _kCoral,
    );

// ─── Shared slide shell ───────────────────────────────────────────────────────

class _SlideShell extends StatelessWidget {
  const _SlideShell({
    required this.illustration,
    required this.headline,
    required this.body,
    this.subtext,
    this.bottomWidget,
  });

  final Widget illustration;
  final String headline;
  final String body;
  final String? subtext;
  final Widget? bottomWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            flex: 45,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: illustration,
            ),
          ),
          Expanded(
            flex: 55,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(headline, style: _headline(), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                Text(body, style: _body(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (subtext != null)
                  Text(subtext!, style: _subtext(), textAlign: TextAlign.center),
                if (bottomWidget != null) ...[
                  const SizedBox(height: 16),
                  bottomWidget!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SLIDE 1 — Problem hook ───────────────────────────────────────────────────

class _Slide1 extends StatefulWidget {
  @override
  State<_Slide1> createState() => _Slide1State();
}

class _Slide1State extends State<_Slide1> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: -3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _shakeCtrl.forward().then((_) {
        if (!mounted) return;
        _shakeCtrl.reset();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _shakeCtrl.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      headline: "Tired of losing important files in WhatsApp? 😤",
      body: "Important guidelines, lecture PDFs, reference videos... shared in a "
          "group, scrolled away, impossible to find. Every doctor knows this pain.",
      subtext: "MedShelf fixes that — forever.",
      illustration: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) =>
            Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
        child: _WhatsAppMock().animate().fadeIn(duration: 600.ms),
      ),
    );
  }
}

class _WhatsAppMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Chat bubbles
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _WaBubble('📄 NRP Guidelines 2024.pdf'),
                  _WaBubble('🎥 Ventilation_technique.mp4'),
                  _WaBubble('📊 ICU Sepsis Protocol.pptx'),
                ],
              ),
            ),
            // Dark overlay
            Container(color: Colors.black.withValues(alpha: 0.45)),
            // ❌ + caption
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('❌', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 6),
                  Text(
                    'Scrolled away. Gone forever.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaBubble extends StatelessWidget {
  const _WaBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kWaGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── SLIDE 2 — Share flow ─────────────────────────────────────────────────────

class _Slide2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      headline: "Save anything, from anywhere. 📥",
      body: "Share from WhatsApp / Telegram / Gmail · import from your device · "
          "or tap Scan to capture paper documents with the camera — auto-edge, "
          "auto-crop, fully offline.",
      subtext: "PDFs, PPTs, videos, images, Word files — and rich notes too.",
      illustration: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 4-step flow
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FlowStep(
                icon: Text('W',
                    style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                circleColor: _kWaGreen,
                label: 'WhatsApp',
                delay: 0,
              ),
              const _FlowArrow(delay: 100),
              _FlowStep(
                icon: const Icon(Icons.share, color: Colors.white, size: 24),
                circleColor: Colors.white,
                circleColorOpacity: 0.2,
                label: 'Tap Share',
                delay: 200,
              ),
              const _FlowArrow(delay: 300),
              _FlowStep(
                icon: const Text('📚', style: TextStyle(fontSize: 24)),
                circleColor: _kTeal,
                hasBorder: true,
                label: 'MedShelf',
                delay: 400,
              ),
              const _FlowArrow(delay: 500),
              _FlowStep(
                icon: const Icon(Icons.check, color: Colors.white, size: 26),
                circleColor: const Color(0xFF4CAF50),
                label: 'Saved!',
                delay: 600,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // File type chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: const [
                _TypeChip('📄 PDF'),
                _TypeChip('📊 PPT'),
                _TypeChip('🎥 Video'),
                _TypeChip('🖼️ Image'),
                _TypeChip('📝 Word'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.circleColor,
    required this.label,
    required this.delay,
    this.circleColorOpacity = 1.0,
    this.hasBorder = false,
  });

  final Widget icon;
  final Color circleColor;
  final double circleColorOpacity;
  final String label;
  final int delay;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: circleColorOpacity < 1.0
                ? circleColor.withValues(alpha: circleColorOpacity)
                : circleColor,
            shape: BoxShape.circle,
            border: hasBorder ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Center(child: icon),
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
            .slideY(
                begin: 0.3,
                delay: Duration(milliseconds: delay),
                duration: 400.ms,
                curve: Curves.easeOut),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: delay + 100), duration: 300.ms),
      ],
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow({required this.delay});
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20)
          .animate()
          .fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── SLIDE 3 — Folder tree ────────────────────────────────────────────────────

class _Slide3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      headline: "Your personal medical library 🗂️",
      body: "Files go into Specialty → Topic → Subtopic folders — exactly the way "
          "medical knowledge is structured. Every folder is customisable.",
      subtext: "You set it up once. MedShelf remembers everything.",
      illustration: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _FolderRow(
              depth: 0,
              emoji: '🫁',
              name: 'Pediatrics',
              badge: '24 files',
              bold: true,
              fontSize: 14,
              delay: 0,
            ),
            _FolderRow(
              depth: 1,
              emoji: '👶',
              name: 'Neonatology',
              badge: '12 files',
              bold: false,
              fontSize: 13,
              delay: 150,
            ),
            _FolderRow(
              depth: 2,
              emoji: '💨',
              name: 'Resuscitation',
              badge: '5 files',
              bold: false,
              fontSize: 12,
              delay: 300,
            ),
            _FileRow(
              depth: 3,
              iconColor: Colors.red,
              name: 'NRP_Guidelines_2024.pdf',
              delay: 450,
            ),
            _FileRow(
              depth: 3,
              iconColor: Colors.orange,
              name: 'Ventilation_Protocol.pptx',
              delay: 600,
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.depth,
    required this.emoji,
    required this.name,
    required this.badge,
    required this.bold,
    required this.fontSize,
    required this.delay,
  });

  final int depth;
  final String emoji;
  final String name;
  final String badge;
  final bool bold;
  final double fontSize;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: 8),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: fontSize)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.nunito(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kCoral,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideX(
            begin: -0.2,
            delay: Duration(milliseconds: delay),
            duration: 400.ms,
            curve: Curves.easeOut);
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.depth,
    required this.iconColor,
    required this.name,
    required this.delay,
  });

  final int depth;
  final Color iconColor;
  final String name;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: 8),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: iconColor, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideX(
            begin: -0.2,
            delay: Duration(milliseconds: delay),
            duration: 400.ms,
            curve: Curves.easeOut);
  }
}

// ─── SLIDE 4 — Search ─────────────────────────────────────────────────────────

class _Slide4 extends StatelessWidget {
  const _Slide4({required this.onCta});
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      headline: "Find · Share · Stay focused 🔍",
      body: "Search any file by name, type, or specialty. Tap Share next to any "
          "file to send it to a colleague on WhatsApp, Email or any other app — "
          "in two taps.",
      bottomWidget: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onCta,
          child: Text(
            'Set Up My Library →',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kTeal,
            ),
          ),
        ),
      ),
      illustration: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fake search bar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'NRP guidelines',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SearchTile(
              circleColor: Colors.red,
              fileIcon: Icons.picture_as_pdf,
              fileName: 'NRP_Guidelines_2024.pdf',
              specialty: '🫁 Pediatrics',
              delay: 200,
            ),
            _SearchTile(
              circleColor: Colors.orange,
              fileIcon: Icons.slideshow,
              fileName: 'Ventilation_Slides.pptx',
              specialty: '🫁 Pediatrics',
              delay: 400,
            ),
            _SearchTile(
              circleColor: Colors.blue,
              fileIcon: Icons.description,
              fileName: 'Sepsis_Protocol.docx',
              specialty: '🫀 General Medicine',
              delay: 600,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({
    required this.circleColor,
    required this.fileIcon,
    required this.fileName,
    required this.specialty,
    required this.delay,
  });

  final Color circleColor;
  final IconData fileIcon;
  final String fileName;
  final String specialty;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(fileIcon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kCoral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    specialty,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.5), size: 16),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideY(
            begin: 0.2,
            delay: Duration(milliseconds: delay),
            duration: 400.ms,
            curve: Curves.easeOut);
  }
}
