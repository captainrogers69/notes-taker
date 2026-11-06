import 'dart:async';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_gateway.dart';
import '../../../core/database/weave_database.dart';
import '../../../core/notifications/notification_canceller.dart';
import '../../../core/sync/bulk_uploader.dart';
import '../../../core/sync/outbox_gate.dart';
import '../../../core/sync/sync_status.dart';

sealed class SessionState extends Equatable {
  const SessionState();

  /// True while an account is attached and sync runs ([Uploading],
  /// [SignedIn]); drives the sync badge (`SyncStatusCubit`).
  bool get syncs => false;

  @override
  List<Object?> get props => [];
}

/// No account: everything stays on this device (G6).
class LocalSession extends SessionState {
  const LocalSession();
}

/// A sign-in or sign-up request is in flight, or a restored session is
/// being checked ([SessionCubit.restore]).
class SigningIn extends SessionState {
  const SigningIn();
}

/// Signed in; local data from before sign-in is being pushed. [done] counts
/// changes the server has acknowledged. A UI phase only: when the engine
/// reports offline or error it becomes [SignedIn] (the outbox persists and
/// the engine retries).
class Uploading extends SessionState {
  const Uploading(this.done, this.total);

  final int done;
  final int total;

  @override
  bool get syncs => true;

  @override
  List<Object?> get props => [done, total];
}

class SignedIn extends SessionState {
  const SignedIn(this.user);

  final AuthUser user;

  @override
  bool get syncs => true;

  @override
  List<Object?> get props => [user];
}

/// Sign out or delete account in progress (after the server call, if any).
class SigningOut extends SessionState {
  const SigningOut();
}

/// Outcome of a [SessionCubit] action.
sealed class SessionResult extends Equatable {
  const SessionResult();

  @override
  List<Object?> get props => [];
}

class SessionOk extends SessionResult {
  const SessionOk();
}

/// Refused without side effects: another action is running, or the current
/// state does not allow this one (double tap).
class SessionBusy extends SessionResult {
  const SessionBusy();
}

/// Sign-out refused: [count] changes are still unsynced and would be lost.
/// Call `signOut(discardPending: true)` to sign out anyway.
class PendingChanges extends SessionResult {
  const PendingChanges(this.count);

  final int count;

  @override
  List<Object?> get props => [count];
}

/// Sign-in refused: this device holds another account's data. Nothing
/// changed and auth was signed out again. Call `signIn(...,
/// replaceOtherAccountData: true)` to remove it and sign in.
class OtherAccountData extends SessionResult {
  const OtherAccountData();
}

class SessionFailed extends SessionResult {
  const SessionFailed(this.error);

  final AuthError error;

  @override
  List<Object?> get props => [error];
}

/// The sync operations the session drives (wired in `account_di.dart`).
class SessionSync {
  const SessionSync({
    this.start = _noop,
    this.stop = _noopAsync,
    this.register = _noopAsync,
    this.renewDevice = _noopAsync,
    this.syncNow = _noopAsync,
    this.status = _noStatus,
    this.current = _noCurrent,
  });

  /// Starts the registered engine (`startSync`).
  final void Function() start;

  /// Disposes the sync objects (`unregisterSync`).
  final Future<void> Function() stop;

  /// Registers fresh, not started sync objects for the current device id.
  final Future<void> Function() register;

  /// New device id (`renewDeviceIdentity`).
  final Future<void> Function() renewDevice;

  /// One pass of the running engine.
  final Future<void> Function() syncNow;

  /// The running engine's status (broadcast, no replay).
  final Stream<SyncStatus> Function() status;

  /// The running engine's latest status, for what [status] already emitted.
  final SyncStatus Function() current;

  static void _noop() {}
  static Future<void> _noopAsync() async {}
  static Stream<SyncStatus> _noStatus() => const Stream.empty();
  static SyncStatus _noCurrent() => SyncStatus.localOnly;
}

/// Global account session (registered in `account_di.dart`).
///
/// Data ownership: `Kv('account.user')` ([BulkUploader.ownerKey]) names the
/// account this device's data belongs to and was snapshotted for. It is set
/// in the snapshot transaction and cleared by the wipe. The [OutboxGate]
/// follows it: on exactly while an owner is recorded (set from Kv at
/// startup by `registerCore`, so edits made before [restore] resolves or
/// after a server-side sign-out are queued for that owner).
///
/// - [restore] (app start with a stored session): owner is this user →
///   [SignedIn] and sync starts, no upload. Otherwise the attach path below
///   runs (an interrupted sign-in is completed).
/// - [signIn] / [signUp] → attach: owner is another account → refused with
///   [OtherAccountData] and auth signed out again, unless
///   `replaceOtherAccountData` (then the normal wipe runs first). Otherwise:
///   owner is this user → the outbox already holds every edit (the gate was
///   on), no snapshot; no owner → outbox on → snapshot
///   ([BulkUploader.enqueueAll]). Then start sync → [Uploading] counting
///   down → [SignedIn]; straight to [SignedIn] when nothing is queued.
/// - Server-side sign-out (the auth user becomes null while signed in, not
///   during our own action, or noticed when that action ends): sync stopped,
///   [LocalSession]; the data, the outbox, the owner and the gate stay, so
///   edits keep queueing for that account.
/// - [signOut]: unsynced changes → one sync pass (bounded by
///   [pendingSyncTimeout]); still unsynced and not `discardPending` →
///   [PendingChanges], nothing changed. Then: stop sync → wipe (keeps
///   `pref.` keys) → cancel notifications → auth sign-out (failure logged,
///   ignored) → new device id → fresh sync objects → [LocalSession]. A
///   failing step is logged by type and the rest still runs, so it always
///   ends in [LocalSession] with working DI; a failed wipe is reported as
///   [SessionFailed] ([AuthError.unknown]).
/// - [deleteAccount]: the RPC first (state unchanged meanwhile; on failure
///   [SessionFailed] and nothing changes), then the same path.
///
/// One action at a time: a call while another runs, or from a state that
/// does not allow it, returns [SessionBusy] and does nothing.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required this._auth,
    required this._db,
    required this._outbox,
    required this._uploader,
    this._sync = const SessionSync(),
    this._notifications = const NoopNotificationCanceller(),
    this.pendingSyncTimeout = const Duration(seconds: 5),
    void Function(String message)? log,
  }) : _log = log ?? ((m) => developer.log(m, name: 'Session')),
       super(_auth.current == null ? const LocalSession() : const SigningIn()) {
    _authSub = _auth.user.listen(_onAuthUser);
  }

  final AuthGateway _auth;
  final WeaveDatabase _db;
  final OutboxGate _outbox;
  final BulkUploader _uploader;
  final SessionSync _sync;
  final NotificationCanceller _notifications;
  final void Function(String) _log;

  /// How long sign-out waits for one sync pass to push pending changes.
  final Duration pendingSyncTimeout;

  StreamSubscription<AuthUser?>? _authSub;
  StreamSubscription<int>? _upload;
  StreamSubscription<SyncStatus>? _uploadStatus;
  bool _busy = false;

  /// What [restore] decided at app start (null until it ran). The UI shows
  /// the "notes from another account" prompt for [OtherAccountData].
  SessionResult? startupResult;

  /// For `SyncStatusCubit`: whether sync runs, per state change.
  Stream<bool> get signedIn => stream.map((s) => s.syncs).distinct();

  bool get signedInNow => state.syncs;

  /// The account while sync runs ([Uploading], [SignedIn]), else null.
  AuthUser? get currentUser => state.syncs ? _auth.current : null;

  /// True in [LocalSession] while this device's data still belongs to an
  /// account (owner key set, so the [OutboxGate] is on and edits queue for
  /// it): after a server-side sign-out (also after a restart), or a refused
  /// sign-in onto another account's data. The sync badge then reads
  /// "Signed out · sign in again to sync" instead of local-only. Re-read on
  /// every state change: the gate only changes together with one.
  bool get accountSignedOut => state is LocalSession && _outbox.enabled;

  /// Resolves a session restored at app start (state [SigningIn]). Starts
  /// sync when it ends signed in; call once after `registerSync`. Never
  /// throws: an error ends in [LocalSession] (auth kept; the next start
  /// retries). The result is also kept in [startupResult].
  Future<SessionResult> restore() async {
    final result = await _exclusive(() async {
      if (state is! SigningIn) return const SessionOk();
      final user = _auth.current;
      if (user == null) {
        emit(const LocalSession());
        return const SessionOk();
      }
      return _attachSafely(user, replace: false, restoring: true);
    });
    return startupResult = result;
  }

  Future<SessionResult> signIn(
    String email,
    String password, {
    bool replaceOtherAccountData = false,
  }) => _enter(
    () => _auth.signIn(email, password),
    replace: replaceOtherAccountData,
  );

  /// [SessionFailed] with [AuthError.emailNotConfirmed] (and still
  /// [LocalSession]) when the project needs the email confirmed first.
  Future<SessionResult> signUp(
    String email,
    String password, {
    bool replaceOtherAccountData = false,
  }) => _enter(
    () => _auth.signUp(email, password),
    replace: replaceOtherAccountData,
  );

  Future<SessionResult> _enter(
    Future<void> Function() call, {
    required bool replace,
  }) => _exclusive(() async {
    if (state is! LocalSession) return const SessionBusy();
    emit(const SigningIn());
    try {
      await call();
    } on Object catch (e) {
      final code = e is AuthFailure ? e.code : AuthError.unknown;
      _log('auth failed: ${code.name} (${e.runtimeType})');
      emit(const LocalSession());
      return SessionFailed(code);
    }
    final user = _auth.current;
    if (user == null) {
      _log('auth returned no user');
      emit(const LocalSession());
      return const SessionFailed(AuthError.unknown);
    }
    return _attachSafely(user, replace: replace, restoring: false);
  });

  /// [_attach] with any unexpected error turned into [LocalSession] and
  /// [AuthError.unknown] (type logged only). After a fresh sign-in auth is
  /// signed out again; a restored session is kept for the next start.
  Future<SessionResult> _attachSafely(
    AuthUser user, {
    required bool replace,
    required bool restoring,
  }) async {
    try {
      final owner = await _uploader.owner();
      if (restoring && owner == user.id) {
        _sync.start();
        emit(SignedIn(user));
        return const SessionOk();
      }
      if (restoring) _log('restored session needs attach (${user.id})');
      return await _attach(user, owner, replace: replace);
    } on Object catch (e) {
      _log('attach failed: ${e.runtimeType}');
      await _stopWatching();
      await _step('stop sync', _sync.stop);
      await _step('register sync', _sync.register);
      if (!restoring) await _signOutRemote();
      await _gateFromOwner();
      emit(const LocalSession());
      return const SessionFailed(AuthError.unknown);
    }
  }

  /// The gate follows the owner key (on while an owner is recorded).
  Future<void> _gateFromOwner() async {
    try {
      _outbox.enabled = await _uploader.owner() != null;
    } on Object catch (e) {
      _log('owner read failed: ${e.runtimeType}');
      _outbox.enabled = false;
    }
  }

  /// Binds this device's data to [user] (state [SigningIn]).
  Future<SessionResult> _attach(
    AuthUser user,
    String? owner, {
    required bool replace,
  }) async {
    if (owner != null && owner != user.id) {
      if (!replace) {
        _log('refused: data of another account (${user.id})');
        await _signOutRemote();
        emit(const LocalSession());
        return const OtherAccountData();
      }
      _log('replacing data of another account (${user.id})');
      await _wipeLocal(signOutAuth: false);
      // Never snapshot another account's rows into this one: the wipe can
      // fail (logged, swallowed), so check the key is really gone.
      owner = await _uploader.owner();
      if (owner != null) {
        _log('replace failed: data of another account still here');
        await _signOutRemote();
        emit(const LocalSession());
        return const SessionFailed(AuthError.unknown);
      }
    }
    if (owner == user.id) {
      // The gate was on since the key was written: the outbox holds every
      // edit (incl. purge markers), so no snapshot is needed.
      _outbox.enabled = true;
      _log('signed in ${user.id} again');
    } else {
      // On before the snapshot: an edit racing it is either in the snapshot
      // or queued after it, never lost.
      _outbox.enabled = true;
      final written = await _uploader.enqueueAll(user.id);
      _log('signed in ${user.id}, $written snapshotted');
    }
    _sync.start();
    final total = await _outboxCount();
    if (total == 0) {
      emit(SignedIn(user));
      return const SessionOk();
    }
    emit(Uploading(0, total));
    _watchUpload(user, total);
    return const SessionOk();
  }

  void _watchUpload(AuthUser user, int initialTotal) {
    var total = initialTotal;
    var last = initialTotal;
    _uploadStatus = _sync.status().listen((s) {
      if (s == SyncStatus.offline || s == SyncStatus.error) {
        _log('upload continues in background (${s.name})');
        _finishUpload(user);
      }
    });
    // The stream does not replay: a pass that already went offline before
    // the subscription is only visible here.
    final now = _sync.current();
    if (now == SyncStatus.offline || now == SyncStatus.error) {
      _log('upload continues in background (${now.name})');
      _finishUpload(user);
      return;
    }
    _upload = _outboxCountQuery().watchSingle().listen((left) {
      if (isClosed || state is! Uploading) return;
      if (left == 0) {
        _log('upload done ($total)');
        _finishUpload(user);
        return;
      }
      // Edits made while uploading join the queue: done never goes back.
      if (left > last) total += left - last;
      last = left;
      emit(Uploading(total - left, total));
    });
  }

  void _finishUpload(AuthUser user) {
    unawaited(_stopWatching());
    if (!isClosed && state is Uploading) emit(SignedIn(user));
  }

  Future<void> _stopWatching() async {
    final upload = _upload;
    final status = _uploadStatus;
    _upload = null;
    _uploadStatus = null;
    await upload?.cancel();
    await status?.cancel();
  }

  Selectable<int> _outboxCountQuery() {
    final count = _db.outbox.changeId.count();
    return (_db.selectOnly(
      _db.outbox,
    )..addColumns([count])).map((r) => r.read(count) ?? 0);
  }

  Future<int> _outboxCount() => _outboxCountQuery().getSingle();

  /// Signs out and removes this account's data from the device (device
  /// prefs stay). See the class doc for [PendingChanges].
  Future<SessionResult> signOut({bool discardPending = false}) => _exclusive(
    () async {
      if (!state.syncs) return const SessionBusy();
      var pending = await _outboxCount();
      if (pending > 0) {
        try {
          await _sync.syncNow().timeout(pendingSyncTimeout);
        } on Object catch (e) {
          _log('sync before sign-out failed: ${e.runtimeType}');
        }
        pending = await _outboxCount();
        if (pending > 0 && !discardPending) {
          _log('sign-out held: $pending pending');
          return PendingChanges(pending);
        }
      }
      emit(const SigningOut());
      final wiped = await _wipeLocal(signOutAuth: true);
      _log('signed out');
      emit(const LocalSession());
      return wiped ? const SessionOk() : const SessionFailed(AuthError.unknown);
    },
  );

  /// Deletes the account on the server (needs the network), then wipes like
  /// [signOut]. On failure: [SessionFailed], nothing changes.
  Future<SessionResult> deleteAccount() => _exclusive(() async {
    if (!state.syncs) return const SessionBusy();
    try {
      await _auth.deleteAccount();
    } on Object catch (e) {
      final code = e is AuthFailure ? e.code : AuthError.unknown;
      _log('delete account failed: ${code.name}');
      return SessionFailed(code);
    }
    emit(const SigningOut());
    final wiped = await _wipeLocal(signOutAuth: true);
    _log('account deleted');
    emit(const LocalSession());
    return wiped ? const SessionOk() : const SessionFailed(AuthError.unknown);
  });

  /// The wipe path. Every step runs even if an earlier one fails, so the
  /// app always ends with fresh sync objects for a new device id.
  ///
  /// The gate stays as it was until the wipe step, so an edit made while
  /// sync stops is still queued for the owner if the wipe then fails.
  /// Returns false when the wipe failed (the owner's data is still here).
  Future<bool> _wipeLocal({required bool signOutAuth}) async {
    await _stopWatching();
    await _step('stop sync', _sync.stop);
    final wiped = await _step('wipe', _db.wipe);
    // Off after a wipe; on if it failed and the owner's data is still here.
    await _gateFromOwner();
    await _step('cancel notifications', _notifications.cancelAll);
    if (signOutAuth) await _signOutRemote();
    await _step('renew device', _sync.renewDevice);
    await _step('register sync', _sync.register);
    return wiped;
  }

  /// Runs one step; logs a failure by type and returns false.
  Future<bool> _step(String name, Future<void> Function() run) async {
    try {
      await run();
      return true;
    } on Object catch (e) {
      _log('$name failed: ${e.runtimeType}');
      return false;
    }
  }

  /// Local sign-out wins: a failure (offline) is logged by type only.
  Future<void> _signOutRemote() => _step('auth sign-out', _auth.signOut);

  /// Server-side sign-out (expired or revoked refresh token). A null user
  /// during a busy action is picked up when it ends ([_exclusive]).
  void _onAuthUser(AuthUser? user) {
    if (user != null || _busy || isClosed || !state.syncs) return;
    unawaited(_serverSignOut());
  }

  /// Stops syncing; keeps the data, the outbox, the owner and the gate.
  Future<SessionResult> _serverSignOut() => _exclusive(() async {
    if (!state.syncs || _auth.current != null) return const SessionBusy();
    _log('signed out by the server');
    await _stopWatching();
    await _step('stop sync', _sync.stop);
    await _step('register sync', _sync.register);
    emit(const LocalSession());
    return const SessionOk();
  });

  Future<SessionResult> _exclusive(
    Future<SessionResult> Function() body,
  ) async {
    if (_busy || isClosed) return const SessionBusy();
    _busy = true;
    try {
      return await body();
    } finally {
      _busy = false;
      if (!isClosed && state.syncs && _auth.current == null) {
        unawaited(_serverSignOut());
      }
    }
  }

  /// Actions can finish after [close] (app shutdown); drop their emits.
  @override
  void emit(SessionState state) {
    if (!isClosed) super.emit(state);
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    await _stopWatching();
    return super.close();
  }
}
