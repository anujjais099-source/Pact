import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/pact_colors.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../data/models/pact_level.dart';
import '../../state/checkin_controller.dart';

/// The reward moment. It says one of two things, and the difference is the
/// whole emotional engine: you are done, versus you are both done.
class CheckInSuccessScreen extends ConsumerWidget {
  const CheckInSuccessScreen({
    super.key,
    required this.streak,
    required this.bothGreen,
  });

  final int streak;
  final bool bothGreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final level = PactLevel.forStreak(streak);
    final levelledUp = bothGreen && streak == level.from;

    return PopScope(
      canPop: false,
      child: PactScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            _Seal(color: bothGreen ? level.color : PactColors.green, done: bothGreen),
            Gap.h32,
            Text(
              bothGreen ? 'Day $streak.\nBoth of you.' : 'Your half\nis done.',
              style: t.displayMedium,
            ),
            Gap.h16,
            Text(
              bothGreen
                  ? 'Neither of you blinked today. The streak holds.'
                  : 'Your proof is in. The day only counts once your partner checks in too.',
              style: t.bodyMedium?.copyWith(fontSize: 15.5),
            ),
            if (levelledUp) ...[
              Gap.h24,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: level.color.withValues(alpha: 0.1),
                  borderRadius: Radii.md,
                  border: Border.all(color: level.color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 17, color: level.color),
                    Gap.w12,
                    Expanded(
                      child: Text(
                        '${level.label} unlocked.',
                        style: TextStyle(
                          color: level.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(flex: 3),
            PactButton(
              label: 'Back to my Pact',
              onPressed: () {
                ref.read(checkInControllerProvider.notifier).reset();
                context.go(Routes.home);
              },
            ),
            Gap.h16,
          ],
        ),
      ),
    );
  }
}

class _Seal extends StatelessWidget {
  const _Seal({required this.color, required this.done});

  final Color color;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        height: 86,
        width: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Icon(
          done ? Icons.handshake_rounded : Icons.check_rounded,
          color: color,
          size: 40,
        ),
      ),
    );
  }
}
