import 'package:flutter/material.dart';

import '../../../core/theme/pact_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pact_avatar.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../data/models/pact.dart';
import '../../../data/models/pact_day.dart';

/// The partner, reduced to what accountability actually needs: who they are,
/// whether they showed up, and how often they do. Nothing to tap that leads to
/// a conversation.
class PartnerCard extends StatelessWidget {
  const PartnerCard({
    super.key,
    required this.partner,
    required this.status,
    required this.proof,
    this.onTap,
  });

  final MemberInfo partner;
  final DayStatus status;
  final Proof? proof;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Material(
      color: PactColors.surfaceRaised,
      borderRadius: Radii.lg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.lg,
            border: Border.all(
              color: status == DayStatus.green
                  ? PactColors.green.withValues(alpha: 0.35)
                  : PactColors.strokeSoft,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              PactAvatar(
                username: partner.username,
                avatarUrl: partner.avatarUrl,
                size: 52,
                ring: status.color.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partner.username, style: t.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      '${partner.goalName} · ${partner.reliabilityLabel} reliable',
                      style: t.bodyMedium?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    StatusPill(
                      status: status,
                      compact: true,
                      label: switch (status) {
                        DayStatus.green => Fmt.submittedAt(proof?.submittedAt),
                        DayStatus.red => 'Missed',
                        DayStatus.pending => 'Has not checked in',
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PactColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
