import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/note_color_id.dart';
import '../../../../core/helpers/due_label.dart';
import '../../../../core/theme/weave_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/undo_toast.dart';
import '../../../../core/widgets/weave_icons.dart';
import '../../../items/domain/entities/item.dart';
import '../list_cubit.dart';
import 'color_picker.dart';

/// The app has mini bars here (macOS and Windows).
bool get hasMiniBar => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.windows => true,
  _ => false,
};

/// `.pop`: the look of every menu on the list screen.
MenuStyle listMenuStyle(BuildContext context) {
  final t = context.tokens;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(t.surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(8),
    shadowColor: const WidgetStatePropertyAll(Color(0x40000000)),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusCard)),
    ),
  );
}

/// Archive, with Undo: leaves for Up next; Undo comes back.
Future<void> archiveList(BuildContext context, ListCubit cubit) async {
  final name = cubit.state.list?.name ?? '';
  await _leave(context, cubit, cubit.archive, 'Archived $name');
}

/// Delete moves the list to Trash, with Undo.
Future<void> trashList(BuildContext context, ListCubit cubit) async {
  final name = cubit.state.list?.name ?? '';
  await _leave(context, cubit, cubit.trash, 'Moved $name to trash');
}

Future<void> _leave(
  BuildContext context,
  ListCubit cubit,
  Future<Map<String, Object?>> Function() write,
  String message,
) async {
  final router = GoRouter.of(context);
  final path = '/list/${Uri.encodeComponent(cubit.listId)}';
  final previous = await write();
  if (!context.mounted) return;
  UndoToast.show(context, message, () async {
    // This screen (and its cubit) has gone: the write needs only the repo,
    // which the closed cubit still holds.
    await cubit.restoreList(previous);
    router.go(path);
  });
  router.go('/');
}

/// The list as text (F11.1): text lines, then tasks with their state.
String listAsText(ListState s, {required bool markdown}) {
  final name = s.list?.name ?? '';
  final lines = <String>[markdown ? '# $name' : name, ''];
  for (final i in s.items) {
    final pad = '  ' * i.indent;
    if (i.kind == ItemKind.text) {
      lines.add('$pad${i.text}');
      continue;
    }
    final mark = markdown ? (i.done ? '- [x]' : '- [ ]') : (i.done ? '✓' : '○');
    final due = i.due == null || i.done ? '' : ' (${dueLabel(i.due!, s.now)})';
    lines.add('$pad$mark ${i.text}$due');
  }
  return lines.join('\n');
}

Future<void> copyList(
  BuildContext context,
  ListState s, {
  required bool markdown,
}) async {
  await Clipboard.setData(
    ClipboardData(text: listAsText(s, markdown: markdown)),
  );
  if (context.mounted) {
    UndoToast.show(context, markdown ? 'Copied as Markdown' : 'Copied as text');
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final WeaveIcons icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MenuItemButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(200, 34)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
        ),
        overlayColor: WidgetStatePropertyAll(t.hover),
      ),
      leadingIcon: WeaveIcon(icon, color: danger ? t.negative : t.muted),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: danger ? t.negative : t.text),
      ),
    );
  }
}

/// `.ibtn`: a 36 px icon button (44 on phones).
class ListIconButton extends StatelessWidget {
  const ListIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 36,
  });

  final WeaveIcons icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      child: SizedBox.square(
        dimension: size,
        child: Center(child: WeaveIcon(icon, color: context.tokens.muted)),
      ),
    );
  }
}

/// ••• on desktop (03 `more`): Pin to top · Hide done tasks · Archive ·
/// Delete list….
class ListMoreMenu extends StatelessWidget {
  const ListMoreMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    final l = context.select<ListCubit, ({bool pinned, bool hide})>(
      (c) => (
        pinned: c.state.list?.pinnedToTop ?? false,
        hide: c.state.list?.hideDone ?? false,
      ),
    );
    return MenuAnchor(
      style: listMenuStyle(context),
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        _MenuRow(
          icon: WeaveIcons.pin,
          label: l.pinned ? 'Unpin from top' : 'Pin to top',
          onPressed: () => cubit.setPinned(pinned: !l.pinned),
        ),
        _MenuRow(
          icon: WeaveIcons.check,
          label: l.hide ? 'Show done tasks' : 'Hide done tasks',
          onPressed: () => cubit.setHideDone(hide: !l.hide),
        ),
        Divider(height: 13, thickness: 1, color: context.tokens.rule),
        _MenuRow(
          icon: WeaveIcons.archive,
          label: 'Archive',
          onPressed: () => archiveList(context, cubit),
        ),
        _MenuRow(
          icon: WeaveIcons.trash,
          label: 'Delete list…',
          danger: true,
          onPressed: () => trashList(context, cubit),
        ),
      ],
      builder: (context, menu, _) => ListIconButton(
        icon: WeaveIcons.more,
        label: 'More',
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// Share on desktop (03 `share`): copy as text or Markdown.
class ListShareMenu extends StatelessWidget {
  const ListShareMenu({super.key, required this.builder});

  final Widget Function(BuildContext context, VoidCallback toggle) builder;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    return MenuAnchor(
      style: listMenuStyle(context),
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        _MenuRow(
          icon: WeaveIcons.text,
          label: 'Copy as text',
          onPressed: () => copyList(context, cubit.state, markdown: false),
        ),
        _MenuRow(
          icon: WeaveIcons.list,
          label: 'Copy as Markdown',
          onPressed: () => copyList(context, cubit.state, markdown: true),
        ),
      ],
      builder: (context, menu, _) =>
          builder(context, () => menu.isOpen ? menu.close() : menu.open()),
    );
  }
}

/// The dot's menu on desktop (03 `color`).
class ListColorMenu extends StatelessWidget {
  const ListColorMenu({super.key, required this.builder});

  final Widget Function(BuildContext context, VoidCallback toggle) builder;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListCubit>();
    final current = context.select<ListCubit, NoteColor?>(
      (c) => c.state.list?.color,
    );
    return MenuAnchor(
      style: listMenuStyle(context),
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        for (final c in NoteColor.values)
          MenuItemButton(
            onPressed: () => cubit.setColor(c),
            leadingIcon: ListDot(color: c),
            child: Text(
              c == current ? '${colorName(c)} (current)' : colorName(c),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
      builder: (context, menu, _) =>
          builder(context, () => menu.isOpen ? menu.close() : menu.open()),
    );
  }
}

Future<void> _sheet(BuildContext context, ListCubit cubit, WidgetBuilder b) {
  final t = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: t.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Builder(builder: b),
        ),
      ),
    ),
  );
}

/// The phone's ••• sheet (03 `psheet = more`).
Future<void> showListMoreSheet(BuildContext context, ListCubit cubit) {
  return _sheet(context, cubit, (sheet) {
    final s = sheet.watch<ListCubit>().state;
    final l = s.list;
    if (l == null) return const SizedBox.shrink();
    final theme = Theme.of(sheet).textTheme;
    void close() => Navigator.of(sheet).pop();
    Widget toggle(String label, bool on, ValueChanged<bool> set) =>
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.titleSmall)),
              Semantics(
                label: label,
                child: Switch(value: on, onChanged: set),
              ),
            ],
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l.name, style: theme.titleMedium),
        ),
        toggle('Pin to top', l.pinnedToTop, (v) => cubit.setPinned(pinned: v)),
        toggle(
          'Hide done tasks',
          l.hideDone,
          (v) => cubit.setHideDone(hide: v),
        ),
        const SizedBox(height: 8),
        Text('Colour', style: theme.bodySmall),
        ColorSwatches(selected: l.color, onPick: cubit.setColor),
        const SizedBox(height: 12),
        Row(
          children: [
            ListTextButton(
              label: 'Archive',
              onTap: () {
                close();
                archiveList(context, cubit);
              },
            ),
            const SizedBox(width: 8),
            ListTextButton(
              label: 'Delete',
              danger: true,
              onTap: () {
                close();
                trashList(context, cubit);
              },
            ),
          ],
        ),
      ],
    );
  });
}

/// The phone's Share sheet (03 `psheet = share`).
Future<void> showListShareSheet(BuildContext context, ListCubit cubit) {
  return _sheet(context, cubit, (sheet) {
    final s = cubit.state;
    void copy({required bool markdown}) {
      Navigator.of(sheet).pop();
      copyList(context, s, markdown: markdown);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Share ${s.list?.name ?? ''}',
            style: Theme.of(sheet).textTheme.titleMedium,
          ),
        ),
        Row(
          children: [
            ListTextButton(label: 'Text', onTap: () => copy(markdown: false)),
            const SizedBox(width: 8),
            ListTextButton(
              label: 'Markdown',
              onTap: () => copy(markdown: true),
            ),
          ],
        ),
      ],
    );
  });
}

/// `.btn` (`.sm`, `.ghost`, `.danger`): 13/500 text on `raised`.
class ListTextButton extends StatelessWidget {
  const ListTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.small = false,
    this.ghost = false,
    this.danger = false,
    this.pressed,
  });

  final String label;
  final VoidCallback onTap;
  final WeaveIcons? icon;
  final bool small;
  final bool ghost;
  final bool danger;
  final bool? pressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final on = pressed ?? false;
    final ink = danger ? t.negative : t.text;
    return Pressable(
      onTap: onTap,
      selected: pressed,
      color: on
          ? t.surface
          : ghost || danger
          ? null
          : t.raised,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(color: on ? t.text : Colors.transparent),
        ),
        child: Container(
          height: small ? 30 : t.controlHeight,
          padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon case final i?) ...[
                WeaveIcon(i, color: ink),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
