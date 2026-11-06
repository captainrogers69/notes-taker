import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/items/domain/entities/item.dart';
import '../domain/note_color_id.dart';
import '../theme/weave_theme.dart';
import '../theme/weave_tokens.dart';
import 'day_thread.dart';

/// Today as one line (03 `dayStrip`, app.css `.lstrip.daystrip`): the
/// phone's form of the day thread (C9). "07" · the line from 07:00 to 23:00
/// with the lived part in ink and a Now tick, each timed task a mark · "23".
/// Nothing when no task today has a time.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.today,
    required this.now,
    this.colors = const {},
  });

  final List<Item> today;
  final DateTime now;
  final Map<String, NoteColor> colors;

  @override
  Widget build(BuildContext context) {
    final dots = threadDots(today, now, colors);
    if (dots.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final b = Theme.of(context).brightness;
    final hours = t.numeric.copyWith(fontSize: 12, color: t.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ExcludeSemantics(child: Text('07', style: hours)),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: 'Today${threadSaid(dots, now)}',
              image: true,
              child: CustomPaint(
                size: const Size.fromHeight(18),
                painter: _StripPainter(dots, now, t, b),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ExcludeSemantics(child: Text('23', style: hours)),
        ],
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.dots, this.now, this.t, this.b);

  final List<ThreadDot> dots;
  final DateTime now;
  final WeaveTokens t;
  final Brightness b;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    double x(int m) =>
        6 +
        ((m.clamp(threadStart, threadEnd) - threadStart) /
                (threadEnd - threadStart) *
                (w - 12))
            .roundToDouble();
    final nx = x(now.hour * 60 + now.minute);
    Paint line(Color c, double width) => Paint()
      ..color = c
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(6, 9), Offset(w - 6, 9), line(t.control, 2))
      ..drawLine(const Offset(6, 9), Offset(nx, 9), line(t.text, 2))
      ..drawLine(
        Offset(nx, 1),
        Offset(nx, 17),
        line(t.text, 1.5)..strokeCap = StrokeCap.butt,
      );
    for (final d in dots) {
      paintThreadMark(canvas, d, Offset(x(d.minute), 9), t, b, large: false);
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.now != now || !listEquals(old.dots, dots) || old.t != t || old.b != b;
}
