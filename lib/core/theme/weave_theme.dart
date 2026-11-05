import 'package:flutter/material.dart';

import 'weave_tokens.dart';

/// Geist 400/500 only (design playbook §4 Typography).
ThemeData weaveTheme(Brightness b) {
  final t = b == Brightness.light ? WeaveTokens.light : WeaveTokens.dark;

  TextStyle style(double size, FontWeight weight, {double? letterSpacing}) =>
      TextStyle(
        fontFamily: t.font,
        fontFamilyFallback: t.fontFallback,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: t.text,
      );

  final textTheme = TextTheme(
    // Screen title 24/500, -0.01em
    headlineSmall: style(t.fsTitle, FontWeight.w500, letterSpacing: -0.24),
    // Card title, sheet list name 16/500
    titleMedium: style(t.fsSection, FontWeight.w500),
    // Body, tasks, fields 14/400
    bodyMedium: style(t.fsBody, FontWeight.w400),
    bodyLarge: style(t.fsBody, FontWeight.w400),
    // Meta, times, sublines 13/400
    bodySmall: style(t.fsSmall, FontWeight.w400),
    // Buttons 13/500
    labelLarge: style(t.fsSmall, FontWeight.w500),
    // Kbd hints, day-strip hours, fine print 12/400
    labelSmall: style(12, FontWeight.w400),
    // Phone tab labels 11 (iOS) / 12 (Android), 500
    labelMedium: style(12, FontWeight.w500),
  );

  return ThemeData(
    brightness: b,
    useMaterial3: true,
    fontFamily: t.font,
    fontFamilyFallback: t.fontFallback,
    scaffoldBackgroundColor: t.ground,
    canvasColor: t.surface,
    dividerColor: t.border,
    colorScheme: ColorScheme(
      brightness: b,
      primary: t.primary,
      onPrimary: t.onPrimary,
      secondary: t.raised,
      onSecondary: t.text,
      error: t.negative,
      onError: t.onPrimary,
      surface: t.surface,
      onSurface: t.text,
    ),
    textTheme: textTheme,
    extensions: [t],
  );
}

extension WeaveTokensX on BuildContext {
  WeaveTokens get tokens =>
      Theme.of(this).extension<WeaveTokens>() ?? WeaveTokens.light;
}
