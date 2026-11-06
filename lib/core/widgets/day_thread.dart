import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/items/domain/entities/item.dart';
import '../helpers/due_label.dart';
import '../theme/note_color.dart';
import '../theme/weave_theme.dart';
import '../theme/weave_tokens.dart';

/// The day runs 07:00–23:00 on the thread and the strip.
const threadStart = 7 * 60;
const threadEnd = 23 * 60;

/// How a task is marked on the thread and the strip (03 `drawThread`):
/// upcoming = filled in its list colour, overdue = red ring, done = hollow.
enum ThreadMarkKind { upcoming, overdue, done }

/// A timed task due today, placed on the day.
class ThreadDot extends Equatable {
  const ThreadDot(this.item, this.minute, this.kind, this.color);

  final Item item;
  final int minute;
  final ThreadMarkKind kind;
  final NoteColor color;

  @override
  List<Object?> get props => [item, minute, kind, color];
}

/// The marks for [today]: timed tasks due on [now]'s day, by time. Untimed
/// tasks and tasks of other days have no place on the day.
List<ThreadDot> threadDots(
  List<Item> today,
  DateTime now,
  Map<String, NoteColor> colors,
) {
  final day = DateTime(now.year, now.month, now.day);
  final dots = <ThreadDot>[];
  for (final i in today) {
    final due = i.due;
    final m = due?.minutes;
    if (due == null || m == null || due.date != day) continue;
    final kind = i.done
        ? ThreadMarkKind.done
        : isOverdue(due, now)
        ? ThreadMarkKind.overdue
        : ThreadMarkKind.upcoming;
    dots.add(ThreadDot(i, m, kind, colors[i.listId] ?? NoteColor.yellow));
  }
  dots.sort((a, b) => a.minute - b.minute);
  return dots;
}

/// The screen-reader text after its lead-in (design playbook §6):
/// ": 09:00 Pay bill (overdue), 12:00 Buy milk (done). Now 16:20." — or
/// ". Now 16:20." when nothing is timed today.
String threadSaid(List<ThreadDot> dots, DateTime now) {
  final items = dots
      .map((d) {
        final s = switch (d.kind) {
          ThreadMarkKind.done => ' (done)',
          ThreadMarkKind.overdue => ' (overdue)',
          ThreadMarkKind.upcoming => '',
        };
        return '${fmtClock(d.minute)} ${d.item.text}$s';
      })
      .join(', ');
  final clock = fmtClock(now.hour * 60 + now.minute);
  return items.isEmpty ? '. Now $clock.' : ': $items. Now $clock.';
}

/// Today's thread (design playbook §9 Up next, 03 `drawThread`): 07:00 to
/// 23:00, the lived part in ink and the rest of today shaded; each timed
/// task a mark in its list's colour with its label above (overdue: red ring
/// and "!"; done: hollow, struck label). Marks closer than 14 px share one
/// label ("… +1"). Under 520 px labels shorten and hours thin out.
class DayThread extends StatelessWidget {
  const DayThread({
    super.key,
    required this.today,
    required this.now,
    this.colors = const {},
    this.onOpen,
  });

  /// Tasks due today, open and done (others are left out).
  final List<Item> today;
  final DateTime now;

  /// List id → colour, for the marks.
  final Map<String, NoteColor> colors;

  /// A label was tapped.
  final ValueChanged<Item>? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = Theme.of(context).brightness;
    final dots = threadDots(today, now, colors);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 600.0;
        final layout = ThreadLayout.of(dots, now, w, t);
        return Semantics(
          label: 'Today from 07:00 to 23:00${threadSaid(dots, now)}',
          image: true,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onOpen == null
                ? null
                : (d) {
                    final hit = layout.labelAt(d.localPosition);
                    if (hit != null) onOpen?.call(hit.item);
                  },
            child: CustomPaint(
              size: Size(w, layout.height),
              painter: _ThreadPainter(layout, dots, now, t, b),
            ),
          ),
        );
      },
    );
  }
}

/// A label on the thread and the marks it speaks for.
class ThreadLabel {
  ThreadLabel(this.first, this.cx);

  final ThreadDot first;
  final double cx;
  final more = <(ThreadDot, double)>[];
  String text = '';
  double width = 0;
  int row = 0;
  double start = 0;

  Item get item => first.item;
}

/// Where everything on the thread goes at one width (a port of 03
/// `drawThread`, so labels never overlap and no leader crosses a label).
class ThreadLayout {
  ThreadLayout._(
    this.width,
    this.labels,
    this.rows,
    this.compact,
    this.nowMinute,
    this.nowX,
  );

  factory ThreadLayout.of(
    List<ThreadDot> dots,
    DateTime now,
    double width,
    WeaveTokens t,
  ) {
    final w = width;
    final compact = w < 520;
    double x(int m) {
      final c = m.clamp(threadStart, threadEnd);
      return ((c - threadStart) / (threadEnd - threadStart) * (w - 12))
              .roundToDouble() +
          6;
    }

    String short(String s, int n) =>
        s.length > n ? '${s.substring(0, n - 1).trimRight()}…' : s;

    final labels = <ThreadLabel>[];
    for (final d in dots) {
      final cx = x(d.minute);
      final last = labels.lastOrNull;
      if (last != null && cx - last.cx < 14) {
        last.more.add((d, cx));
      } else {
        labels.add(ThreadLabel(d, cx));
      }
    }
    for (final l in labels) {
      final extra = l.more.isEmpty ? '' : ' +${l.more.length}';
      final title = l.first.item.text;
      l.text =
          (compact
              ? short(title, 16)
              : '${fmtClock(l.first.minute)} ${short(title, 28)}') +
          extra;
      final late = l.first.kind == ThreadMarkKind.overdue;
      l.width = _measure((late ? '! ' : '') + l.text, 14, t, FontWeight.w400);
    }
    // Label rows above the axis: the lowest free row whose span is clear
    // and whose lower rows don't cover this leader. Placed right to left;
    // at most 8 rows.
    final rows = <List<(double, double)>>[];
    for (final l in labels.reversed) {
      final s = math.max(0.0, math.min(w - l.width, l.cx - 4));
      final e = s + l.width;
      var r = 0;
      while (r < 8) {
        if (rows.length <= r) rows.add([]);
        final clear = rows[r].every((b) => e + 10 < b.$1 || s > b.$2 + 10);
        final leaderClear = rows
            .take(r)
            .every((rw) => rw.every((b) => l.cx < b.$1 - 4 || l.cx > b.$2 + 4));
        if (clear && leaderClear) break;
        r++;
      }
      if (rows.length <= r) rows.add([]);
      rows[r].add((s, e));
      l.row = r;
      l.start = s;
    }
    final nowMinute = now.hour * 60 + now.minute;
    return ThreadLayout._(
      w,
      labels,
      rows.length,
      compact,
      nowMinute,
      x(nowMinute),
    );
  }

  final double width;
  final List<ThreadLabel> labels;
  final int rows;
  final bool compact;
  final int nowMinute;
  final double nowX;

  double get rowHeight => compact ? 20 : 24;
  double get axisY => 8 + rows * rowHeight + 16;
  double get height => axisY + 34;

  /// The baseline of a label's row (row 0 sits nearest the axis).
  double baselineOf(ThreadLabel l) => 8 + (rows - 1 - l.row) * rowHeight + 14;

  ThreadLabel? labelAt(Offset p) {
    for (final l in labels) {
      final base = baselineOf(l);
      final r = Rect.fromLTRB(l.start, base - 16, l.start + l.width, base + 6);
      if (r.contains(p)) return l;
    }
    return null;
  }

  static double _measure(
    String s,
    double size,
    WeaveTokens t,
    FontWeight weight,
  ) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: t.font,
          fontFamilyFallback: t.fontFallback,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }
}

class _ThreadPainter extends CustomPainter {
  _ThreadPainter(this.l, this.dots, this.now, this.t, this.b);

  final ThreadLayout l;

  /// What [l] was made from: it is rebuilt with every build.
  final List<ThreadDot> dots;
  final DateTime now;
  final WeaveTokens t;
  final Brightness b;

  TextPainter _text(String s, double size, Color c, {bool medium = false}) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: t.font,
            fontFamilyFallback: t.fontFallback,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontSize: size,
            fontWeight: medium ? FontWeight.w500 : FontWeight.w400,
            color: c,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

  /// Paints [p] with its alphabetic baseline at [baseline].
  void _at(Canvas c, TextPainter p, double left, double baseline) {
    final ascent = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    p.paint(c, Offset(left, baseline - ascent));
    p.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final axisY = l.axisY;
    final nowX = l.nowX;
    // The rest of today, shaded.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(nowX, 0, math.max(0, w - nowX), axisY + 8),
        const Radius.circular(4),
      ),
      Paint()..color = t.hover,
    );
    Paint stroke(Color c, double width) => Paint()
      ..color = c
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(6, axisY), Offset(w - 6, axisY), stroke(t.control, 3))
      ..drawLine(Offset(6, axisY), Offset(nowX, axisY), stroke(t.text, 3));

    // Hours, except where the Now label sits.
    final nowLabel = _text(
      'Now ${fmtClock(l.nowMinute)}',
      13,
      t.text,
      medium: true,
    );
    final nowW = nowLabel.width + 8;
    final nowS = math.max(0.0, math.min(w - nowW, nowX - nowW / 2));
    final step = l.compact ? 240 : 120;
    for (var m = threadStart; m <= threadEnd; m += step) {
      final hx =
          ((m - threadStart) / (threadEnd - threadStart) * (w - 12))
              .roundToDouble() +
          6;
      final p = _text(fmtClock(m), 13, t.muted);
      final lw = p.width;
      final left = m == threadStart
          ? hx - 6
          : m == threadEnd
          ? hx + 6 - lw
          : hx - lw / 2;
      if (left + lw > nowS - 6 && left < nowS + nowW + 6) {
        p.dispose();
        continue;
      }
      canvas.drawLine(
        Offset(hx, axisY + 4),
        Offset(hx, axisY + 7),
        Paint()..color = t.control,
      );
      _at(canvas, p, left, axisY + 26);
    }
    canvas.drawLine(
      Offset(nowX, 0),
      Offset(nowX, axisY + 10),
      Paint()
        ..color = t.text
        ..strokeWidth = 1.5,
    );
    _at(canvas, nowLabel, nowS + (nowW - nowLabel.width) / 2, axisY + 26);

    for (final lb in l.labels) {
      final ly = l.baselineOf(lb);
      canvas.drawLine(
        Offset(lb.cx, ly + 5),
        Offset(lb.cx, axisY - 8),
        Paint()..color = t.control,
      );
      final kind = lb.first.kind;
      final late = kind == ThreadMarkKind.overdue;
      final p = TextPainter(
        text: TextSpan(
          text: (late ? '! ' : '') + lb.text,
          style: TextStyle(
            fontFamily: t.font,
            fontFamilyFallback: t.fontFallback,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontSize: 14,
            fontWeight: late ? FontWeight.w500 : FontWeight.w400,
            color: kind == ThreadMarkKind.done
                ? t.muted
                : late
                ? t.negative
                : t.text,
            decoration: kind == ThreadMarkKind.done
                ? TextDecoration.lineThrough
                : null,
            decorationColor: t.muted,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      _at(canvas, p, lb.start, ly);
      for (final (d, cx) in [...lb.more.reversed, (lb.first, lb.cx)]) {
        _mark(canvas, d, Offset(cx, axisY), large: true);
      }
    }
  }

  void _mark(Canvas canvas, ThreadDot d, Offset c, {required bool large}) {
    paintThreadMark(canvas, d, c, t, b, large: large);
  }

  @override
  bool shouldRepaint(_ThreadPainter old) =>
      old.l.width != l.width ||
      old.now != now ||
      !listEquals(old.dots, dots) ||
      old.t != t ||
      old.b != b;
}

/// One mark: done = hollow (`surface`, `muted` ring), overdue = red ring,
/// upcoming = filled in the list colour with its ink edge. [large] is the
/// thread's size (r 5 / 6 / 7.5); otherwise the strip's (4 / 4.5 / 5.5).
void paintThreadMark(
  Canvas canvas,
  ThreadDot d,
  Offset c,
  WeaveTokens t,
  Brightness b, {
  required bool large,
}) {
  final fill = Paint()..style = PaintingStyle.fill;
  final ring = Paint()..style = PaintingStyle.stroke;
  switch (d.kind) {
    case ThreadMarkKind.done:
      final r = large ? 5.0 : 4.0;
      canvas
        ..drawCircle(c, r, fill..color = t.surface)
        ..drawCircle(
          c,
          r,
          ring
            ..color = t.muted
            ..strokeWidth = 1.5,
        );
    case ThreadMarkKind.overdue:
      final r = large ? 6.0 : 4.5;
      canvas
        ..drawCircle(c, r, fill..color = t.surface)
        ..drawCircle(
          c,
          r,
          ring
            ..color = t.negative
            ..strokeWidth = large ? 2.5 : 2,
        );
    case ThreadMarkKind.upcoming:
      final r = large ? 7.5 : 5.5;
      canvas
        ..drawCircle(c, r, fill..color = d.color.fill(b))
        ..drawCircle(
          c,
          r,
          ring
            ..color = d.color.ink(b)
            ..strokeWidth = 1,
        );
  }
}
