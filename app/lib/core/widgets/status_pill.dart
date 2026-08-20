import 'package:flutter/material.dart';

import '../../data/models/pact_day.dart';
import '../theme/pact_colors.dart';

/// Green / Red / Pending, the app's entire status vocabulary.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.label, this.compact = false});

  final DayStatus status;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 7),
      decoration: BoxDecoration(
        color: status.softColor,
        borderRadius: Radii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 7,
            width: 7,
            decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label ?? status.label,
            style: TextStyle(
              color: status.color,
              fontSize: compact ? 11.5 : 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 14-day dot strip. Reading your history should take one second.
class DayDots extends StatelessWidget {
  const DayDots({super.key, required this.statuses});

  /// Oldest first.
  final List<DayStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in statuses) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: s == DayStatus.pending
                    ? PactColors.surfaceHigh
                    : s.color.withValues(alpha: 0.85),
                borderRadius: Radii.pill,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}
