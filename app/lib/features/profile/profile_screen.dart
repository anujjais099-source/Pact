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
import '../../data/repositories/user_repository.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../onboarding/goal_setup_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value;
    final pact = ref.watch(currentPactProvider).value;

    if (me == null) return const PactScaffold(child: PactLoader());

    return PactScaffold(
      title: 'Profile',
      leading: const BackButton(),
      child: ListView(
        padding: const EdgeInsets.only(top: 84, bottom: 40),
        children: [
          Center(
            child: Column(
              children: [
                PactAvatar(username: me.username, avatarUrl: me.avatarUrl, size: 92),
                Gap.h16,
                Text(me.username, style: t.headlineMedium),
                const SizedBox(height: 4),
                Text(me.email, style: t.bodyMedium?.copyWith(fontSize: 13)),
              ],
            ),
          ),
          Gap.h32,
          PactCard(
            child: StatRow(
              tiles: [
                StatTile(value: '${me.totalPacts}', label: 'Total pacts'),
                StatTile(
                  value: '${me.longestStreak}',
                  label: 'Longest streak',
                  color: PactColors.violet,
                ),
                StatTile(
                  value: Fmt.percent(me.reliability),
                  label: 'Reliability',
                  color: me.reliability >= 80 ? PactColors.green : PactColors.amber,
                ),
              ],
            ),
          ),
          Gap.h12,
          PactCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Current goal'),
                      const SizedBox(height: 6),
                      Text(me.goalName, style: t.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        '${me.totalCheckins} check-ins · ${me.missedDays} missed',
                        style: t.bodyMedium?.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GoalSetupScreen(isEditing: true),
                    ),
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          Gap.h12,
          _NotificationToggle(enabled: me.notificationsEnabled, uid: me.uid),
          if (pact != null) ...[
            Gap.h24,
            const SectionLabel('Active pact'),
            Gap.h12,
            PactCard(
              onTap: () => context.go(Routes.partner),
              child: Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: pact.level.color.withValues(alpha: 0.12),
                      borderRadius: Radii.sm,
                    ),
                    child: Icon(Icons.link_rounded, size: 19, color: pact.level.color),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'With ${pact.partnerOf(me.uid).username}',
                          style: t.titleMedium,
                        ),
                        Text(
                          '${pact.streak} day streak · ${pact.level.label}',
                          style: t.bodyMedium?.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: PactColors.textTertiary),
                ],
              ),
            ),
          ],
          Gap.h32,
          PactButton(
            label: 'Sign out',
            style: PactButtonStyle.secondary,
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          Gap.h16,
          Center(
            child: Text(
              'Pact · v1.0.0',
              style: t.bodyMedium?.copyWith(fontSize: 11.5, color: PactColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationToggle extends ConsumerWidget {
  const _NotificationToggle({required this.enabled, required this.uid});

  final bool enabled;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PactCard(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Morning, evening, and the last hour.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: PactColors.violet,
            onChanged: (v) => ref.read(userRepositoryProvider).setNotifications(uid, v),
          ),
        ],
      ),
    );
  }
}
