import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/pact_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pact_avatar.dart';
import '../../core/widgets/pact_loader.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../core/widgets/stat_tile.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/models/pact_day.dart';
import '../../state/providers.dart';

/// Everything you are allowed to know about your partner. No message field, no
/// follow button, no reactions — by design, and the screen says so out loud.
class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final uid = ref.watch(currentUidProvider);
    final pact = ref.watch(currentPactProvider).value;
    final today = ref.watch(todayProvider).value ?? PactDay.empty;

    if (uid == null || pact == null) {
      return const PactScaffold(child: PactLoader());
    }

    final partner = pact.partnerOf(uid);
    final status = today.statusOf(partner.uid);
    final proof = today.proofOf(partner.uid);

    return PactScaffold(
      title: 'Your partner',
      leading: const BackButton(),
      child: ListView(
        padding: const EdgeInsets.only(top: 84, bottom: 40),
        children: [
          Center(
            child: Column(
              children: [
                PactAvatar(
                  username: partner.username,
                  avatarUrl: partner.avatarUrl,
                  size: 96,
                  ring: status.color.withValues(alpha: 0.55),
                ),
                Gap.h16,
                Text(partner.username, style: t.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Committed to ${partner.goalName}',
                  style: t.bodyMedium?.copyWith(fontSize: 14.5),
                ),
                Gap.h12,
                StatusPill(status: status),
              ],
            ),
          ),
          Gap.h32,
          PactCard(
            child: StatRow(
              tiles: [
                StatTile(
                  value: partner.reliabilityLabel,
                  label: 'Reliability',
                  color: partner.reliability >= 80 ? PactColors.green : PactColors.amber,
                ),
                StatTile(
                  value: pact.level.label.replaceAll(' Pact', ''),
                  label: 'Current level',
                  color: pact.level.color,
                ),
                StatTile(value: '${pact.daysTogether}', label: 'Days together'),
              ],
            ),
          ),
          Gap.h24,
          const SectionLabel("Today's proof"),
          Gap.h12,
          _Proof(status: status, proof: proof, username: partner.username),
          Gap.h24,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PactColors.surfaceRaised,
              borderRadius: Radii.md,
              border: Border.all(color: PactColors.strokeSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.do_not_disturb_on_outlined,
                  size: 17,
                  color: PactColors.textTertiary,
                ),
                Gap.w12,
                Expanded(
                  child: Text(
                    'You cannot message, follow or react. Pact is accountability, '
                    'not another feed. You stay together until the streak breaks.',
                    style: t.bodyMedium?.copyWith(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Proof extends StatelessWidget {
  const _Proof({required this.status, required this.proof, required this.username});

  final DayStatus status;
  final Proof? proof;
  final String username;

  @override
  Widget build(BuildContext context) {
    // A proof record can exist before its photo does — in a demo build there
    // is never a photo at all. Say the day was completed rather than claiming
    // we are still waiting on someone who already showed up.
    if (proof != null && proof!.photoUrl.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: PactColors.surfaceRaised,
          borderRadius: Radii.lg,
          border: Border.all(color: PactColors.green.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 26, color: PactColors.green),
              const SizedBox(height: 10),
              Text(
                Fmt.submittedAt(proof!.submittedAt),
                style: const TextStyle(color: PactColors.green, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    if (proof == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: PactColors.surfaceRaised,
          borderRadius: Radii.lg,
          border: Border.all(color: PactColors.strokeSoft),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status == DayStatus.red
                    ? Icons.no_photography_outlined
                    : Icons.hourglass_empty_rounded,
                size: 26,
                color: PactColors.textTertiary,
              ),
              const SizedBox(height: 10),
              Text(
                status == DayStatus.red
                    ? '$username did not check in.'
                    : 'Waiting on $username.',
                style: const TextStyle(color: PactColors.textSecondary, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: Radii.lg,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: CachedNetworkImage(
              imageUrl: proof!.photoUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(
                color: PactColors.surfaceRaised,
                child: PactLoader(),
              ),
              errorWidget: (_, __, ___) => const ColoredBox(
                color: PactColors.surfaceRaised,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: PactColors.textTertiary),
                ),
              ),
            ),
          ),
        ),
        Gap.h8,
        Text(
          Fmt.submittedAt(proof!.submittedAt),
          style: const TextStyle(color: PactColors.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}
