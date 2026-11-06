import 'package:flutter/widgets.dart';

import '../../core/di/core_di.dart';
import '../../core/sync/sync_engine.dart';

/// Shell actions whose flows belong to later tasks. The defaults are stubs
/// those tasks replace in [ShellActions.standard]:
/// - [newList]: "New list" and ⌘N / Ctrl+N. Task 16 (`new_list_dialog.dart`).
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
    // Task 16: open the new-list flow here.
    newList: _stub,
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

  static void _stub(BuildContext context) {}
  static Future<void> _noRetry() async {}
}

/// Layout facts for pages inside the shell.
class ShellLayout extends InheritedWidget {
  const ShellLayout({
    super.key,
    required this.isPhone,
    required this.padding,
    required super.child,
  });

  /// Phone layout (tab bar, add bar, bottom sheets): width < 720.
  final bool isPhone;

  /// Page padding: desktop canvas 32 32 48 (24 24 48 under 1100 px), phone
  /// body 4 16 24 (app.css `.canvas`, `.pbody`). Pages apply it inside
  /// their scroll view.
  final EdgeInsets padding;

  static ShellLayout of(BuildContext context) {
    final l = context.dependOnInheritedWidgetOfExactType<ShellLayout>();
    assert(l != null, 'No ShellLayout above this page');
    return l ??
        const ShellLayout(
          isPhone: false,
          padding: EdgeInsets.zero,
          child: SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(ShellLayout old) =>
      old.isPhone != isPhone || old.padding != padding;
}
