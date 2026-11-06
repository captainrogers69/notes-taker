import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/core_di.dart';
import '../../core/domain/note_color_id.dart';
import '../../core/sync/sync_engine.dart';
import '../../features/lists/domain/repositories/lists_repository.dart';

/// Shell actions; the flows of later tasks are stubs in
/// [ShellActions.standard]:
/// - [signIn]: the local-mode user row and "Signed out · sign in again to
///   sync". Task 20 (`sign_in_dialog.dart`).
class ShellActions {
  const ShellActions({
    this.newList = _stub,
    this.signIn = _stub,
    this.retrySync = _noRetry,
  });

  /// The app's actions, from DI.
  factory ShellActions.standard() => ShellActions(
    newList: _newList,
    // Task 20: open the sign-in dialog here.
    signIn: _stub,
    retrySync: () async {
      if (sl.isRegistered<SyncEngine>()) await sl<SyncEngine>().syncNow();
    },
  );

  final void Function(BuildContext context) newList;
  final void Function(BuildContext context) signIn;

  /// "Sync error · retrying": one sync pass now.
  final Future<void> Function() retrySync;

  /// 03 `newlist`: no dialog. Makes "Untitled list" in the next palette
  /// colour and opens it with the name selected.
  static Future<void> _newList(BuildContext context) async {
    final router = GoRouter.of(context);
    final repo = sl<ListsRepository>();
    final count = (await repo.watchActive().first).length;
    final color = NoteColor.values[count % NoteColor.values.length];
    final id = await repo.create('Untitled list', color);
    router.go('/list/${Uri.encodeComponent(id)}?new=1');
  }

  static void _stub(BuildContext context) {}
  static Future<void> _noRetry() async {}
}
