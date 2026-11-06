import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// What the sync badge shows. Not persisted.
enum SyncStatus { localOnly, synced, syncing, offline, error }

/// Global sync status: mirrors the attached engine's [SyncStatus] while
/// signed in and is [SyncStatus.localOnly] while signed out.
///
/// The cubit outlives engines: after sign-out the engine is re-created with
/// a new device id (`unregisterSync` / `registerSync`), and `registerSync`
/// calls [attach] with the new engine's status, so widgets keep one cubit.
///
/// [signedIn] comes from `SessionCubit.signedIn` (true while `Uploading` or
/// `SignedIn`); without it the cubit stays [SyncStatus.localOnly].
class SyncStatusCubit extends Cubit<SyncStatus> {
  SyncStatusCubit({
    Stream<SyncStatus>? status,
    SyncStatus initial = SyncStatus.syncing,
    Stream<bool>? signedIn,
    bool signedInNow = false,
  }) : _engine = initial,
       _signedIn = signedInNow,
       super(signedInNow ? initial : SyncStatus.localOnly) {
    if (status != null) attach(status, initial: initial);
    _authSub = signedIn?.listen((v) {
      _signedIn = v;
      emit(v ? _engine : SyncStatus.localOnly);
    });
  }

  SyncStatus _engine;
  bool _signedIn;
  StreamSubscription<SyncStatus>? _statusSub;
  StreamSubscription<bool>? _authSub;

  /// Follows [status] from now on, replacing any earlier source.
  void attach(Stream<SyncStatus> status, {required SyncStatus initial}) {
    if (isClosed) return;
    unawaited(_statusSub?.cancel());
    _engine = initial;
    if (_signedIn && !isClosed) emit(initial);
    _statusSub = status.listen((s) {
      _engine = s;
      if (_signedIn) emit(s);
    });
  }

  /// Stops following the current source (engine being torn down).
  Future<void> detach() async {
    await _statusSub?.cancel();
    _statusSub = null;
  }

  @override
  Future<void> close() async {
    await detach();
    await _authSub?.cancel();
    return super.close();
  }
}
