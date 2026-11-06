import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/helpers/due_label.dart';
import '../../core/theme/note_color.dart';
import '../../core/theme/weave_theme.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shell_layout.dart';
import '../../core/widgets/weave_icons.dart';
import '../../features/lists/domain/entities/task_list.dart';
import 'shell_actions.dart';
import 'shell_cubit.dart';
import 'sidebar.dart';

/// The phone's Lists tab (03 `phoneLists`): every list as a note in two
/// columns, then New list and Archive and trash.
class PhoneListsPage extends StatelessWidget {
  const PhoneListsPage({super.key, required this.actions});

  final ShellActions actions;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShellCubit>().state;
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final open = s.lists.fold<int>(0, (n, l) => n + l.openCount);
    Widget card(Widget child, EdgeInsets padding) => Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: child,
    );
    final notes = <Widget>[];
    for (var n = 0; n < s.lists.length; n += 2) {
      final second = n + 1 < s.lists.length ? s.lists[n + 1] : null;
      notes.add(
        Padding(
          padding: EdgeInsets.only(top: n == 0 ? 0 : 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _NoteCard(
                    list: s.lists[n],
                    inBar: s.shownInMiniBar.contains(s.lists[n].id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: second == null
                      ? const SizedBox.shrink()
                      : _NoteCard(
                          list: second,
                          inBar: s.shownInMiniBar.contains(second.id),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: ShellLayout.of(context).padding,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Lists',
            style: theme.headlineSmall?.copyWith(height: 32 / 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${s.lists.length} lists · $open open',
          style: t.numeric.copyWith(color: t.muted),
        ),
        const SizedBox(height: 16),
        if (notes.isNotEmpty) ...[
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: notes,
            ),
            const EdgeInsets.all(16),
          ),
          const SizedBox(height: 12),
        ],
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavRow(
                icon: WeaveIcons.plus,
                label: 'New list',
                onTap: () => actions.newList(context),
              ),
              NavRow(
                icon: WeaveIcons.archive,
                label: 'Archive and trash',
                count: s.archiveTrashCount,
                onTap: () => context.go('/archive'),
              ),
            ],
          ),
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ],
    );
  }
}

/// `.note.paper`: name, then what's left and what's next.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.list, required this.inBar});

  final TaskList list;
  final bool inBar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = Theme.of(context).brightness;
    final theme = Theme.of(context).textTheme;
    final l = list;
    final small = t.numeric.copyWith(fontSize: t.fsSmall, color: t.muted);
    final next = l.nextDue;
    final late = l.overdueCount;
    final now = DateTime.now();
    final tail = late > 0
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WeaveIcon(WeaveIcons.alert, color: t.negative),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$late overdue',
                  style: small.copyWith(color: t.negative),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Text(
            next != null
                ? 'next ${rowDueLabel(next, now)}'
                : l.openCount > 0
                ? 'no times set'
                : 'nothing left',
            style: small,
            overflow: TextOverflow.ellipsis,
          );
    return Pressable(
      onTap: () => context.go('/list/${Uri.encodeComponent(l.id)}'),
      color: Color.alphaBlend(
        l.color.fill(b).withValues(alpha: t.paperMix),
        t.surface,
      ),
      hoverColor: Color.alphaBlend(
        l.color.fill(b).withValues(alpha: t.paperMix),
        t.surface,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(color: l.color.ink(b).withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (inBar)
                  Semantics(
                    label: 'In the mini bar',
                    child: WeaveIcon(WeaveIcons.screen, color: t.muted),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l.openCount > 0 ? '${l.openCount} left' : 'All done',
                  style: small.copyWith(color: t.text),
                ),
                Text(' · ', style: small),
                tail,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
