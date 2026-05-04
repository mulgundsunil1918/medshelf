import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Coach Mark Step ──────────────────────────────────────────────────────────

/// A single step in an interactive walkthrough — points to a real UI element
/// and shows a tooltip explaining what it does.
class CoachStep {
  const CoachStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.icon,
    this.tooltipPosition = TooltipPosition.below,
    this.padding = 8,
    this.shape = SpotlightShape.rect,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData? icon;
  final TooltipPosition tooltipPosition;

  /// Extra padding around the target when drawing the spotlight.
  final double padding;

  final SpotlightShape shape;
}

enum TooltipPosition { above, below }

enum SpotlightShape { rect, circle }

// ─── Public entrypoint ────────────────────────────────────────────────────────

/// Show an interactive coach mark walkthrough on top of the current screen.
/// Returns once the user finishes or skips.
Future<void> showCoachMarks(
  BuildContext context, {
  required List<CoachStep> steps,
}) async {
  if (steps.isEmpty) return;
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, a1, a2) => _CoachMarkRoute(steps: steps),
      transitionsBuilder: (ctx, anim, secAnim, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

// ─── Internal route widget ────────────────────────────────────────────────────

class _CoachMarkRoute extends StatefulWidget {
  const _CoachMarkRoute({required this.steps});
  final List<CoachStep> steps;

  @override
  State<_CoachMarkRoute> createState() => _CoachMarkRouteState();
}

class _CoachMarkRouteState extends State<_CoachMarkRoute> {
  static const _kCoral = Color(0xFFE8835A);

  int _index = 0;

  void _next() {
    if (_index < widget.steps.length - 1) {
      setState(() => _index++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip() => Navigator.of(context).pop();

  /// Locate the target element on screen using its GlobalKey.
  Rect? _findTargetRect(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final size = MediaQuery.of(context).size;
    final targetRect = _findTargetRect(step.targetKey);

    // Fallback if target not on screen — show centered dialog instead.
    if (targetRect == null) {
      return Material(
        color: Colors.black54,
        child: Center(
          child: _TooltipCard(
            step: step,
            stepIndex: _index,
            totalSteps: widget.steps.length,
            onNext: _next,
            onSkip: _skip,
          ),
        ),
      );
    }

    final inflated = targetRect.inflate(step.padding);
    final tooltipBelow = step.tooltipPosition == TooltipPosition.below;

    // Where the tooltip card appears, with sensible defaults that flip if
    // there's not enough room on the chosen side.
    double tooltipTop;
    if (tooltipBelow) {
      final wanted = inflated.bottom + 16;
      tooltipTop = wanted + 200 < size.height
          ? wanted
          : (inflated.top - 200 - 16).clamp(24.0, size.height - 220);
    } else {
      final wanted = inflated.top - 200 - 16;
      tooltipTop = wanted > 24
          ? wanted
          : inflated.bottom + 16;
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Dimmed backdrop with spotlight cutout ──────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              child: CustomPaint(
                painter: _SpotlightPainter(
                  rect: inflated,
                  shape: step.shape,
                ),
              ),
            ),
          ),

          // ── Glowing border around the target ─────────────────────────
          Positioned(
            left: inflated.left,
            top: inflated.top,
            width: inflated.width,
            height: inflated.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: step.shape == SpotlightShape.circle
                      ? null
                      : BorderRadius.circular(14),
                  shape: step.shape == SpotlightShape.circle
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  border: Border.all(color: _kCoral, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _kCoral.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Tooltip card ────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            top: tooltipTop,
            child: _TooltipCard(
              step: step,
              stepIndex: _index,
              totalSteps: widget.steps.length,
              onNext: _next,
              onSkip: _skip,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spotlight painter — dim everything except the cutout ────────────────────

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.rect, required this.shape});

  final Rect rect;
  final SpotlightShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.78);

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path();

    if (shape == SpotlightShape.circle) {
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final radius = (rect.shortestSide / 2) + 4;
      cutoutPath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    } else {
      cutoutPath.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    }

    final combined = Path.combine(PathOperation.difference, fullPath, cutoutPath);
    canvas.drawPath(combined, dim);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.rect != rect || old.shape != shape;
}

// ─── Tooltip card with title, description, progress dots, buttons ────────────

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final CoachStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const _kTeal = Color(0xFF006B74);
  static const _kCoral = Color(0xFFE8835A);

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == totalSteps - 1;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: icon + title ─────────────────────────────────
            Row(
              children: [
                if (step.icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _kCoral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(step.icon, color: _kCoral, size: 22),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    step.title,
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _kTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Description ─────────────────────────────────────────
            Text(
              step.description,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // ── Progress dots ──────────────────────────────────────
            Row(
              children: [
                ...List.generate(totalSteps, (i) {
                  final active = i == stepIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: active ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? _kCoral : _kTeal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
                const Spacer(),

                // ── Skip ─────────────────────────────────────────
                if (!isLast)
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),

                // ── Next / Done ──────────────────────────────────
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kCoral,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onNext,
                  child: Text(
                    isLast ? 'Got it!' : 'Next →',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
