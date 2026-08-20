import 'package:flutter/material.dart';

/// Pact's palette. Dark-first, one accent, three status colours.
/// Nothing else gets to be colourful — the streak number is the hero.
abstract final class PactColors {
  // surfaces
  static const Color black = Color(0xFF07070A);
  static const Color surface = Color(0xFF0E0E14);
  static const Color surfaceRaised = Color(0xFF16161F);
  static const Color surfaceHigh = Color(0xFF1E1E2A);
  static const Color stroke = Color(0xFF262633);
  static const Color strokeSoft = Color(0xFF1B1B25);

  // text
  static const Color textPrimary = Color(0xFFF4F4F7);
  static const Color textSecondary = Color(0xFF9A9AAE);
  static const Color textTertiary = Color(0xFF5E5E74);

  // accent
  static const Color violet = Color(0xFF7C5CFF);
  static const Color violetSoft = Color(0x1A7C5CFF);
  static const Color violetDeep = Color(0xFF5B3FE0);

  // status
  static const Color green = Color(0xFF3DDC97);
  static const Color greenSoft = Color(0x1A3DDC97);
  static const Color red = Color(0xFFFF5A6E);
  static const Color redSoft = Color(0x1AFF5A6E);
  static const Color amber = Color(0xFFFFB84D);
  static const Color amberSoft = Color(0x1AFFB84D);

  // levels
  static const Color level1 = Color(0xFF7C5CFF);
  static const Color level2 = Color(0xFF4DA3FF);
  static const Color level3 = Color(0xFF3DDC97);
  static const Color legendary = Color(0xFFFFC24D);

  static const LinearGradient violetGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C5CFF), Color(0xFF4DA3FF)],
  );

  static const LinearGradient legendaryGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC24D), Color(0xFFFF8A4D)],
  );
}

/// 4-pt spacing scale. Use these, never raw numbers.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  static const SizedBox h4 = SizedBox(height: xs);
  static const SizedBox h8 = SizedBox(height: sm);
  static const SizedBox h12 = SizedBox(height: md);
  static const SizedBox h16 = SizedBox(height: lg);
  static const SizedBox h24 = SizedBox(height: xl);
  static const SizedBox h32 = SizedBox(height: xxl);
  static const SizedBox h48 = SizedBox(height: huge);
  static const SizedBox w8 = SizedBox(width: sm);
  static const SizedBox w12 = SizedBox(width: md);
  static const SizedBox w16 = SizedBox(width: lg);
}

abstract final class Radii {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(10));
  static const BorderRadius md = BorderRadius.all(Radius.circular(16));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(22));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}
