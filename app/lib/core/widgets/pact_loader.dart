import 'package:flutter/material.dart';

import '../theme/pact_colors.dart';

class PactLoader extends StatelessWidget {
  const PactLoader({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: PactColors.violet),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: const TextStyle(color: PactColors.textSecondary, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

/// One-line inline error with a retry affordance.
class PactError extends StatelessWidget {
  const PactError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: PactColors.redSoft,
        borderRadius: Radii.md,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: PactColors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: PactColors.red, fontSize: 13.5, height: 1.35),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(color: PactColors.red)),
            ),
        ],
      ),
    );
  }
}
