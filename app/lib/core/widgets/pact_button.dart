import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/pact_colors.dart';

enum PactButtonStyle { primary, secondary, ghost, danger }

/// One button for the whole app. Full width, 56pt, always reachable with a
/// thumb, and it never lets you double-submit.
class PactButton extends StatelessWidget {
  const PactButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = PactButtonStyle.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PactButtonStyle style;
  final bool loading;
  final IconData? icon;
  final bool expand;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      PactButtonStyle.primary => (PactColors.violet, Colors.white, null),
      PactButtonStyle.secondary => (
          PactColors.surfaceHigh,
          PactColors.textPrimary,
          PactColors.stroke,
        ),
      PactButtonStyle.ghost => (Colors.transparent, PactColors.textSecondary, null),
      PactButtonStyle.danger => (PactColors.redSoft, PactColors.red, null),
    };

    final child = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        borderRadius: Radii.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!.call();
                }
              : null,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: border == null
                ? null
                : BoxDecoration(
                    borderRadius: Radii.md,
                    border: Border.all(color: border),
                  ),
            padding: EdgeInsets.symmetric(horizontal: expand ? 20 : 28),
            child: loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 19, color: fg),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
