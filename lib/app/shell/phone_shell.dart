import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/weave_theme.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_toast.dart';
import '../../core/widgets/weave_icons.dart';
import '../../features/lists/presentation/list_page.dart';
import '../../features/up_next/presentation/up_next_page.dart';
import '../router.dart';
import 'app_shell.dart';
import 'tab_bar.dart';

/// The add bar pinned above the tabs on Up next and list screens (design
/// playbook §9 Layouts), each with its own `QuickCaptureField`.
Widget? phoneAddBar(ShellLocation location) => switch (location) {
  ShellLocation(route: AppRoute.upNext) => const UpNextAddBar(),
  ShellLocation(route: AppRoute.list, :final listId?) => ListAddBar(
    key: ValueKey(listId),
    listId: listId,
  ),
  _ => null,
};

/// Phones and windows under 720: top bar (only on screens pushed inside
/// the Lists tab: back to Lists) · screen · add bar · tab bar. No brand row
/// (C11). The Undo toast sits just above the add bar.
class PhoneShell extends StatelessWidget {
  const PhoneShell({
    super.key,
    required this.location,
    required this.toast,
    required this.upNextCount,
    required this.child,
    this.addBar,
    this.platform,
  });

  final ShellLocation location;
  final UndoToastController toast;
  final int upNextCount;
  final Widget child;

  /// Defaults to [phoneAddBar].
  final Widget? addBar;
  final TargetPlatform? platform;

  /// The toast's gap above the add bar (or the tab bar).
  static const toastGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final route = location.route;
    // A list and Archive and trash are pushed inside the Lists tab.
    final sub = route == AppRoute.list || route == AppRoute.archive;
    final tab = sub || route == AppRoute.lists
        ? AppRoute.lists
        : route == AppRoute.search || route == AppRoute.settings
        ? route
        : AppRoute.upNext;
    final bar = addBar ?? phoneAddBar(location);
    // System back: from a screen inside the Lists tab to Lists; from any
    // other tab to Up next; only Up next leaves the app.
    return PopScope(
      canPop: route == AppRoute.upNext,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.goNamed(sub ? AppRoute.lists.name : AppRoute.upNext.name);
      },
      child: Material(
        color: t.ground,
        // No Scaffold here: this keeps the add bar above the keyboard.
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            // The body's Stack holds only positioned children, so it takes its
            // width from here: without stretch it would be 0 wide.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: MediaQuery.viewPaddingOf(context).top),
              if (sub)
                _TopBar(
                  platform: platform,
                  actions: switch (location.listId) {
                    final id? when route == AppRoute.list => ListTopActions(
                      key: ValueKey(id),
                      listId: id,
                    ),
                    _ => null,
                  },
                ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: child),
                    UndoToastLayer(controller: toast, bottom: toastGap),
                  ],
                ),
              ),
              if (bar != null)
                // `.paddbar`: padding 8 12 8, 1 px border above, surface.
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border(top: BorderSide(color: t.border)),
                  ),
                  child: bar,
                ),
              PhoneTabBar(
                current: tab,
                upNextCount: upNextCount,
                platform: platform,
                onSelect: (r) => context.goNamed(r.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.ptop`: 48 high, padding 0 8. Back: iOS "‹ Lists" (chevron + parent
/// name, 16 px); Android a plain ← (the system back does the same).
/// [actions]: the list screen's Share and •••, on the right.
class _TopBar extends StatelessWidget {
  const _TopBar({this.platform, this.actions});

  final TargetPlatform? platform;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final android =
        (platform ?? defaultTargetPlatform) == TargetPlatform.android;
    void back() => context.goNamed(AppRoute.lists.name);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (android)
              Pressable(
                onTap: back,
                semanticLabel: 'Back to Lists',
                tooltip: 'Back to Lists',
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: WeaveIcon(WeaveIcons.back, color: t.muted),
                  ),
                ),
              )
            else
              Pressable(
                onTap: back,
                hoverColor: Colors.transparent,
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 8, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WeaveIcon(WeaveIcons.back, size: 20, color: t.text),
                        const SizedBox(width: 2),
                        Text(
                          'Lists',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            ?actions,
          ],
        ),
      ),
    );
  }
}
