import 'package:flutter/material.dart';

import '../theme/pact_colors.dart';

/// A number and what it means. Used on Home, Match and Profile.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.icon,
  });

  final String value;
  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color ?? PactColors.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              value,
              style: TextStyle(
                color: color ?? PactColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: PactColors.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}

/// Three stats in a row with hairline dividers — the standard block.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          Expanded(child: tiles[i]),
          if (i != tiles.length - 1)
            Container(width: 1, height: 34, color: PactColors.strokeSoft),
          if (i != tiles.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }
}
