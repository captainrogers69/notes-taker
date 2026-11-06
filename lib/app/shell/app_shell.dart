import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/core_di.dart';
import '../../core/helpers/platform_labels.dart';
import '../../core/widgets/undo_toast.dart';
import '../router.dart';
import 'desktop_shell.dart';
import 'phone_shell.dart';
import '../../core/widgets/shell_layout.dart';
import 'shell_actions.dart';
import 'shell_cubit.dart';

/// Below this width the phone layout is used (design playbook §9 Layouts).
const phoneBreakpoint = 720.0;

/// Below this width the sidebar narrows to 224 (app.css tablet band).
const narrowBreakpoint = 1100.0;

/// Where the shell is: the route and, for [AppRoute.list], the list id.
class ShellLocation {
  const ShellLocation(this.route, [this.listId]);

  factory ShellLocation.of(Uri uri) {
    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.isEmpty) return const ShellLocation(AppRoute.upNext);
    if (seg.first == 'list' && seg.length > 1) {
      return ShellLocation(AppRoute.list, seg[1]);
    }
    for (final r in AppRoute.values) {
      if (r.path == '/${seg.first}') return ShellLocation(r);
    }
    return const ShellLocation(AppRoute.upNext);
  }

  final AppRoute route;
  final String? listId;
}

/// The app frame around every route: picks [DesktopShell] (≥ 720) or
/// [PhoneShell], owns the sidebar / tab-bar data ([ShellCubit]), the Undo
/// toast, the search field focus and the keyboard shortcuts
/// (⌘K / Ctrl+K search, ⌘N / Ctrl+N new list).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.actions,
    required this.child,
  });

  final GoRouterState location;
  final ShellActions actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShellCubit>(
      create: (_) => sl<ShellCubit>(),
      child: _ShellFrame(
        location: ShellLocation.of(location.uri),
        actions: actions,
        child: child,
      ),
    );
  }
}

class _ShellFrame extends HookWidget {
  const _ShellFrame({
    required this.location,
    required this.actions,
    required this.child,
  });

  final ShellLocation location;
  final ShellActions actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < phoneBreakpoint;
    final toast = useMemoized(UndoToastController.new);
    useEffect(() => toast.dispose, [toast]);
    final searchFocus = useFocusNode(debugLabel: 'search');
    final search = useTextEditingController();
    final cubit = context.read<ShellCubit>();

    // Counts that depend on the time are re-read on resume (and every
    // minute by the cubit).
    useOnAppLifecycleStateChange((_, now) {
      if (now == AppLifecycleState.resumed) cubit.refresh();
    });

    // The Lists tab is phone-only: on a wide window the sidebar lists them.
    // The router redirects on navigation; this covers a window widened
    // while on /lists.
    final onLists = location.route == AppRoute.lists;
    useEffect(() {
      if (!phone && onLists) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.goNamed(AppRoute.upNext.name);
        });
      }
      return null;
    }, [phone, onLists]);

    void focusSearch() {
      if (phone) {
        context.goNamed(AppRoute.search.name);
      } else {
        searchFocus.requestFocus();
      }
    }

    final cmd = usesCommandKey();
    final padding = phone
        ? const EdgeInsets.fromLTRB(16, 4, 16, 24)
        : width < narrowBreakpoint
        ? const EdgeInsets.fromLTRB(24, 24, 24, 48)
        : const EdgeInsets.fromLTRB(32, 32, 32, 48);

    final page = ShellLayout(isPhone: phone, padding: padding, child: child);
    return UndoToastScope(
      controller: toast,
      child: CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.keyK, meta: cmd, control: !cmd):
              focusSearch,
          SingleActivator(
            LogicalKeyboardKey.keyN,
            meta: cmd,
            control: !cmd,
          ): () =>
              actions.newList(context),
        },
        // A scope, not a plain Focus: when a field gives up focus it falls
        // back to this scope (below the bindings), so the shortcuts keep
        // working.
        child: FocusScope(
          autofocus: true,
          child: phone
              ? PhoneShell(
                  location: location,
                  toast: toast,
                  upNextCount: context.select<ShellCubit, int>(
                    (c) => c.state.upNextCount,
                  ),
                  child: page,
                )
              : DesktopShell(
                  location: location,
                  actions: actions,
                  toast: toast,
                  searchFocus: searchFocus,
                  search: search,
                  narrow: width < narrowBreakpoint,
                  child: page,
                ),
        ),
      ),
    );
  }
}
