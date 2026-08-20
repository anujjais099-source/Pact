import 'package:flutter/material.dart';

import '../theme/pact_colors.dart';

/// Every screen sits on the same near-black ground with one faint violet bloom
/// behind the content. It is the only decoration in the app.
class PactScaffold extends StatelessWidget {
  const PactScaffold({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.padded = true,
    this.glow = true,
    this.bottom,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool padded;
  final bool glow;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    // Copied to a local: Dart promotes locals, not final fields, so `bottom`
    // would still read as Widget? inside the null check below.
    final bottomBar = bottom;

    return Scaffold(
      backgroundColor: PactColors.black,
      extendBodyBehindAppBar: true,
      appBar: (title == null && leading == null && actions == null)
          ? null
          : AppBar(title: title == null ? null : Text(title!), leading: leading, actions: actions),
      body: Stack(
        children: [
          if (glow)
            Positioned(
              top: -160,
              left: -80,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  height: 380,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x267C5CFF), Color(0x00000000)],
                      radius: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padded ? 20 : 0),
              child: child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: bottomBar,
            ),
    );
  }
}

/// Small all-caps label used above every block of content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      );
}

/// The standard raised container.
class PactCard extends StatelessWidget {
  const PactCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PactColors.surfaceRaised,
      borderRadius: Radii.lg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.lg,
            border: Border.all(color: borderColor ?? PactColors.strokeSoft),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
