import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/pact_colors.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_loader.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../data/models/pact.dart';
import '../../data/repositories/pact_repository.dart';
import '../../data/services/firebase_service.dart';
import '../../state/pact_memory.dart';
import '../../state/providers.dart';

/// The most emotionally loaded screen in the app. It states the fact, names
/// what was lost, assigns responsibility honestly, and offers exactly one way
/// forward. No guilt-tripping past that — shame does not build habits.
class PactBrokenScreen extends ConsumerWidget {
  const PactBrokenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final brokenPactId = ref.watch(pactMemoryProvider);

    if (uid == null || brokenPactId == null) {
      return const PactScaffold(child: PactLoader());
    }

    final snapshot = ref.watch(_brokenPactProvider(brokenPactId));

    return PactScaffold(
      child: snapshot.when(
        loading: () => const PactLoader(),
        error: (_, __) => _Body(
          streakLost: 0,
          byMe: false,
          partnerName: 'your partner',
          onContinue: () => ref.read(pactMemoryProvider.notifier).acknowledge(),
        ),
        data: (pact) => _Body(
          streakLost: pact?.longestStreak ?? 0,
          byMe: pact?.brokenByMe(uid) ?? false,
          partnerName: pact?.partnerOf(uid).username ?? 'your partner',
          onContinue: () async {
            await ref.read(pactAnalyticsProvider).broken(
                  pact?.longestStreak ?? 0,
                  pact?.brokenByMe(uid) ?? false,
                );
            await ref.read(pactMemoryProvider.notifier).acknowledge();
          },
        ),
      ),
    );
  }
}

final _brokenPactProvider = StreamProvider.family<Pact?, String>(
  (ref, pactId) => ref.watch(pactRepositoryProvider).watch(pactId),
);

class _Body extends StatelessWidget {
  const _Body({
    required this.streakLost,
    required this.byMe,
    required this.partnerName,
    required this.onContinue,
  });

  final int streakLost;
  final bool byMe;
  final String partnerName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(flex: 2),
        Container(
          height: 78,
          width: 78,
          decoration: BoxDecoration(
            color: PactColors.redSoft,
            shape: BoxShape.circle,
            border: Border.all(color: PactColors.red.withValues(alpha: 0.4), width: 2),
          ),
          child: const Icon(Icons.link_off_rounded, color: PactColors.red, size: 34),
        ),
        Gap.h32,
        Text('Your Pact has\nbeen broken.', style: t.displayMedium),
        Gap.h16,
        if (streakLost > 0)
          RichText(
            text: TextSpan(
              style: t.bodyMedium?.copyWith(fontSize: 15.5),
              children: [
                const TextSpan(text: 'You and '),
                TextSpan(
                  text: partnerName,
                  style: const TextStyle(color: PactColors.textPrimary),
                ),
                const TextSpan(text: ' lost a '),
                TextSpan(
                  text: '$streakLost-day',
                  style: const TextStyle(
                    color: PactColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' streak.'),
              ],
            ),
          )
        else
          Text(
            'The Pact ended before it got going.',
            style: t.bodyMedium?.copyWith(fontSize: 15.5),
          ),
        Gap.h16,
        Text(
          byMe
              ? 'You missed the deadline. That is the deal — it costs both of you, and there is no way to buy it back.'
              : '$partnerName missed the deadline. Nothing you could have done differently; the streak was shared, so the loss is too.',
          style: t.bodyMedium?.copyWith(fontSize: 14.5, height: 1.55),
        ),
        Gap.h24,
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PactColors.surfaceRaised,
            borderRadius: Radii.md,
            border: Border.all(color: PactColors.strokeSoft),
          ),
          child: Row(
            children: [
              const Icon(Icons.refresh_rounded, size: 17, color: PactColors.violet),
              Gap.w12,
              Expanded(
                child: Text(
                  'Your reliability score keeps its history. A new partner starts you at day zero.',
                  style: t.bodyMedium?.copyWith(fontSize: 13, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
        PactButton(label: 'Find a new partner', onPressed: onContinue),
        Gap.h16,
      ],
    );
  }
}
