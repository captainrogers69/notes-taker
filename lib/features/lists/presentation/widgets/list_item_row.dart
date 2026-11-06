import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../core/theme/note_color.dart';
import '../../../../core/theme/weave_theme.dart';
import '../../../../core/widgets/item_tile.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/undo_toast.dart';
import '../../../../core/widgets/weave_icons.dart';
import '../../../items/domain/entities/item.dart';
import '../list_cubit.dart';
import 'inline_edit.dart';

/// One task on the note (03 `itemRow`): grip (on hover) · tick · the task as
/// an inline editor · chips and time · details chevron (on hover or focus).
/// On phones the row has no editor or grip: tapping it opens the details,
/// and a long press drags ([dragIndex]).
class ListItemRow extends HookWidget {
  const ListItemRow({
    super.key,
    required this.item,
    required this.now,
    required this.color,
    required this.phone,
    required this.first,
    required this.ruleColor,
    this.dragIndex,
  });

  final Item item;
  final DateTime now;
  final NoteColor color;
  final bool phone;
  final bool first;
  final Color ruleColor;

  /// This row's place in the reorderable rows (null: it cannot be dragged).
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    final t = context.tokens;
    final selected = context.select<ListCubit, bool>(
      (c) => c.state.selectedItemId == item.id,
    );
    final hover = useState(false);
    final within = useState(false);

    Future<void> tick() async {
      final previous = await cubit.toggle(item.id);
      if (!context.mounted || item.done || previous.isEmpty) return;
      UndoToast.show(
        context,
        'Checked "${item.text}"',
        () => cubit.restore(item.id, previous),
      );
    }

    final index = dragIndex;
    Widget? grip;
    if (!phone) {
      final mark = Opacity(
        opacity: hover.value && index != null ? 1 : 0,
        child: SizedBox(
          width: 14,
          height: 24,
          child: Center(child: WeaveIcon(WeaveIcons.grip, color: t.faint)),
        ),
      );
      grip = index == null
          ? mark
          : MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: ReorderableDragStartListener(index: index, child: mark),
            );
    }

    final tile = ItemTile(
      item: item,
      listName: null,
      now: now,
      color: color,
      phone: phone,
      rule: !first,
      ruleColor: ruleColor,
      listRow: true,
      selected: selected,
      leading: grip,
      onTap: () => cubit.select(item.id),
      onToggle: () => unawaited(tick()),
      titleField: phone
          ? null
          : ItemEditor(
              item: item,
              onFocusChange: (on) {
                within.value = on;
                if (on) cubit.select(item.id);
              },
            ),
      trailing: phone
          ? null
          : Opacity(
              opacity: hover.value || within.value || selected ? 1 : 0,
              child: Pressable(
                onTap: () => cubit.select(item.id),
                semanticLabel: 'Details for ${item.text}',
                child: SizedBox.square(
                  dimension: 24,
                  child: Center(
                    child: WeaveIcon(WeaveIcons.chevRight, color: t.muted),
                  ),
                ),
              ),
            ),
    );

    final row = MouseRegion(
      onEnter: (_) => hover.value = true,
      onExit: (_) => hover.value = false,
      child: tile,
    );
    return phone && index != null
        ? ReorderableDelayedDragStartListener(index: index, child: row)
        : row;
  }
}

/// `.noteline`: a text line between the tasks, muted.
class TextLineRow extends StatelessWidget {
  const TextLineRow({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: ItemEditor(item: item, label: 'Text line', muted: true),
    );
  }
}

/// A row's text, edited in place ([InlineEdit] has when it writes).
///
/// Keys (03 `keydown`): Enter adds a task below · Backspace on empty removes
/// the row and goes up · Tab / Shift+Tab indents · Alt+↑ / ↓ moves · Esc
/// leaves the row.
class ItemEditor extends HookWidget {
  const ItemEditor({
    super.key,
    required this.item,
    this.label = 'Task. Alt+Up or Alt+Down moves it.',
    this.muted = false,
    this.onFocusChange,
  });

  final Item item;
  final String label;
  final bool muted;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    final t = context.tokens;
    final body = Theme.of(context).textTheme.bodyMedium;
    final controller = useTextEditingController(text: item.text);

    // The handlers outlive this build; these keep them current.
    final latest = useRef(item);
    latest.value = item;
    final removed = useRef(false);
    final edit = useInlineEdit(
      text: item.text,
      controller: controller,
      write: (text) => cubit.editText(latest.value.id, text),
    );

    Future<void> leave() async {
      if (removed.value) return;
      if (!appActive) return edit.save();
      final saved = latest.value;
      if (controller.text.trim().isNotEmpty) {
        // Not after the await: going away disposes the field meanwhile.
        final saving = edit.save();
        edit.settle(saved.text);
        await saving;
      } else if (edit.baseline.isNotEmpty) {
        // Cleared and left: Backspace is how a task goes, so keep it.
        edit.reset(edit.baseline);
      } else if (cubit.madeHere(saved.id)) {
        // Made by Enter and left blank. A blank row from another device is
        // still being typed there.
        removed.value = true;
        await cubit.removeBlank(saved.id);
      } else {
        edit.reset('');
      }
    }

    KeyEventResult onKey(FocusNode node, KeyEvent e) {
      if (e is! KeyDownEvent) return KeyEventResult.ignored;
      if (controller.value.composing.isValid) return KeyEventResult.ignored;
      final keys = HardwareKeyboard.instance;
      final current = latest.value;
      final key = e.logicalKey;
      if (keys.isAltPressed &&
          (key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown)) {
        if (current.kind != ItemKind.task) return KeyEventResult.ignored;
        final dir = key == LogicalKeyboardKey.arrowUp ? -1 : 1;
        unawaited(cubit.move(current.id, dir));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (keys.isShiftPressed) return KeyEventResult.ignored;
        unawaited(leave());
        unawaited(cubit.addBelow(current));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.backspace && controller.text.isEmpty) {
        removed.value = true;
        if (edit.baseline.isNotEmpty) {
          UndoToast.show(
            context,
            'Deleted "${edit.baseline}"',
            () => cubit.restore(current.id, {'deletedAt': null}),
          );
        }
        unawaited(cubit.removeAndGoUp(current));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        cubit.select(null);
        node.unfocus();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab && current.kind == ItemKind.task) {
        unawaited(cubit.setIndent(current.id, keys.isShiftPressed ? 0 : 1));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final keyHandler = useRef(onKey);
    keyHandler.value = onKey;
    final focus = useFocusNode(
      debugLabel: 'list row',
      onKeyEvent: (n, e) => keyHandler.value(n, e),
    );

    final changed = useRef(onFocusChange);
    changed.value = onFocusChange;
    final leaveNow = useRef(leave);
    leaveNow.value = leave;
    useEffect(() {
      void listen() {
        changed.value?.call(focus.hasFocus);
        if (!focus.hasFocus) unawaited(leaveNow.value());
      }

      focus.addListener(listen);
      return () {
        focus.removeListener(listen);
        // Going away while typing still saves it.
        unawaited(leaveNow.value());
      };
    }, [focus]);

    // The cubit asks for this row (a new row, or the one above a removed
    // one, or a moved one).
    final wanted = context.select<ListCubit, bool>(
      (c) => c.state.focusId == item.id,
    );
    useEffect(() {
      if (wanted) {
        focus.requestFocus();
        cubit.focused();
      }
      return null;
    }, [wanted]);

    final style = body?.copyWith(
      color: item.done || muted ? t.muted : t.text,
      decoration: item.done ? TextDecoration.lineThrough : null,
      decorationColor: t.muted,
    );
    return Semantics(
      label: label,
      child: TextField(
        controller: controller,
        focusNode: focus,
        style: style,
        cursorColor: t.text,
        cursorWidth: 1.5,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onEditingComplete: () {},
        // The soft keyboard's Done; hardware Enter is handled above.
        onSubmitted: (_) {
          unawaited(leave());
          unawaited(cubit.addBelow(latest.value));
        },
        decoration: const InputDecoration.collapsed(hintText: null),
      ),
    );
  }
}
