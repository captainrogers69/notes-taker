import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../core/di/core_di.dart';
import '../core/sync/sync_status.dart';
import '../core/theme/weave_theme.dart';
import '../features/account/presentation/session_cubit.dart';
import 'router.dart';

/// The app: design-02 theme (light and dark, following the system until
/// Settings picks one, Task 20), the global [SessionCubit] and
/// [SyncStatusCubit], and the router.
class WeaveApp extends HookWidget {
  const WeaveApp({super.key, this.router});

  /// Tests pass their own; otherwise [buildRouter].
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    final own = router == null;
    final r = useMemoized(() => router ?? buildRouter(), [router]);
    useEffect(() => own ? r.dispose : null, [r]);
    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionCubit>.value(value: sl<SessionCubit>()),
        BlocProvider<SyncStatusCubit>.value(value: sl<SyncStatusCubit>()),
      ],
      child: MaterialApp.router(
        title: 'Weave',
        debugShowCheckedModeBanner: false,
        theme: weaveTheme(Brightness.light),
        darkTheme: weaveTheme(Brightness.dark),
        routerConfig: r,
      ),
    );
  }
}
