import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/theme/note_color.dart';
import 'package:weave/core/theme/weave_theme.dart';
import 'package:weave/core/theme/weave_tokens.dart';

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('light and dark tokens mirror tokens.css', () {
    expect(WeaveTokens.light.surface, const Color(0xFFFFFFFF));
    expect(WeaveTokens.light.ground, const Color(0xFFF5F5F3));
    expect(WeaveTokens.dark.text, const Color(0xFFF2F2F2));
    expect(WeaveTokens.dark.surface, const Color(0xFF171717));
    expect(WeaveTokens.light.paperMix, 0.22);
    expect(WeaveTokens.dark.paperMix, 0.16);
    expect(WeaveTokens.light.rowHeight, 44);
    expect(WeaveTokens.light.sidebarWidth, 256);
  });

  test('motion durations', () {
    expect(WeaveTokens.light.durFast, const Duration(milliseconds: 120));
    expect(WeaveTokens.light.dur, const Duration(milliseconds: 180));
  });

  test('theme uses Geist and exposes tokens', () {
    final t = weaveTheme(Brightness.light);
    expect(t.textTheme.bodyMedium!.fontFamily, 'Geist');
    expect(t.extension<WeaveTokens>(), WeaveTokens.light);
    expect(
      weaveTheme(Brightness.dark).extension<WeaveTokens>(),
      WeaveTokens.dark,
    );
    expect(t.textTheme.headlineSmall!.fontSize, 24);
    expect(t.textTheme.bodyMedium!.fontSize, 14);
    expect(
      WeaveTokens.light.numeric.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('NoteColor api mapping', () {
    expect(NoteColor.fromApi('nope'), NoteColor.values.first);
    expect(NoteColor.fromApi(null), NoteColor.values.first);
    for (final c in NoteColor.values) {
      expect(NoteColor.fromApi(c.apiValue), c);
    }
    expect(NoteColor.yellow.fill(Brightness.light), const Color(0xFFF5C84C));
    expect(NoteColor.yellow.ink(Brightness.dark), const Color(0xFFF5C84C));
  });

  test('light ink has >= 4.5 contrast on light surface', () {
    for (final c in NoteColor.values) {
      expect(
        contrast(c.ink(Brightness.light), WeaveTokens.light.surface),
        greaterThanOrEqualTo(4.5),
        reason: c.name,
      );
    }
  });
}
