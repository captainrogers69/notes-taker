import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'shell/app_shell.dart';
import 'shell/placeholder_pages.dart';
import 'shell/shell_actions.dart';

/// The app's routes (architecture playbook §9). Navigate with
/// `context.goNamed(AppRoute.x.name)`.
enum AppRoute {
  upNext('/'),
  list('/list/:id'),
  archive('/archive'),
  search('/search'),
  settings('/settings'),

  /// Phone only (the Lists tab); desktop shows Up next there, as the
  /// sidebar already lists them.
  lists('/lists');

  const AppRoute(this.path);

  final String path;
}

/// The router: every route sits inside the [AppShell] (sidebar on desktop,
/// tab bar on phones). Pages that later tasks build are placeholders now
/// (see `placeholder_pages.dart`).
GoRouter buildRouter({ShellActions? actions, String initialLocation = '/'}) {
  final a = actions ?? ShellActions.standard();
  GoRoute route(AppRoute r, Widget Function(GoRouterState s) page) => GoRoute(
    path: r.path,
    name: r.name,
    pageBuilder: (context, state) => NoTransitionPage(child: page(state)),
  );
  return GoRouter(
    initialLocation: initialLocation,
    // The Lists tab is phone-only: a wide window shows Up next there.
    redirect: (context, state) =>
        state.uri.path == AppRoute.lists.path && !_isPhone(context)
        ? AppRoute.upNext.path
        : null,
    // Unknown paths (old deep links, typos) land on Up next.
    onException: (context, state, router) => router.go(AppRoute.upNext.path),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state, actions: a, child: child),
        routes: [
          route(AppRoute.upNext, (_) => const UpNextPlaceholder()),
          route(
            AppRoute.list,
            (s) => ListPlaceholder(listId: s.pathParameters['id'] ?? ''),
          ),
          route(AppRoute.archive, (_) => const ArchivePlaceholder()),
          route(AppRoute.search, (_) => const SearchPlaceholder()),
          route(AppRoute.settings, (_) => const SettingsPlaceholder()),
          route(AppRoute.lists, (_) => const ListsPlaceholder()),
        ],
      ),
    ],
  );
}

/// Width check for the redirect (same breakpoint as [AppShell]).
bool _isPhone(BuildContext context) {
  var size = MediaQuery.maybeSizeOf(context);
  if (size == null) {
    final view = View.maybeOf(context);
    if (view != null) size = view.physicalSize / view.devicePixelRatio;
  }
  return size == null || size.width < phoneBreakpoint;
}
