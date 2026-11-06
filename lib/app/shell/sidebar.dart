import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_gateway.dart';
import '../../core/helpers/platform_labels.dart';
import '../../core/sync/sync_status.dart';
import '../../core/theme/note_color.dart';
import '../../core/theme/weave_theme.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/sync_status_badge.dart';
import '../../core/widgets/weave_icons.dart';
import '../../core/widgets/weave_mark.dart';
import '../../features/account/presentation/session_cubit.dart';
import '../../features/lists/domain/entities/task_list.dart';
import '../router.dart';
import 'app_shell.dart';
import 'shell_actions.dart';
import 'shell_cubit.dart';

/// The desktop sidebar (design playbook §9 Sidebar, 03 `app.js` `sidebar()`):
/// brand · sync line · search (⌘K) · Up next · Pinned · Lists · New list
/// (⌘N) · footer: Archive and trash, Settings, the user row. Counts only,
/// no progress bars (C7).
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.location,
    required this.actions,
    required this.searchFocus,
    required this.search,
  });

  final ShellLocation location;
  final ShellActions actions;
  final FocusNode searchFocus;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShellCubit>().state;
    final route = location.route;
    final pinned = s.lists.where((l) => l.pinnedToTop).toList();
    final others = s.lists.where((l) => !l.pinnedToTop).toList();
    final mod = modifierLabel();

    Widget listRow(TaskList l) => _ListRow(
      key: ValueKey(l.id),
      list: l,
      selected: route == AppRoute.list && location.listId == l.id,
      inMiniBar: s.shownInMiniBar.contains(l.id),
    );

    return Padding(
      // app.css `.side { padding: 16px 12px 12px }`
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: CustomScrollView(
        slivers: [
          SliverList.list(
            children: [
              const _Brand(),
              _SyncLine(actions: actions, devices: s.deviceCount),
              _SearchField(focus: searchFocus, controller: search, mod: mod),
              NavRow(
                icon: WeaveIcons.sun,
                label: 'Up next',
                count: s.upNextCount,
                selected: route == AppRoute.upNext,
                onTap: () => context.goNamed(AppRoute.upNext.name),
              ),
              if (pinned.isNotEmpty) ...[
                const _Group('Pinned'),
                ...pinned.map(listRow),
              ],
              const _Group('Lists'),
              ...others.map(listRow),
              NavRow(
                icon: WeaveIcons.plus,
                label: 'New list',
                muted: true,
                kbd: '${mod}N',
                onTap: () => actions.newList(context),
              ),
            ],
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 16),
                NavRow(
                  icon: WeaveIcons.archive,
                  label: 'Archive and trash',
                  count: s.archiveTrashCount,
                  selected: route == AppRoute.archive,
                  onTap: () => context.goNamed(AppRoute.archive.name),
                ),
                NavRow(
                  icon: WeaveIcons.gear,
                  label: 'Settings',
                  selected: route == AppRoute.settings,
                  onTap: () => context.goNamed(AppRoute.settings.name),
                ),
                _UserRow(actions: actions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    // `.brand`: height 32, padding 0 8, gap 10; mark 20; "Weave" 15/500.
    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const WeaveMark(size: 20),
            const SizedBox(width: 10),
            Text('Weave', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.actions, required this.devices});

  final ShellActions actions;
  final int devices;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<SyncStatusCubit>().state;
    final signedOut = context.select<SessionCubit, bool>(
      (c) => c.accountSignedOut,
    );
    // `.syncline { margin: 0 8px 10px 38px }`: under the word "Weave".
    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 0, 8, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SyncStatusBadge(
          status: status,
          devices: devices,
          signedOut: signedOut,
          style: SyncBadgeStyle.sidebar,
          // Text only when signed out: Sign in is the user row (C4).
          onRetry: () => actions.retrySync(),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.focus,
    required this.controller,
    required this.mod,
  });

  final FocusNode focus;
  final TextEditingController controller;
  final String mod;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    // `.search`: 32 high, padding 0 10, margin-bottom 14, 1 px control
    // border, radius 6, surface; icon and placeholder faint; kbd 12 faint.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: focus.requestFocus,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.control),
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
          child: Row(
            children: [
              WeaveIcon(WeaveIcons.search, color: t.faint),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: 'Search notes',
                  child: TextField(
                    focusNode: focus,
                    controller: controller,
                    style: tt.bodyMedium,
                    cursorColor: t.text,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search',
                      hintStyle: tt.bodyMedium?.copyWith(color: t.faint),
                      semanticCounterText: '',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${mod}K', style: tt.labelSmall?.copyWith(color: t.faint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One sidebar row (`.navrow`): 32 high, padding 0 8, gap 10, radius 6;
/// `raised` when current, `hover` on hover; the count is 13 muted, tabular.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.count,
    this.blankZero = false,
    this.kbd,
    this.trailing,
    this.selected = false,
    this.muted = false,
    this.paper,
    this.onTap,
  });

  final WeaveIcons? icon;
  final Widget? leading;
  final String label;

  /// Shown as is (also 0), except null.
  final int? count;

  /// Shows nothing for a 0 [count] (list rows: `D.open(l).length || ''`).
  final bool blankZero;
  final String? kbd;
  final Widget? trailing;
  final bool selected;
  final bool muted;

  /// Note paper behind a row that is not current (the list in the mini
  /// bar).
  final Color? paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final lead = leading;
    final n = count;
    final k = kbd;
    final tr = trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Pressable(
        onTap: onTap,
        selected: selected,
        color: selected ? t.raised : paper,
        hoverColor: selected ? t.raised : null,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ?lead,
                if (icon case final i?) WeaveIcon(i, color: t.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: tt.bodyMedium?.copyWith(
                      color: muted ? t.muted : t.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                if (tr != null) ...[const SizedBox(width: 10), tr],
                if (n != null) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 12),
                    child: Text(
                      n == 0 && blankZero ? '' : '$n',
                      textAlign: TextAlign.right,
                      style: tt.bodySmall
                          ?.merge(t.numeric)
                          .copyWith(color: t.muted),
                    ),
                  ),
                ],
                if (k != null) ...[
                  const SizedBox(width: 10),
                  Text(k, style: tt.labelSmall?.copyWith(color: t.faint)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    super.key,
    required this.list,
    required this.selected,
    required this.inMiniBar,
  });

  final TaskList list;
  final bool selected;
  final bool inMiniBar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = Theme.of(context).brightness;
    final fill = list.color.fill(b);
    return NavRow(
      // `.ndot`: a 10 px dot (fill, 1 px ink edge) centred in 16.
      leading: SizedBox(
        width: 16,
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: list.color.ink(b)),
            ),
          ),
        ),
      ),
      label: list.name,
      count: list.openCount,
      blankZero: true,
      selected: selected,
      paper: inMiniBar ? fill.withValues(alpha: t.paperMix) : null,
      trailing: inMiniBar
          ? Tooltip(
              message: 'In the mini bar',
              child: Semantics(
                label: 'In the mini bar',
                child: WeaveIcon(WeaveIcons.screen, color: t.muted),
              ),
            )
          : null,
      onTap: () =>
          context.goNamed(AppRoute.list.name, pathParameters: {'id': list.id}),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // `.group { margin: 22px 8px 6px }`, 13 muted.
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 22, 8, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.actions});

  final ShellActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final user = context.select<SessionCubit, AuthUser?>((c) => c.currentUser);
    // Local mode only in [LocalSession]; while signing in or out the row
    // shows no account and offers no Sign in.
    final local = context.select<SessionCubit, bool>(
      (c) => c.state is LocalSession,
    );
    final email = user?.email ?? '';
    final avatar = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: t.raised, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: local
          ? WeaveIcon(WeaveIcons.laptop, color: t.muted)
          : Text(
              email.isEmpty ? '' : email.characters.first.toUpperCase(),
              style: tt.labelMedium,
            ),
    );
    final who = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            local ? 'Local mode' : email,
            style: tt.bodyMedium,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          if (local)
            Text(
              'Sign in to sync devices',
              style: tt.bodySmall?.copyWith(color: t.muted),
            ),
        ],
      ),
    );
    // `.userrow`: margin-top 8, padding 14 8 8, 1 px rule above.
    final row = Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.rule)),
      ),
      child: Row(children: [avatar, const SizedBox(width: 10), who]),
    );
    if (!local) return row;
    return Pressable(
      onTap: () => actions.signIn(context),
      hoverColor: Colors.transparent,
      radius: 0,
      child: row,
    );
  }
}
