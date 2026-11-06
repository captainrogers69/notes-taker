import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../features/lists/domain/entities/task_list.dart';
import '../helpers/quick_parse.dart';
import '../theme/weave_theme.dart';
import 'pressable.dart';
import 'weave_icons.dart';

/// The one add field (design playbook C3, §2 Quick capture; 03 `capture()`):
/// a + icon, the text, and the list as a small chip inside the field. Enter
/// adds and, once that worked, clears, ready for the next one; there is no
/// Add button.
///
/// Under it, while the field has focus, the parse line (`aria-live`): the
/// read-back once the text holds a date or time ("Due Tomorrow 18:00 · adds
/// as “call mom”"), otherwise the hint. Its height is kept so nothing nudges;
/// the phone add bar has no hint and drops the line when it is empty (03
/// `.paddbar .parse:empty`).
class QuickCaptureField extends HookWidget {
  const QuickCaptureField({
    super.key,
    required this.listId,
    required this.onListChange,
    required this.onSubmit,
    this.lists = const [],
    this.phoneBar = false,
    this.inline = false,
    this.ruleColor,
    this.semanticLabel = 'Add a task',
    this.now,
    this.focusNode,
    this.placeholder = 'Add a task… try “dentist fri 10am”',
  });

  /// The list Enter adds to (the chip shows it).
  final String? listId;
  final ValueChanged<String> onListChange;

  /// Called with the trimmed line; never with an empty one. Returns whether
  /// it was added: the text stays unless it was (also if this throws).
  final Future<bool> Function(String raw) onSubmit;

  /// The chip's choices. Empty: no chip (a list screen's own field).
  final List<TaskList> lists;

  /// The phone add bar: 44 high, 16 px text, chip at most 112 wide.
  final bool phoneBar;

  /// The list note's add row (03 `.capture.inline`): 44 high, no box, a
  /// [ruleColor] line above, no parse line.
  final bool inline;
  final Color? ruleColor;

  /// What a screen reader calls the field.
  final String semanticLabel;

  /// The clock for the read-back (default: now).
  final DateTime Function()? now;
  final FocusNode? focusNode;
  final String placeholder;

  static const boxKey = ValueKey('quick-capture-box');

  /// 03 `HINT`.
  static const hint =
      'Times and days are understood: 6pm, 18:30, tomorrow, tonight, in 2 h.';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final controller = useTextEditingController();
    final ownFocus = useFocusNode(debugLabel: 'quick capture');
    final focus = focusNode ?? ownFocus;
    useListenable(controller);
    useListenable(focus);

    final raw = controller.text.trim();
    final clock = (now ?? DateTime.now)();
    final parsed = raw.isEmpty || !focus.hasFocus
        ? null
        : quickParse(raw, clock);
    final readBack = parsed?.due == null
        ? null
        : '${parseReadBack(parsed!, clock)} · adds as “${parsed.text}”';

    final submitting = useRef(false);
    Future<void> submit(String value) async {
      final line = value.trim();
      focus.requestFocus();
      // Enter that confirms an input method's text is not an add.
      if (controller.value.composing.isValid) return;
      if (line.isEmpty || submitting.value) return;
      submitting.value = true;
      var added = false;
      try {
        added = await onSubmit(line);
      } on Object catch (e) {
        developer.log('add failed: ${e.runtimeType}', name: 'Capture');
      }
      submitting.value = false;
      if (!context.mounted || !added) return;
      // Whatever was typed meanwhile is the next task: leave it.
      if (controller.text.trim() == line) controller.clear();
    }

    final small = theme.bodySmall?.copyWith(color: t.muted);
    final Widget parseLine;
    if (readBack != null) {
      parseLine = Row(
        children: [
          WeaveIcon(WeaveIcons.clock, color: t.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              readBack,
              style: small,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (focus.hasFocus && !phoneBar) {
      parseLine = Text(
        hint,
        style: small,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      parseLine = const SizedBox.shrink();
    }

    final selected = lists.where((l) => l.id == listId).firstOrNull;
    // Phones: 16 px in fields (app.css `.lay-phone input`).
    final fieldStyle = phoneBar
        ? theme.bodyMedium?.copyWith(fontSize: 16)
        : theme.bodyMedium;

    final box = Container(
      key: boxKey,
      height: phoneBar || inline ? 44 : 40,
      padding: inline
          ? const EdgeInsets.only(left: 4)
          : const EdgeInsets.symmetric(horizontal: 12),
      decoration: inline
          ? null
          : BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
      // The border is drawn on top, so the chip's tap area keeps the
      // field's full height (44 in the phone add bar).
      foregroundDecoration: inline
          ? BoxDecoration(
              border: Border(top: BorderSide(color: ruleColor ?? t.rule)),
            )
          : BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusControl),
              border: Border.all(color: focus.hasFocus ? t.text : t.control),
            ),
      child: Row(
        children: [
          WeaveIcon(WeaveIcons.plus, color: t.text),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: semanticLabel,
              child: TextField(
                controller: controller,
                focusNode: focus,
                style: fieldStyle,
                cursorColor: t.text,
                cursorWidth: 1.5,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                // Keeps focus after Enter (the next task goes straight in).
                onEditingComplete: () {},
                onSubmitted: (v) => unawaited(submit(v)),
                // The label above is what a screen reader says.
                decoration: InputDecoration.collapsed(
                  hintText: null,
                  hint: ExcludeSemantics(
                    child: Text(
                      placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: fieldStyle?.copyWith(color: t.faint),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (lists.isNotEmpty && selected != null) ...[
            const SizedBox(width: 10),
            _ListChip(
              lists: lists,
              selected: selected,
              maxWidth: phoneBar ? 112 : 200,
              onPick: onListChange,
            ),
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        box,
        if (!inline && (!phoneBar || readBack != null))
          Padding(
            // `.parse`: 10 below the field (6 4 0 in the add bar), 20 high.
            padding: phoneBar
                ? const EdgeInsets.fromLTRB(4, 6, 4, 0)
                : const EdgeInsets.only(top: 10),
            child: SizedBox(
              height: 20,
              child: Semantics(
                liveRegion: true,
                child: Align(alignment: Alignment.centerLeft, child: parseLine),
              ),
            ),
          ),
      ],
    );
  }
}

/// `.lchip`: the list inside the field (26 high, radius 13, `hover` fill,
/// 13 muted). Opens a menu of the lists. Its tap area is the field's
/// height.
class _ListChip extends StatelessWidget {
  const _ListChip({
    required this.lists,
    required this.selected,
    required this.maxWidth,
    required this.onPick,
  });

  final List<TaskList> lists;
  final TaskList selected;
  final double maxWidth;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(t.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: const WidgetStatePropertyAll(Color(0x40000000)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard),
            side: BorderSide(color: t.border),
          ),
        ),
      ),
      menuChildren: [
        for (final l in lists)
          MenuItemButton(
            onPressed: () => onPick(l.id),
            leadingIcon: SizedBox(
              width: 16,
              child: l.id == selected.id
                  ? WeaveIcon(WeaveIcons.check, color: t.text)
                  : null,
            ),
            child: Text(l.name, style: theme.bodyMedium),
          ),
      ],
      builder: (context, menu, _) => Pressable(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        semanticLabel: 'Add to list, ${selected.name}',
        hoverColor: Colors.transparent,
        radius: 13,
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 26,
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: t.hover,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                widthFactor: 1,
                child: ExcludeSemantics(
                  child: Text(
                    selected.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(color: t.muted),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
