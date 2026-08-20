import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/pact_colors.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_scaffold.dart';
import 'splash_screen.dart';

/// One promise, three lines of mechanics, two buttons. Anything more and the
/// idea stops being obvious.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _rules = [
    ('Match with a stranger', 'No names to pick, no friends to invite.'),
    ('Check in daily with a photo', 'Live camera only. Proof, not promises.'),
    ('Miss a day and you both lose it', 'The streak belongs to the two of you.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return PactScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          const PactMark(size: 52),
          Gap.h32,
          Text('Your streak is\nno longer\nyours alone.', style: t.displayMedium),
          Gap.h16,
          Text(
            'Pactly pairs you with one stranger. You both show up, every day, or you both start over.',
            style: t.bodyMedium?.copyWith(fontSize: 15, height: 1.5),
          ),
          const Spacer(),
          for (final (title, sub) in _rules) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  height: 6,
                  width: 6,
                  decoration: const BoxDecoration(
                    color: PactColors.violet,
                    shape: BoxShape.circle,
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleMedium),
                      const SizedBox(height: 2),
                      Text(sub, style: t.bodyMedium?.copyWith(fontSize: 13.5)),
                    ],
                  ),
                ),
              ],
            ),
            Gap.h16,
          ],
          const Spacer(flex: 2),
          PactButton(
            label: 'Make a Pact',
            onPressed: () => context.push(Routes.signUp),
          ),
          Gap.h12,
          PactButton(
            label: 'I already have an account',
            style: PactButtonStyle.ghost,
            onPressed: () => context.push(Routes.signIn),
          ),
          Gap.h16,
        ],
      ),
    );
  }
}
