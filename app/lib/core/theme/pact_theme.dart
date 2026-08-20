import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pact_colors.dart';

/// One theme. Dark only — Pact is a night-and-morning app and a light mode
/// would double the surface area for zero retention gain in the MVP.
abstract final class PactTheme {
  static const String _family = 'Inter';

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: PactColors.violet,
      onPrimary: Colors.white,
      secondary: PactColors.green,
      onSecondary: PactColors.black,
      surface: PactColors.surface,
      onSurface: PactColors.textPrimary,
      error: PactColors.red,
      onError: Colors.white,
      outline: PactColors.stroke,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: PactColors.black,
      splashFactory: InkSparkle.splashFactory,
      // Falls back to the platform font until Inter is dropped into assets/.
      fontFamily: _family,
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
    );

    return base.copyWith(
      textTheme: _text(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: PactColors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: _family,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: PactColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: PactColors.strokeSoft,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: PactColors.surfaceHigh,
        contentTextStyle: TextStyle(color: PactColors.textPrimary, fontFamily: _family),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.md),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PactColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: _input(),
    );
  }

  static InputDecorationTheme _input() {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: Radii.md,
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: PactColors.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: const TextStyle(color: PactColors.textTertiary, fontSize: 15),
      labelStyle: const TextStyle(color: PactColors.textSecondary, fontSize: 14),
      errorStyle: const TextStyle(color: PactColors.red, fontSize: 12.5),
      enabledBorder: border(PactColors.stroke),
      focusedBorder: border(PactColors.violet, 1.4),
      errorBorder: border(PactColors.red),
      focusedErrorBorder: border(PactColors.red, 1.4),
    );
  }

  static TextTheme _text(TextTheme t) => t.copyWith(
        displayLarge: const TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w700,
          letterSpacing: -3,
          height: 1,
          color: PactColors.textPrimary,
        ),
        displayMedium: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
          height: 1.05,
          color: PactColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.15,
          color: PactColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          color: PactColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: PactColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15.5,
          height: 1.45,
          color: PactColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: PactColors.textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: PactColors.textPrimary,
        ),
        labelSmall: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: PactColors.textTertiary,
        ),
      );
}
