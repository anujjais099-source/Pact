import 'package:flutter/material.dart';

import '../../core/theme/pact_colors.dart';

/// Shown only while the session resolves. It must never be the reason a user
/// waits, so it carries the promise instead of a spinner alone.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PactColors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PactMark(size: 64),
            const SizedBox(height: 20),
            Text('PACTLY', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 6)),
            const SizedBox(height: 8),
            const Text(
              'Your streak is no longer yours alone.',
              style: TextStyle(color: PactColors.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 34),
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: PactColors.violet),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two interlocking rings — one streak, two people. Drawn, not shipped as an
/// asset, so it stays crisp at every density.
class PactMark extends StatelessWidget {
  const PactMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size * 1.55,
      child: Stack(
        children: [
          Positioned(left: 0, child: _ring(PactColors.violet)),
          Positioned(right: 0, child: _ring(PactColors.green)),
        ],
      ),
    );
  }

  Widget _ring(Color c) => Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c, width: size * 0.09),
        ),
      );
}
