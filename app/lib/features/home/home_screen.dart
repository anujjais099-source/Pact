import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/pact_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pact_avatar.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_loader.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../core/widgets/stat_tile.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/streak_ring.dart';
import '../../data/models/pact_day.dart';
import '../../state/providers.dart';
import 'widgets/partner_card.dart';

/// Everything a user needs to decide one thing: do I check in right now?
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value;
    final pact = ref.watch(currentPactProvider).value;
    final today = ref.watch(todayProvider).value ?? PactDay.empty;
    final recent = ref.watch(recentDaysProvider).value ?? const [];
    final left = ref.watch(deadlineProvider).value ?? Duration.zero;

    if (me == null || pact == null) {
      return const PactScaffold(child: PactLoader(message: 'Loading your Pact'));
    }

    final myStatus = today.statusOf(me.uid);
    final partner = pact.partnerOf(me.uid);
    final partnerStatus = today.statusOf(partner.uid);
    final urgent = left <= const Duration(hours: 1) && myStatus != DayStatus.green;

    return PactScaffold(
      padded: false,
      bottom: _CheckInBar(
        status: myStatus,
        urgent: urgent,
        onCheckIn: () => context.push(Routes.checkIn),
      ),
      child: RefreshIndicator(
        color: PactColors.violet,
        backgroundColor: PactColors.surfaceHigh,
        onRefresh: () async {
          ref.invalidate(currentPactProvider);
          ref.invalidate(todayProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            _TopBar(username: me.username, avatarUrl: me.avatarUrl),
            Gap.h24,
            Center(
              child: StreakRing(
                streak: pact.streak,
                level: pact.level,
                bothGreenToday: today.bothGreen,
              ),
            ),
            Gap.h24,
            _DeadlineBanner(left: left, urgent: urgent, done: myStatus == DayStatus.green),
            Gap.h24,
            const SectionLabel('Today'),
            Gap.h12,
            _TodayBoard(
              myStatus: myStatus,
              myProof: today.proofOf(me.uid),
              partnerStatus: partnerStatus,
              username: me.username,
              partnerName: partner.username,
            ),
            Gap.h24,
            const SectionLabel('Your partner'),
            Gap.h12,
            PartnerCard(
              partner: partner,
              status: partnerStatus,
              proof: today.proofOf(partner.uid),
              onTap: () => context.push(Routes.partner),
            ),
            Gap.h24,
            const SectionLabel('The Pact'),
            Gap.h12,
            PactCard(
              child: Column(
                children: [
                  StatRow(
                    tiles: [
                      StatTile(value: '${pact.daysTogether}', label: 'Days together'),
                      StatTile(
                        value: pact.level.label.replaceAll(' Pact', ''),
                        label: 'Pact level',
                        color: pact.level.color,
                      ),
                      StatTile(
                        value: Fmt.percent(me.reliability),
                        label: 'Your reliability',
                        color: me.reliability >= 80 ? PactColors.green : PactColors.amber,
                      ),
                    ],
                  ),
                  if (recent.isNotEmpty) ...[
                    Gap.h16,
                    const Divider(),
                    Gap.h16,
                    DayDots(
                      statuses: recent.reversed
                          .map((d) => d.statusOf(me.uid))
                          .toList(growable: false),
                    ),
                    Gap.h8,
                    Text(
                      'Last ${recent.length} days',
                      style: t.bodyMedium?.copyWith(
                        fontSize: 11.5,
                        color: PactColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.username, this.avatarUrl});

  final String username;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Your Pact'),
              const SizedBox(height: 2),
              Text(username, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push(Routes.profile),
          child: PactAvatar(username: username, avatarUrl: avatarUrl, size: 40),
        ),
      ],
    );
  }
}

/// The clock is the pressure. It only shouts in the last hour.
class _DeadlineBanner extends StatelessWidget {
  const _DeadlineBanner({required this.left, required this.urgent, required this.done});

  final Duration left;
  final bool urgent;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = done
        ? (
            PactColors.green,
            Icons.check_circle_outline_rounded,
            'Done for today. Resets in ${Fmt.countdown(left)}.',
          )
        : urgent
            ? (
                PactColors.red,
                Icons.timer_outlined,
                '${Fmt.countdown(left)} left. Your partner is exposed.',
              )
            : (
                PactColors.textSecondary,
                Icons.schedule_rounded,
                '${Fmt.countdown(left)} until the day closes.',
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: Radii.md,
        border: Border.all(color: color.withValues(alpha: urgent ? 0.4 : 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          Gap.w12,
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: urgent ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two columns, two people, one day. Deliberately symmetrical — the point is
/// that neither half counts on its own.
class _TodayBoard extends StatelessWidget {
  const _TodayBoard({
    required this.myStatus,
    required this.myProof,
    required this.partnerStatus,
    required this.username,
    required this.partnerName,
  });

  final DayStatus myStatus;
  final Proof? myProof;
  final DayStatus partnerStatus;
  final String username;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusTile(
            title: 'You',
            subtitle: myStatus == DayStatus.green
                ? Fmt.submittedAt(myProof?.submittedAt)
                : 'Not submitted',
            status: myStatus,
          ),
        ),
        Gap.w12,
        Expanded(
          child: _StatusTile(
            title: partnerName,
            subtitle: switch (partnerStatus) {
              DayStatus.green => 'Checked in',
              DayStatus.red => 'Missed the day',
              DayStatus.pending => 'Still pending',
            },
            status: partnerStatus,
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final DayStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PactColors.surfaceRaised,
        borderRadius: Radii.md,
        border: Border.all(color: status.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PactColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.label,
            style: TextStyle(color: status.color, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: PactColors.textTertiary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// The one button that matters, pinned where a thumb already is.
class _CheckInBar extends StatelessWidget {
  const _CheckInBar({
    required this.status,
    required this.urgent,
    required this.onCheckIn,
  });

  final DayStatus status;
  final bool urgent;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    if (status == DayStatus.green) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PactColors.greenSoft,
          borderRadius: Radii.md,
          border: Border.all(color: PactColors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: PactColors.green, size: 19),
            SizedBox(width: 9),
            Text(
              'Checked in today',
              style: TextStyle(
                color: PactColors.green,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return PactButton(
      label: urgent ? 'Check in now' : 'Check in',
      icon: Icons.camera_alt_rounded,
      style: urgent ? PactButtonStyle.danger : PactButtonStyle.primary,
      onPressed: onCheckIn,
    );
  }
}
