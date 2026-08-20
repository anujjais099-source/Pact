import 'package:flutter/material.dart';

import '../../core/theme/pact_colors.dart';

/// Mirrors functions/src/levels.ts. Keep the two in step.
enum PactLevel {
  one(1, 'Level 1 Pact', 1, 7, PactColors.level1),
  two(2, 'Level 2 Pact', 8, 14, PactColors.level2),
  three(3, 'Level 3 Pact', 15, 30, PactColors.level3),
  legendary(4, 'Legendary Pact', 31, null, PactColors.legendary);

  const PactLevel(this.level, this.label, this.from, this.to, this.color);

  final int level;
  final String label;
  final int from;
  final int? to;
  final Color color;

  static PactLevel forStreak(int streak) {
    if (streak >= 31) return PactLevel.legendary;
    if (streak >= 15) return PactLevel.three;
    if (streak >= 8) return PactLevel.two;
    return PactLevel.one;
  }

  /// Days remaining until the next band. Null once Legendary.
  int? daysToNext(int streak) => to == null ? null : (to! + 1) - streak;

  /// 0..1 progress through the current band, for the streak ring.
  double progress(int streak) {
    if (to == null) return 1;
    final span = to! - from + 1;
    final done = (streak - from + 1).clamp(0, span);
    return span == 0 ? 1 : done / span;
  }

  PactLevel? get next => switch (this) {
        PactLevel.one => PactLevel.two,
        PactLevel.two => PactLevel.three,
        PactLevel.three => PactLevel.legendary,
        PactLevel.legendary => null,
      };
}
