import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/core_di.dart';
import '../../../core/theme/note_color.dart';
import '../../../core/theme/weave_theme.dart';
import '../../../core/widgets/quick_capture_field.dart';
import '../../../core/widgets/shell_layout.dart';
import '../../../core/widgets/undo_toast.dart';
import '../../../core/widgets/weave_icons.dart';
import '../../items/domain/entities/item.dart';
import 'list_cubit.dart';
import 'widgets/done_group.dart';
import 'widgets/list_header.dart';
import 'widgets/list_item_row.dart';
import 'widgets/list_more_menu.dart';

/// A list's screen (03 `listScreen`, design playbook §9 List screen): the
/// title row, then the tasks on the list's note paper, 760 wide: rows, the
/// add row and its ruled lines (phones: the shell's add bar), then Done.
class ListPage extends StatelessWidget {
  const ListPage({super.key, required this.listId, this.isNew = false});

  final String listId;

  /// Just made: the name starts selected.
  final bool isNew;

  static const rowsKey = ValueKey('list-rows');
  static const titleKey = ValueKey('list-title');

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ListCubit>(
      create: (_) => sl<ListCubit>(param1: listId),
      child: _ListView(isNew: isNew),
    );
  }
}

/// `color-mix(in srgb, var(--ci) N%, transparent)`.
Color _inkMix(NoteColor c, Brightness b, double n) =>
    c.ink(b).withValues(alpha: n);

class _ListView extends HookWidget {
  const _ListView({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    final s = context.watch<ListCubit>().state;
    final layout = ShellLayout.of(context);
    final phone = layout.isPhone;

    useOnAppLifecycleStateChange((_, now) {
      if (now == AppLifecycleState.resumed) cubit.refresh();
    });

    // Archived, trashed or deleted, here or on another device.
    final gone = s.gone;
    useEffect(() {
      if (gone) {
        final router = GoRouter.maybeOf(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) router?.go('/');
        });
      }
      return null;
    }, [gone]);

    final l = s.list;
    if (l == null) return const SizedBox.shrink();

    final header = ListHeader(
      phone: phone,
      isNew: isNew,
      titleKey: ListPage.titleKey,
    );
    final note = _Note(phone: phone);
    return ListView(
      padding: layout.padding,
      children: [
        if (phone)
          header
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: header,
            ),
          ),
        if (phone)
          note
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: note,
            ),
          ),
      ],
    );
  }
}

/// `.card.paper.notecard`: the tasks on the list's note paper.
class _Note extends StatelessWidget {
  const _Note({required this.phone});

  final bool phone;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    final s = context.watch<ListCubit>().state;
    final l = s.list;
    if (l == null) return const SizedBox.shrink();
    final t = context.tokens;
    final b = Theme.of(context).brightness;
    final theme = Theme.of(context).textTheme;
    final color = l.color;
    final rule = _inkMix(color, b, 0.14);
    final paper = Color.alphaBlend(
      color.fill(b).withValues(alpha: t.paperMix),
      t.surface,
    );
    final pad = phone ? 16.0 : 20.0;
    final rows = s.rows;
    final done = s.done;
    final checks = s.open.length + done.length;

    Widget row(Item i, {required bool first, int? dragIndex}) =>
        i.kind == ItemKind.text
        ? TextLineRow(key: ValueKey(i.id), item: i)
        : ListItemRow(
            key: ValueKey(i.id),
            item: i,
            now: s.now,
            color: color,
            phone: phone,
            first: first,
            ruleColor: rule,
            dragIndex: dragIndex,
          );

    Future<void> uncheckAll() async {
      final previous = await cubit.uncheckAll();
      if (!context.mounted || previous.isEmpty) return;
      UndoToast.show(
        context,
        'Unchecked ${previous.length} in ${l.name}',
        () => cubit.restoreAll(previous),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(pad - 8, pad, pad - 8, pad),
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: _inkMix(color, b, 0.22)),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReorderableListView(
            key: ListPage.rowsKey,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => unawaited(cubit.drop(from, to)),
            proxyDecorator: (child, _, _) => Material(
              color: paper,
              elevation: 4,
              borderRadius: BorderRadius.circular(t.radiusControl),
              child: child,
            ),
            children: [
              for (final (n, i) in rows.indexed)
                KeyedSubtree(
                  key: ValueKey('row-${i.id}'),
                  child: row(
                    i,
                    first: n == 0,
                    dragIndex: ListState.movable(i) ? n : null,
                  ),
                ),
            ],
          ),
          if (!phone) _AddRow(rule: rule, listName: l.name),
          if (checks == 0)
            Padding(
              padding: EdgeInsets.fromLTRB(8, phone ? 0 : 8, 8, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: t.control),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    'Nothing here yet. Type below and press Enter.',
                    style: theme.bodyMedium?.copyWith(color: t.muted),
                  ),
                ),
              ),
            ),
          if (done.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: l.hideDone
                  ? DoneBar(
                      ruleColor: rule,
                      left: Text(
                        '${done.length} done, hidden',
                        style: theme.bodySmall?.copyWith(color: t.muted),
                      ),
                      right: ListTextButton(
                        label: 'Show',
                        small: true,
                        ghost: true,
                        onTap: () => cubit.setHideDone(hide: false),
                      ),
                    )
                  : DoneGroup(
                      count: done.length,
                      open: s.doneOpen,
                      ruleColor: rule,
                      onToggle: cubit.toggleDoneOpen,
                      onUncheckAll: () => unawaited(uncheckAll()),
                      children: [
                        for (final (n, i) in done.indexed)
                          row(i, first: n == 0),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

Future<bool> _addLine(BuildContext context, ListCubit cubit, String raw) async {
  try {
    await cubit.add(raw);
    return true;
  } on Object catch (e) {
    developer.log('add failed: ${e.runtimeType}', name: 'Capture');
    if (context.mounted) {
      UndoToast.show(context, "Couldn't add that. Try again.");
    }
    return false;
  }
}

/// `.ruled`: the add row, then the note's slack as ruled lines.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.rule, required this.listName});

  static const _lines = 3;

  final Color rule;
  final String listName;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuickCaptureField(
            listId: cubit.listId,
            inline: true,
            ruleColor: rule,
            placeholder: 'Add a task…',
            semanticLabel: 'Add a task to $listName',
            onListChange: (_) {},
            onSubmit: (raw) => _addLine(context, cubit, raw),
          ),
          for (var n = 0; n < _lines; n++)
            Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: rule)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The phone add bar on a list (pinned above the tabs by the shell).
class ListAddBar extends StatelessWidget {
  const ListAddBar({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ListCubit>(
      create: (_) => sl<ListCubit>(param1: listId),
      child: Builder(
        builder: (context) {
          final cubit = context.read<ListCubit>();
          final name = context.select<ListCubit, String>(
            (c) => c.state.list?.name ?? '',
          );
          return QuickCaptureField(
            listId: listId,
            phoneBar: true,
            placeholder: 'Add a task…',
            semanticLabel: 'Add a task to $name',
            onListChange: (_) {},
            onSubmit: (raw) => _addLine(context, cubit, raw),
          );
        },
      ),
    );
  }
}

/// The list's Share and ••• in the phone's top bar (03 `.ptop`).
class ListTopActions extends StatelessWidget {
  const ListTopActions({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ListCubit>(
      create: (_) => sl<ListCubit>(param1: listId),
      child: Builder(
        builder: (context) {
          final cubit = context.read<ListCubit>();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListIconButton(
                icon: WeaveIcons.share,
                label: 'Share',
                size: 44,
                onTap: () => showListShareSheet(context, cubit),
              ),
              ListIconButton(
                icon: WeaveIcons.more,
                label: 'More',
                size: 44,
                onTap: () => showListMoreSheet(context, cubit),
              ),
            ],
          );
        },
      ),
    );
  }
}
