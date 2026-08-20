import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/pact_colors.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_loader.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../state/matchmaking_controller.dart';
import '../../state/providers.dart';

/// Waiting is the weakest moment in the funnel, so the screen keeps talking:
/// what is happening, what the rules are, and how to leave.
class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen> {
  @override
  void initState() {
    super.initState();
    // If we were already enqueued from a previous session, do not re-enqueue.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final queued = await ref.read(inQueueProvider.future);
      if (!mounted) return;
      if (!queued) ref.read(matchmakingControllerProvider.notifier).find();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value;
    final match = ref.watch(matchmakingControllerProvider);
    final queued = ref.watch(inQueueProvider).value ?? false;
    final searching = queued || match.phase == MatchPhase.searching;

    // The server may pair us at any moment; the user document is the signal.
    ref.listen(matchArrivedProvider, (_, pactId) {
      if (pactId != null) {
        ref.read(matchmakingControllerProvider.notifier).confirmMatched(pactId);
      }
    });

    return PactScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const _SearchPulse(),
          Gap.h32,
          Text(
            searching ? 'Finding someone\nas serious as you.' : 'Ready when you are.',
            style: t.headlineMedium,
          ),
          Gap.h12,
          Text(
            searching
                ? 'You will be paired with one stranger who also committed to a daily goal. No chat, no profiles — just the two of you and a streak.'
                : 'Join the pool and we will pair you with one stranger.',
            style: t.bodyMedium?.copyWith(fontSize: 15),
          ),
          Gap.h24,
          _Rule(text: 'Goal: ${me?.goalName ?? '—'}', icon: Icons.flag_outlined),
          _Rule(
            text: 'Your reliability: ${me?.reliabilityLabel ?? '100%'}',
            icon: Icons.verified_outlined,
          ),
          const _Rule(
            text: 'One missed day ends it for both of you',
            icon: Icons.warning_amber_rounded,
          ),
          if (match.error != null) ...[
            Gap.h16,
            PactError(
              message: match.error!,
              onRetry: () => ref.read(matchmakingControllerProvider.notifier).find(),
            ),
          ],
          const Spacer(),
          if (searching)
            PactButton(
              label: 'Leave the queue',
              style: PactButtonStyle.ghost,
              onPressed: () => ref.read(matchmakingControllerProvider.notifier).cancel(),
            )
          else
            PactButton(
              label: 'Find my partner',
              onPressed: () => ref.read(matchmakingControllerProvider.notifier).find(),
            ),
          Gap.h16,
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: PactColors.textTertiary),
          Gap.w12,
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: PactColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two rings drifting toward each other — the whole product in one animation.
class _SearchPulse extends StatefulWidget {
  const _SearchPulse();

  @override
  State<_SearchPulse> createState() => _SearchPulseState();
}

class _SearchPulseState extends State<_SearchPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        final gap = 34.0 * (1 - t) + 6;
        return SizedBox(
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(-gap, 0),
                child: _ring(PactColors.violet, 0.35 + (t * 0.5)),
              ),
              Transform.translate(
                offset: Offset(gap, 0),
                child: _ring(PactColors.green, 0.35 + (t * 0.5)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(Color color, double opacity) => Container(
        height: 72,
        width: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: opacity), width: 5),
        ),
      );
}
