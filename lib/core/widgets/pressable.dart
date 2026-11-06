import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../theme/weave_theme.dart';

/// A borderless, achromatic button surface (no ink splash): [color] at
/// rest, `hover` on hover, and the playbook focus ring (2 px in `text`,
/// 2 px outside, `:focus-visible`) on keyboard focus. Enter / Space
/// activate it.
class Pressable extends HookWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onActivate,
    this.color,
    this.hoverColor,
    this.radius,
    this.semanticLabel,
    this.selected,
    this.tooltip,
    this.ringColor,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Keyboard activation (Enter / Space); defaults to [onTap]. Lets a
  /// control skip motion that only a pointer gets (keyboard-triggered UI is
  /// instant, design playbook §4 Motion).
  final VoidCallback? onActivate;

  /// Fill at rest (null: none).
  final Color? color;

  /// Fill on hover (null: the `hover` token).
  final Color? hoverColor;

  /// Corner radius (null: `radius-control`).
  final double? radius;
  final String? semanticLabel;
  final bool? selected;
  final String? tooltip;

  /// Focus ring colour (null: `text`). Pass `onPrimary` on a primary fill,
  /// where a `text` ring would not show.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hover = useState(false);
    final focus = useState(false);
    final r = BorderRadius.circular(radius ?? t.radiusControl);
    final enabled = onTap != null;
    final fill = enabled && hover.value ? (hoverColor ?? t.hover) : color;
    Widget body = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (v) => hover.value = v,
      onShowFocusHighlight: (v) => focus.value = v,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            (onActivate ?? onTap)?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: focus.value
              ? _FocusRing(ringColor ?? t.text, r)
              : null,
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, borderRadius: r),
            child: child,
          ),
        ),
      ),
    );
    body = Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticLabel,
      child: body,
    );
    final tip = tooltip;
    return tip == null ? body : Tooltip(message: tip, child: body);
  }
}

class _FocusRing extends CustomPainter {
  const _FocusRing(this.color, this.radius);

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    // outline: 2px; outline-offset: 2px → centre of the stroke 3 px out.
    canvas.drawRRect(
      radius.toRRect(Offset.zero & size).inflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRing old) =>
      old.color != color || old.radius != radius;
}
