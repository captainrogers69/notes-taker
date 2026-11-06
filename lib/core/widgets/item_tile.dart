import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../features/items/domain/entities/item.dart';
import '../helpers/due_label.dart';
import '../theme/note_color.dart';
import '../theme/weave_theme.dart';
import 'pressable.dart';
import 'weave_icons.dart';

/// One task row (03 `agendaRow`, app.css `.row`): check · title · list name
/// (when given) · time, right-aligned. Overdue times are red with the alert
/// icon and the hidden word "Overdue" (never colour alone); done tasks are
/// struck through.
///
/// Ticking an open task plays the tick (fill and strike 120 ms, then the row
/// fades 120 ms) and then calls [onToggle]; unticking calls it at once.
/// Without motion it calls [onToggle] at once.
class ItemTile extends HookWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.listName,
    required this.now,
    this.onTap,
    this.onToggle,
    this.color = NoteColor.yellow,
    this.phone = false,
    this.rule = true,
  });

  final Item item;

  /// Shown after the title (03 shows it when the rows span several lists;
  /// never on phones). Null hides it.
  final String? listName;

  /// For the overdue check.
  final DateTime now;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  /// The task's list colour: the tick's fill and the name's dot.
  final NoteColor color;

  /// Phone layout: 44 px tick target, 48 px row, time sized to content.
  final bool phone;

  /// The 1 px rule above the row (off for the first row of a list).
  final bool rule;

  static const _tickFill = Duration(milliseconds: 120);

  /// The 18 px tick circle.
  static const circleKey = ValueKey('item-tile-circle');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = Theme.of(context).brightness;
    final text = Theme.of(context).textTheme;
    final still = MediaQuery.disableAnimationsOf(context);
    final ticking = useState(false);
    final leaving = useState(false);
    final hover = useState(false);
    final timers = useRef(<Timer>[]);
    // The last toggle came from the keyboard: draw its result at once.
    final byKeyboard = useRef(false);
    void clearTimers() {
      for (final x in timers.value) {
        x.cancel();
      }
      timers.value.clear();
    }

    useEffect(() => clearTimers, const []);
    // A new version of the task (done, undone by Undo, or a repeating
    // task's next due) ends any tick in progress, timers included.
    useEffect(() {
      clearTimers();
      ticking.value = false;
      leaving.value = false;
      return null;
    }, [item]);

    /// Pointer: fill and strike, fade, then write. [instant] (keyboard, or
    /// no motion): write at once.
    void toggle({bool instant = false}) {
      final cb = onToggle;
      if (cb == null) return;
      if (ticking.value) return;
      clearTimers();
      byKeyboard.value = instant;
      if (item.done || still || instant) {
        cb();
        return;
      }
      ticking.value = true;
      timers.value
        ..add(Timer(_tickFill, () => leaving.value = true))
        ..add(Timer(_tickFill * 2, cb))
        // Nothing came back (e.g. the write failed): show the row again.
        ..add(
          Timer(const Duration(seconds: 2), () {
            ticking.value = false;
            leaving.value = false;
          }),
        );
    }

    final filled = item.done || ticking.value;
    final due = item.due;
    final late = due != null && !item.done && isOverdue(due, now);
    final name = phone ? null : listName;

    final title = Text(
      item.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: text.bodyMedium?.copyWith(
        color: filled ? t.muted : t.text,
        decoration: filled ? TextDecoration.lineThrough : null,
        decorationStyle: TextDecorationStyle.solid,
        decorationColor: t.muted,
      ),
    );

    Widget? when;
    if (due != null) {
      final label = rowDueLabel(due, now);
      final style = t.numeric.copyWith(
        fontSize: t.fsSmall,
        color: late ? t.negative : t.muted,
        fontWeight: late ? FontWeight.w500 : FontWeight.w400,
      );
      final body = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (late) ...[
            WeaveIcon(WeaveIcons.alert, color: t.negative),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      );
      when = Semantics(
        label: late ? 'Overdue, $label' : label,
        excludeSemantics: true,
        // `.row .when`: 116 px right-aligned on desktop; sized to content
        // (at least 48) on phones (C10, D8).
        child: phone
            ? ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: body,
                ),
              )
            : SizedBox(
                width: 116,
                child: Align(alignment: Alignment.centerRight, child: body),
              ),
      );
    }

    final check = _Check(
      label: '${item.done ? 'Uncheck' : 'Check'} ${item.text}',
      filled: filled,
      color: color,
      brightness: b,
      phone: phone,
      still: still || byKeyboard.value,
      onTap: onToggle == null ? null : toggle,
      onActivate: onToggle == null ? null : () => toggle(instant: true),
    );
    final body = Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: onTap,
            hoverColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: phone ? 48 : t.rowHeight),
              child: Row(
                children: [
                  Expanded(child: title),
                  if (name != null) ...[
                    const SizedBox(width: 12),
                    _ListName(name: name, color: color, brightness: b),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (when != null) ...[const SizedBox(width: 12), when],
      ],
    );
    // 03 geometry: the circle 8 px in, the title at 38. Desktop: a 24 px
    // target from 5. Phone: a 44 px target from the row's edge, drawn over
    // the title's first pixels (`.lay-phone .check { margin: -13px }`).
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: phone ? 48 : t.rowHeight),
      child: phone
          ? Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 38, right: 8),
                  child: body,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 44,
                  child: Center(child: check),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.only(left: 5, right: 8),
              child: Row(
                children: [
                  check,
                  const SizedBox(width: 9),
                  Expanded(child: body),
                ],
              ),
            ),
    );

    return AnimatedOpacity(
      opacity: leaving.value ? 0 : 1,
      // The fade out is animated; a row that comes back is drawn at once.
      duration: still || !leaving.value ? Duration.zero : t.durFast,
      curve: t.easeOut,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: rule ? t.rule : Colors.transparent),
          MouseRegion(
            onEnter: (_) => hover.value = true,
            onExit: (_) => hover.value = false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: hover.value ? t.hover : null,
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: row,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.check`: an 18 px circle in a 24 px target (44 on phones, the circle
/// 8 px from its left edge). Open: 1.5 px
/// `control` ring on `surface` (list ink on hover). Done: list colour fill,
/// ink ring, the #111 tick.
class _Check extends HookWidget {
  const _Check({
    required this.label,
    required this.filled,
    required this.color,
    required this.brightness,
    required this.phone,
    required this.still,
    required this.onTap,
    required this.onActivate,
  });

  final String label;
  final bool filled;
  final NoteColor color;
  final Brightness brightness;
  final bool phone;
  final bool still;
  final VoidCallback? onTap;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hover = useState(false);
    final ink = color.ink(brightness);
    final target = phone ? 44.0 : 24.0;
    return MouseRegion(
      onEnter: (_) => hover.value = true,
      onExit: (_) => hover.value = false,
      child: Pressable(
        onTap: onTap,
        onActivate: onActivate,
        semanticLabel: label,
        hoverColor: Colors.transparent,
        radius: target / 2,
        child: SizedBox.square(
          dimension: target,
          child: Align(
            // Phone: the circle 8 px from the target's left edge.
            alignment: phone ? const Alignment(-5 / 13, 0) : Alignment.center,
            child: AnimatedContainer(
              key: ItemTile.circleKey,
              duration: still ? Duration.zero : t.durFast,
              curve: t.easeOut,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? color.fill(brightness) : t.surface,
                border: Border.all(
                  width: 1.5,
                  color: filled || hover.value ? ink : t.control,
                ),
              ),
              child: filled
                  ? Center(child: WeaveIcon(WeaveIcons.tick, color: t.tick))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.row .src`: an 8 px dot and the list name, 13 muted.
class _ListName extends StatelessWidget {
  const _ListName({
    required this.name,
    required this.color,
    required this.brightness,
  });

  final String name;
  final NoteColor color;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.fill(brightness),
            shape: BoxShape.circle,
            border: Border.all(color: color.ink(brightness)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.muted),
        ),
      ],
    );
  }
}
