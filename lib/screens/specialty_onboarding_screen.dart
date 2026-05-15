import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/medical_specialties.dart';
import '../services/onboarding_service.dart';
import '../services/topic_service.dart';
import 'main_shell.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTeal = Color(0xFF006B74);

// ─── SpecialtyOnboardingScreen ────────────────────────────────────────────────

class SpecialtyOnboardingScreen extends StatefulWidget {
  const SpecialtyOnboardingScreen({super.key});

  @override
  State<SpecialtyOnboardingScreen> createState() =>
      _SpecialtyOnboardingScreenState();
}

class _SpecialtyOnboardingScreenState extends State<SpecialtyOnboardingScreen> {
  final _pageCtrl = PageController();

  final Set<String> _selected = {};
  final List<String> _customSpecialties = [];

  String _progressLabel = '';
  double _progress = 0;
  bool _done = false;

  final _specialtyKeys = medicalSpecialties.keys.toList();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    setState(() {});
  }

  void _goToApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainShell(),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _skip() async {
    await OnboardingService.instance.setOnboardingComplete();
    if (mounted) _goToApp();
  }

  Future<void> _showAddCustomDialog() async {
    final nameCtrl = TextEditingController();
    String pickedEmoji = '📁';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Create Custom Specialty'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      const emojis = [
                        '📁', '🏥', '💊', '🩺', '🔬', '🧬', '🧪', '💉',
                        '🩸', '🧠', '❤️', '🦴', '🌡️', '🦷', '👁️', '🚨',
                      ];
                      final current = emojis.indexOf(pickedEmoji);
                      setS(() {
                        pickedEmoji = emojis[(current + 1) % emojis.length];
                      });
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(pickedEmoji,
                          style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Specialty name',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the emoji to change it',
                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _customSpecialties.add('$name $pickedEmoji');
                    _selected.add('$name $pickedEmoji');
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFolders() async {
    if (_selected.isEmpty) return;
    setState(() {
      _progress = 0;
      _done = false;
    });
    _goTo(2);

    final ts = Provider.of<TopicService>(context, listen: false);
    final selectedList = _selected.toList();
    final total = selectedList.length;

    for (int i = 0; i < total; i++) {
      if (!mounted) return;
      final specialtyKey = selectedList[i];
      final specialtyName = extractName(specialtyKey);
      final specialtyEmoji = extractEmoji(specialtyKey);

      setState(() => _progressLabel = 'Creating $specialtyName...');

      final specialty = await ts.addTopic(
        name: specialtyName,
        emoji: specialtyEmoji,
        parentId: null,
      );

      final topics = medicalSpecialties[specialtyKey] ?? [];
      for (final topicKey in topics) {
        await ts.addTopic(
          name: extractName(topicKey),
          emoji: extractEmoji(topicKey),
          parentId: specialty.id,
        );
      }

      if (!mounted) return;
      setState(() => _progress = (i + 1) / total);
    }

    await OnboardingService.instance
        .saveSelectedSpecialties(selectedList.map(extractName).toList());
    await OnboardingService.instance.setOnboardingComplete();
    await ts.hideDefaultSpecialties();

    if (mounted) {
      setState(() {
        _done = true;
        _progressLabel = '✅ Your library is ready!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kTeal,
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomePage(
            onGetStarted: () => _goTo(1),
            onSkip: _skip,
          ),
          _SelectSpecialtiesPage(
            selected: _selected,
            specialtyKeys: _specialtyKeys,
            customSpecialties: _customSpecialties,
            onToggle: (key) => setState(() {
              if (_selected.contains(key)) {
                _selected.remove(key);
              } else {
                _selected.add(key);
              }
            }),
            onSelectAll: () => setState(() {
              if (_selected.length == _specialtyKeys.length) {
                _selected.clear();
              } else {
                _selected.addAll(_specialtyKeys);
              }
            }),
            onAddCustom: _showAddCustomDialog,
            onContinue: _createFolders,
            onBack: () => _goTo(0),
            onSkip: _skip,
          ),
          _CreatingPage(
            progress: _progress,
            label: _progressLabel,
            done: _done,
            onStart: _goToApp,
          ),
        ],
      ),
    );
  }
}

// ─── Page 1: Welcome ─────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onGetStarted, required this.onSkip});
  final VoidCallback onGetStarted;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // App icon
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/icon/app_icon.jpg',
                width: 100,
                height: 100,
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Choose Your Specialties',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "We'll create your library folders automatically",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Folder icon
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 20),

            Text(
              "We'll set up your library with the right\nspecialties for your field.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),

            const Spacer(),

            // Get Started button — white bg, teal text
            FilledButton(
              onPressed: onGetStarted,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Get Started →',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kTeal,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Skip — white text, opacity 0.7
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip Setup',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Page 2: Select Specialties ───────────────────────────────────────────────

class _SelectSpecialtiesPage extends StatelessWidget {
  const _SelectSpecialtiesPage({
    required this.selected,
    required this.specialtyKeys,
    required this.customSpecialties,
    required this.onToggle,
    required this.onSelectAll,
    required this.onAddCustom,
    required this.onContinue,
    required this.onBack,
    required this.onSkip,
  });

  final Set<String> selected;
  final List<String> specialtyKeys;
  final List<String> customSpecialties;
  final void Function(String) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onAddCustom;
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.length == specialtyKeys.length;
    final preBuiltCount = specialtyKeys.length;
    final customCount = customSpecialties.length;
    final totalCount = preBuiltCount + customCount + 1;

    return Scaffold(
      backgroundColor: _kTeal,
      appBar: AppBar(
        backgroundColor: _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: onBack,
        ),
        title: const Text(
          'Choose Specialties',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: onSelectAll,
            child: Text(
              allSelected ? 'Clear All' : 'Select All',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: totalCount,
              itemBuilder: (context, i) {
                if (i < preBuiltCount) {
                  final key = specialtyKeys[i];
                  final name = extractName(key);
                  final emoji = extractEmoji(key);
                  final topicCount = medicalSpecialties[key]?.length ?? 0;
                  final isSel = selected.contains(key);
                  return _GridSpecialtyCard(
                    emoji: emoji,
                    name: name,
                    topicCount: topicCount,
                    isSelected: isSel,
                    onTap: () => onToggle(key),
                  );
                }
                final ci = i - preBuiltCount;
                if (ci < customCount) {
                  final key = customSpecialties[ci];
                  final name = extractName(key);
                  final emoji = extractEmoji(key);
                  final isSel = selected.contains(key);
                  return _GridSpecialtyCard(
                    emoji: emoji,
                    name: name,
                    topicCount: 0,
                    isSelected: isSel,
                    onTap: () => onToggle(key),
                  );
                }
                return _CreateMyOwnCard(onTap: onAddCustom);
              },
            ),
          ),

          _BottomBar(
            label:
                '${selected.length} specialt${selected.length == 1 ? 'y' : 'ies'} selected',
            canContinue: selected.isNotEmpty,
            onContinue: onContinue,
            onSkip: onSkip,
          ),
        ],
      ),
    );
  }
}

// ─── Grid Specialty Card ─────────────────────────────────────────────────────

class _GridSpecialtyCard extends StatelessWidget {
  const _GridSpecialtyCard({
    required this.emoji,
    required this.name,
    required this.topicCount,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final String name;
  final int topicCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 14, color: _kTeal),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (topicCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$topicCount topics',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
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

// ─── "Create My Own" card ────────────────────────────────────────────────────

class _CreateMyOwnCard extends StatelessWidget {
  const _CreateMyOwnCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
            color: Colors.white.withValues(alpha: 0.5), radius: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 36, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Create My Own',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashLen = 6.0;
    const gapLen = 4.0;
    final r = Radius.circular(radius);
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), r);
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics().first;
    double dist = 0;
    while (dist < metrics.length) {
      final end = (dist + dashLen).clamp(0.0, metrics.length);
      canvas.drawPath(metrics.extractPath(dist, end), paint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.canContinue,
    required this.onContinue,
    required this.onSkip,
  });

  final String label;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          // Continue — white bg, teal text
          FilledButton(
            onPressed: canContinue ? onContinue : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Continue →',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: canContinue ? _kTeal : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Skip — white text, opacity 0.7
          TextButton(
            onPressed: onSkip,
            child: Text(
              'Skip',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 3: Creating ─────────────────────────────────────────────────────────

class _CreatingPage extends StatelessWidget {
  const _CreatingPage({
    required this.progress,
    required this.label,
    required this.done,
    required this.onStart,
  });

  final double progress;
  final String label;
  final bool done;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kTeal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📚', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 24),
              Text(
                done ? 'Your library is ready!' : 'Setting up your library...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done ? 1.0 : (progress == 0 ? null : progress),
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (done)
                // Start Using — white bg, teal text
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Start Using MedShelf',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kTeal,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
