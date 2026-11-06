import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../core/domain/note_color_id.dart';
import '../../../../core/helpers/due_label.dart';
import '../../../../core/theme/weave_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/weave_icons.dart';
import '../list_cubit.dart';
import 'color_picker.dart';
import 'inline_edit.dart';
import 'list_more_menu.dart';

/// The title row (03 `listScreen`): the dot (the colour), the editable name,
/// the list's due chip and one fact below. Desktop adds Show in mini bar,
/// Share and •••; phones have those in the shell's top bar.
class ListHeader extends HookWidget {
  const ListHeader({
    super.key,
    required this.phone,
    required this.isNew,
    required this.titleKey,
  });

  final bool phone;

  /// A new list: the name starts selected.
  final bool isNew;
  final Key titleKey;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    final s = context.watch<ListCubit>().state;
    final l = s.list;
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final name = l?.name ?? '';
    final controller = useTextEditingController(text: name);
    final focus = useFocusNode(debugLabel: 'list name');
    useListenable(focus);

    final edit = useInlineEdit(
      text: name,
      controller: controller,
      write: cubit.rename,
      stored: (v) => v.trim(),
    );

    // A blank name reads "Untitled list" when you leave the field.
    Future<void> leave() async {
      if (!appActive) return edit.save();
      final text = controller.text.trim();
      if (text.isEmpty) {
        edit.reset(ListCubit.untitled);
        return cubit.rename('');
      }
      // Not after the await: going away disposes the field meanwhile.
      final saving = edit.save();
      if (controller.text != text) edit.reset(text);
      await saving;
    }

    final leaveNow = useRef(leave);
    leaveNow.value = leave;
    useEffect(() {
      void left() {
        if (!focus.hasFocus) unawaited(leaveNow.value());
      }

      focus.addListener(left);
      return () {
        focus.removeListener(left);
        // Going away while typing still saves it.
        unawaited(leaveNow.value());
      };
    }, [focus]);
    final selectedOnce = useRef(false);
    useEffect(() {
      if (isNew && l != null && !selectedOnce.value) {
        selectedOnce.value = true;
        focus.requestFocus();
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
      return null;
    }, [isNew, l != null]);

    final color = l?.color ?? NoteColor.yellow;
    Widget dotButton(VoidCallback onTap) => Pressable(
      onTap: onTap,
      semanticLabel: 'Change colour',
      radius: 12,
      hoverColor: Colors.transparent,
      child: SizedBox.square(
        dimension: phone ? 44 : 24,
        child: Center(child: ListDot(color: color, size: 14)),
      ),
    );

    final titleStyle = theme.headlineSmall?.copyWith(height: 32 / 24);
    final title = Row(
      children: [
        if (phone)
          dotButton(() => showListMoreSheet(context, cubit))
        else
          ListColorMenu(builder: (_, toggle) => dotButton(toggle)),
        SizedBox(width: phone ? 2 : 7),
        Flexible(
          child: IntrinsicWidth(
            child: Semantics(
              label: 'List name, editable',
              child: TextField(
                key: titleKey,
                controller: controller,
                focusNode: focus,
                style: titleStyle,
                cursorColor: t.text,
                cursorWidth: 1.5,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => unawaited(leave()),
                decoration: InputDecoration.collapsed(
                  hintText: null,
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: focus.hasFocus ? t.text : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (l?.due case final due?) ...[
          const SizedBox(width: 12),
          _DueChip(label: 'Due ${rowDueLabel(due, s.now)}'),
        ],
      ],
    );

    final open = s.open.length;
    final next = s.next;
    final numStyle = t.numeric.copyWith(color: t.text);
    final subline = Text.rich(
      open == 0
          ? const TextSpan(text: 'All done')
          : TextSpan(
              children: [
                TextSpan(text: '$open', style: numStyle),
                const TextSpan(text: ' left'),
                if (next != null) ...[
                  TextSpan(text: ' · next ${next.text} '),
                  if (rowDueLabel(next.due!, s.now).contains(' '))
                    TextSpan(
                      text: '· ${rowDueLabel(next.due!, s.now)}',
                      style: t.numeric,
                    )
                  else ...[
                    const TextSpan(text: 'at '),
                    TextSpan(
                      text: rowDueLabel(next.due!, s.now),
                      style: t.numeric,
                    ),
                  ],
                ],
              ],
            ),
      style: theme.bodyMedium?.copyWith(color: t.muted),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 4), subline],
    );

    if (phone) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: titleBlock,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: 16),
          if (hasMiniBar) ...[
            ListTextButton(
              label: s.inMiniBar ? 'In mini bar' : 'Show in mini bar',
              icon: s.inMiniBar ? WeaveIcons.check : WeaveIcons.screen,
              pressed: s.inMiniBar,
              onTap: () => cubit.setMiniBar(shown: !s.inMiniBar),
            ),
            const SizedBox(width: 8),
          ],
          ListShareMenu(
            builder: (_, toggle) => ListTextButton(
              label: 'Share',
              icon: WeaveIcons.share,
              onTap: toggle,
            ),
          ),
          const SizedBox(width: 8),
          const ListMoreMenu(),
        ],
      ),
    );
  }
}

/// `.tchip`: the list's due date beside its name.
class _DueChip extends StatelessWidget {
  const _DueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WeaveIcon(WeaveIcons.clock, color: t.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: t.numeric.copyWith(fontSize: t.fsSmall, color: t.muted),
        ),
      ],
    );
  }
}
