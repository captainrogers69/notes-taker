import 'package:flutter/material.dart';

import '../theme/note_color.dart';
import '../theme/weave_tokens.dart';

/// The Weave mark (logo 8a "Lifted corner", locked 2026-11-05,
/// `docs/logo/kit`): a square note in `--n0` whose top-right corner is
/// lifted in ink. Drawn from the kit's 256 grid, cropped to the note
/// (viewBox 24 24 208 208, as `icons.js` `mark`), so [size] is the note.
///
/// Light: the colour mark (`weave-mark.svg`, corner `#141414`). Dark: the
/// reversed mark (`weave-mark-reversed.svg`, corner `#F5F5F3`); the kit
/// lists "ink corner on dark" as a don't.
class WeaveMark extends StatelessWidget {
  const WeaveMark({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: Size.square(size),
      painter: WeaveMarkPainter(
        note: NoteColor.yellow.fill(Brightness.light),
        // #141414 / #F5F5F3 are the light primary and light ground.
        corner: dark ? WeaveTokens.light.ground : WeaveTokens.light.primary,
      ),
    );
  }
}

class WeaveMarkPainter extends CustomPainter {
  const WeaveMarkPainter({required this.note, required this.corner});

  final Color note;
  final Color corner;

  @override
  void paint(Canvas canvas, Size size) {
    // Kit geometry, 256 grid; the note spans 24..232.
    final k = size.width / 208;
    canvas
      ..save()
      ..scale(k)
      ..translate(-24, -24)
      // <rect x="24" y="24" width="208" height="208" rx="36"/>
      ..drawRRect(
        RRect.fromLTRBR(24, 24, 232, 232, const Radius.circular(36)),
        Paint()..color = note,
      )
      // <path d="M128 24H196A36 36 0 0 1 232 60V128A104 104 0 0 1 128 24Z"/>
      // Both arcs have sweep-flag 1 (clockwise on screen). The second is
      // centred on the note's top-right corner (232, 24), so the lifted
      // corner is a quarter disc of radius 104 clipped by the rounded edge.
      ..drawPath(
        Path()
          ..moveTo(128, 24)
          ..lineTo(196, 24)
          ..arcToPoint(const Offset(232, 60), radius: const Radius.circular(36))
          ..lineTo(232, 128)
          ..arcToPoint(
            const Offset(128, 24),
            radius: const Radius.circular(104),
          )
          ..close(),
        Paint()..color = corner,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(WeaveMarkPainter old) =>
      old.note != note || old.corner != corner;
}
