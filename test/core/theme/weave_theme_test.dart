import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/theme/note_color.dart';
import 'package:weave/core/theme/weave_theme.dart';
import 'package:weave/core/theme/weave_tokens.dart';
import 'package:weave/core/widgets/weave_mark.dart';

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

  test('tick mark is #111 in both modes (app.css .check svg)', () {
    expect(WeaveTokens.light.tick, const Color(0xFF111111));
    expect(WeaveTokens.dark.tick, const Color(0xFF111111));
    expect(WeaveTokens.light.sidebarWidthNarrow, 224);
  });

  testWidgets('Weave mark: ink corner in light, reversed in dark', (
    tester,
  ) async {
    for (final (b, corner) in [
      (Brightness.light, const Color(0xFF141414)),
      (Brightness.dark, const Color(0xFFF5F5F3)),
    ]) {
      await tester.pumpWidget(
        MaterialApp(theme: weaveTheme(b), home: const WeaveMark(size: 20)),
      );
      await tester.pumpAndSettle(); // theme change animates
      final p =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(WeaveMark),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as WeaveMarkPainter;
      expect(p.note, const Color(0xFFF5C84C));
      expect(p.corner, corner);
    }
  });

  testWidgets('Weave mark shape: corner is a quarter disc at the top right', (
    tester,
  ) async {
    // 1 px per kit unit: grid (x, y) is pixel (x - 24, y - 24).
    Future<Color> pixel(Brightness b, int x, int y) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: weaveTheme(b),
          home: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(key: key, child: const WeaveMark(size: 208)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData();
        final i = ((y - 24) * image.width + (x - 24)) * 4;
        final c = Color.fromARGB(
          bytes!.getUint8(i + 3),
          bytes.getUint8(i),
          bytes.getUint8(i + 1),
          bytes.getUint8(i + 2),
        );
        image.dispose();
        return c;
      }))!;
    }

    const note = Color(0xFFF5C84C);
    expect(await pixel(Brightness.light, 200, 60), const Color(0xFF141414));
    expect(await pixel(Brightness.light, 60, 200), note);
    // Inside the corner disc (centre 232,24, r 104) but outside a disc
    // centred on the note's centre.
    expect(await pixel(Brightness.light, 140, 30), const Color(0xFF141414));
    expect(await pixel(Brightness.light, 128, 128), note);
    expect(await pixel(Brightness.dark, 200, 60), const Color(0xFFF5F5F3));
    expect(await pixel(Brightness.dark, 60, 200), note);
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
