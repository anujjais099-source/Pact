import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/pact_level.dart';
import '../theme/pact_colors.dart';

/// The hero of the Home screen: the shared streak, wrapped in a ring that fills
/// as the pair climbs toward the next level.
class StreakRing extends StatelessWidget {
  const StreakRing({
    super.key,
    required this.streak,
    required this.level,
    this.size = 232,
    this.bothGreenToday = false,
  });

  final int streak;
  final PactLevel level;
  final double size;
  final bool bothGreenToday;

  @override
  Widget build(BuildContext context) {
    final progress = level.progress(streak);
    final remaining = level.daysToNext(streak);

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0, 1)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: value,
                color: level.color,
                glow: bothGreenToday,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$streak',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: size * 0.34,
                      color: streak == 0 ? PactColors.textSecondary : PactColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                streak == 1 ? 'day together' : 'days together',
                style: const TextStyle(
                  color: PactColors.textSecondary,
                  fontSize: 13.5,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: level.color.withValues(alpha: 0.12),
                  borderRadius: Radii.pill,
                ),
                child: Text(
                  level.label,
                  style: TextStyle(
                    color: level.color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (remaining != null && streak > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$remaining to ${level.next?.label ?? ''}',
                  style: const TextStyle(color: PactColors.textTertiary, fontSize: 11.5),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color, required this.glow});

  final double progress;
  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width / 2) - 10;
    const start = -math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = PactColors.surfaceHigh;

    canvas.drawCircle(center, radius, track);

    if (glow) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..color = color.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + (2 * math.pi),
        colors: [color.withValues(alpha: 0.55), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.glow != glow;
}
