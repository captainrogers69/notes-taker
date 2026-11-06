import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:weave/core/auth/auth_gateway.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/di/account_di.dart';
import 'package:weave/core/di/core_di.dart';
import 'package:weave/core/di/sync_di.dart';
import 'package:weave/core/notifications/notification_canceller.dart';
import 'package:weave/core/sync/bulk_uploader.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/device_info.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/hlc.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/core/sync/in_memory_sync_transport.dart';
import 'package:weave/core/sync/outbox_gate.dart';
import 'package:weave/core/sync/pulled_change.dart';
import 'package:weave/core/sync/remote_change.dart';
import 'package:weave/core/sync/sync_engine.dart';
import 'package:weave/core/sync/sync_status.dart';
import 'package:weave/core/sync/sync_transport.dart';
import 'package:weave/core/theme/note_color.dart';
import 'package:weave/features/account/presentation/session_cubit.dart';
import 'package:weave/features/lists/domain/repositories/lists_repository.dart';

const _user = AuthUser(id: 'u1', email: 'a@example.com');

/// Shared call log, to check the order of side effects.
final _events = <String>[];

class _FakeAuth implements AuthGateway {
  final _users = StreamController<AuthUser?>.broadcast();
  AuthUser? signedIn;
  AuthError? signInError;
  AuthError? deleteError;
  bool signUpNeedsConfirm = false;
  bool signOutOffline = false;
  Completer<void>? signInGate;
  Completer<void>? deleteGate;
  int signInCalls = 0;

  /// The server ends the session (expired / revoked refresh token).
  void expire() {
    signedIn = null;
    _users.add(null);
  }

  @override
  Stream<AuthUser?> get user => _users.stream;

  @override
  AuthUser? get current => signedIn;

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    _events.add('auth.signIn');
    final gate = signInGate;
    if (gate != null) await gate.future;
    final error = signInError;
    if (error != null) throw AuthFailure(error);
    signedIn = _user;
  }

  @override
  Future<void> signUp(String email, String password) async {
    _events.add('auth.signUp');
    if (signUpNeedsConfirm) {
      throw const AuthFailure(AuthError.emailNotConfirmed);
    }
    signedIn = _user;
  }

  @override
  Future<void> signOut() async {
    _events.add('auth.signOut');
    signedIn = null;
    if (signOutOffline) throw const AuthFailure(AuthError.network);
  }

  @override
  Future<void> deleteAccount() async {
    _events.add('auth.deleteAccount');
    final gate = deleteGate;
    if (gate != null) await gate.future;
    final error = deleteError;
    if (error != null) throw AuthFailure(error);
  }
}

class _FakeNotifications implements NotificationCanceller {
  @override
  Future<void> cancelAll() async => _events.add('notifications.cancelAll');
}

/// Records `db.wipe` and can fail it.
class _Db extends WeaveDatabase {
  _Db() : super(NativeDatabase.memory());

  bool failWipe = false;

  @override
  Future<void> wipe() async {
    _events.add('db.wipe');
    if (failWipe) throw StateError('disk');
    await super.wipe();
  }
}

/// Records every call to the transport.
class _SpyTransport implements SyncTransport {
  _SpyTransport(this.inner);

  final InMemorySyncTransport inner;
  final calls = <String>[];

  @override
  Future<void> push(List<RemoteChange> changes) {
    calls.add('push');
    return inner.push(changes);
  }

  @override
  Future<PulledPage> pull({required int afterSeq, int limit = 500}) {
    calls.add('pull');
    return inner.pull(afterSeq: afterSeq, limit: limit);
  }

  @override
  Stream<void> hints() {
    calls.add('hints');
    return inner.hints();
  }

  @override
  Future<void> touchDevice(String id, String name, String platform) {
    calls.add('touchDevice');
    return inner.touchDevice(id, name, platform);
  }

  @override
  Future<List<DeviceInfo>> devices() {
    calls.add('devices');
    return inner.devices();
  }
}

Future<void> _kv(WeaveDatabase db, String key, String value) => db
    .into(db.kv)
    .insertOnConflictUpdate(KvCompanion.insert(key: key, value: value));

/// The app's DI (core, account, sync) on an in-memory DB and server.
class _App {
  _App([InMemorySyncTransport Function(String)? server])
    : server = server ?? InMemorySyncTransport.newServer();

  final sl = GetIt.asNewInstance();
  final InMemorySyncTransport Function(String) server;
  final transports = <String, _SpyTransport>{};
  final auth = _FakeAuth();
  final db = _Db();

  /// [seed] fills the database before the app starts (as a previous run).
  Future<void> start({
    AuthUser? restored,
    Future<void> Function(WeaveDatabase db, ChangeWriter local)? seed,
  }) async {
    if (seed != null) {
      await seed(db, ChangeWriter(db, HlcClock('dev-old')));
    }
    auth.signedIn = restored;
    await registerCoreWith(sl, db);
    registerAccount(
      sl,
      auth: auth,
      registerSyncFor: _syncFor,
      notifications: _FakeNotifications(),
      log: (_) {},
    );
    await _syncFor(sl);
    // Created now so it follows the session from the start (as the badge).
    sl<SyncStatusCubit>();
  }

  Future<void> _syncFor(GetIt sl) {
    final id = sl<DeviceId>().value;
    final transport = transports[id] = _SpyTransport(server(id));
    final session = sl<SessionCubit>();
    return registerSync(
      sl,
      transport: transport,
      deviceName: 'Mac',
      platform: 'macos',
      connectivity: const Stream<bool>.empty(),
      checkOnline: () async => true,
      signedIn: session.signedIn,
      signedInNow: session.signedInNow,
    );
  }

  SessionCubit get session => sl<SessionCubit>();
  ChangeWriter get writer => sl<ChangeWriter>();
  String get deviceId => sl<DeviceId>().value;
  _SpyTransport get transport => transports[deviceId]!;

  Future<int> outboxCount() async => (await db.select(db.outbox).get()).length;

  Future<Set<String>> listIds() async =>
      (await db.select(db.lists).get()).map((r) => r.id).toSet();

  Future<Set<String>> serverIds() async => {
    for (final r in (await server('probe').pull(afterSeq: 0)).rows)
      r.change.entityId,
  };

  Future<Map<String, String>> kv() async => {
    for (final r in await db.select(db.kv).get()) r.key: r.value,
  };

  Future<void> addLocalData() async {
    await writer.write(EntityType.list, 'l1', {'name': 'A', 'sortKey': 'a0'});
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'x'});
    await writer.write(EntityType.item, 'i2', {'listId': 'l1', 'text': 'y'});
  }

  Future<void> signedInAndSynced() async {
    await addLocalData();
    expect(await session.signIn('a@example.com', 'pw'), const SessionOk());
    await untilSignedIn();
    await sl<SyncEngine>().syncNow();
  }

  Future<void> untilSignedIn() async {
    if (session.state is SignedIn) return;
    await session.stream
        .firstWhere((s) => s is SignedIn)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> dispose() async {
    await unregisterSync(sl);
    await sl<SyncStatusCubit>().close();
    await session.close();
    await db.close();
  }
}

void main() {
  setUp(_events.clear);

  group('with the app DI', () {
    late _App app;

    setUp(() async {
      app = _App();
      await app.start();
    });
    tearDown(() => app.dispose());

    test('local mode never touches transport and writes no outbox', () async {
      await app.addLocalData();
      await pumpEventQueue();
      expect(app.session.state, const LocalSession());
      expect(await app.outboxCount(), 0);
      expect(app.transport.calls, isEmpty);
      expect(app.sl<SyncStatusCubit>().state, SyncStatus.localOnly);
    });

    test('signIn with local data emits Uploading then SignedIn', () async {
      await app.addLocalData();
      final states = <SessionState>[];
      final sub = app.session.stream.listen(states.add);

      final result = await app.session.signIn('a@example.com', 'pw');
      await app.untilSignedIn();
      await sub.cancel();

      expect(result, const SessionOk());
      expect(states.first, const SigningIn());
      expect(states[1], const Uploading(0, 3));
      expect(states.last, const SignedIn(_user));
      expect(await app.outboxCount(), 0);
      expect(await app.serverIds(), {'l1', 'i1', 'i2'});
      expect((await app.kv())[BulkUploader.ownerKey], 'u1');
      expect(app.sl<SyncStatusCubit>().state, isNot(SyncStatus.localOnly));
      expect(app.sl<OutboxGate>().enabled, isTrue);
    });

    test('signIn without local data goes straight to SignedIn', () async {
      final states = <SessionState>[];
      final sub = app.session.stream.listen(states.add);
      await app.session.signIn('a@example.com', 'pw');
      await pumpEventQueue();
      await sub.cancel();
      expect(states, [const SigningIn(), const SignedIn(_user)]);
      expect(app.transport.calls, contains('pull'), reason: 'sync started');
      expect((await app.kv())[BulkUploader.ownerKey], 'u1');
    });

    test('wrong password surfaces AuthError.wrongPassword and stays '
        'LocalSession', () async {
      app.auth.signInError = AuthError.wrongPassword;
      await app.addLocalData();

      final result = await app.session.signIn('a@example.com', 'bad');
      await pumpEventQueue();

      expect(result, const SessionFailed(AuthError.wrongPassword));
      expect(app.session.state, const LocalSession());
      expect(app.sl<OutboxGate>().enabled, isFalse);
      expect(await app.outboxCount(), 0);
      expect(app.transport.calls, isEmpty);
      expect((await app.kv())[BulkUploader.ownerKey], isNull);
    });

    test('signUp needing email confirmation stays LocalSession', () async {
      app.auth.signUpNeedsConfirm = true;
      final result = await app.session.signUp('a@example.com', 'pw');
      expect(result, const SessionFailed(AuthError.emailNotConfirmed));
      expect(app.session.state, const LocalSession());
      expect(app.transport.calls, isEmpty);
    });

    test(
      'sign out wipes lists, items, outbox and cursor; keeps prefs',
      () async {
        await app.signedInAndSynced();
        await _kv(app.db, 'sync.cursor', '7');
        await _kv(app.db, 'pref.theme', 'dark');
        await _kv(app.db, 'pref.captureListId', 'l1');

        expect(await app.session.signOut(), const SessionOk());

        expect(app.session.state, const LocalSession());
        expect(await app.db.select(app.db.lists).get(), isEmpty);
        expect(await app.db.select(app.db.items).get(), isEmpty);
        expect(await app.outboxCount(), 0);
        expect((await app.kv()).keys.toSet(), {
          'device.id',
          'hlc.last',
          'pref.theme',
        });
        expect(_events, [
          'auth.signIn',
          'db.wipe',
          'notifications.cancelAll',
          'auth.signOut',
        ]);
      },
    );

    test('sign out: new device id on the same clock and writer, old sync '
        'objects disposed', () async {
      await app.signedInAndSynced();
      final oldId = app.deviceId;
      final oldLast = app.sl<HlcClock>().last;
      final clock = app.sl<HlcClock>();
      final writer = app.writer;
      final oldEngine = app.sl<SyncEngine>();
      final repo = app.sl<ListsRepository>();
      final statusCubit = app.sl<SyncStatusCubit>();

      await app.session.signOut();

      final newId = app.deviceId;
      expect(newId, isNot(oldId));
      final kv = await app.kv();
      expect(kv['device.id'], newId);
      expect(identical(app.sl<HlcClock>(), clock), isTrue);
      expect(identical(app.writer, writer), isTrue);
      expect(identical(app.sl<ListsRepository>(), repo), isTrue);
      expect(clock.node, newId);
      expect(Hlc.parse(kv['hlc.last']!).node, newId);

      expect(() => oldEngine.start(), throwsStateError, reason: 'disposed');
      expect(identical(app.sl<SyncEngine>(), oldEngine), isFalse);
      expect(app.transports.keys, [oldId, newId]);
      expect(app.transports[newId]!.calls, isEmpty, reason: 'not started');
      expect(identical(app.sl<SyncStatusCubit>(), statusCubit), isTrue);
      expect(statusCubit.state, SyncStatus.localOnly);
      expect(app.sl<OutboxGate>().enabled, isFalse);

      // A repository obtained before sign-out writes with the new node,
      // after every old stamp, and queues nothing.
      final id = await repo.create('C', NoteColor.values.first);
      expect(await app.outboxCount(), 0);
      final row = await (app.db.select(
        app.db.lists,
      )..where((t) => t.id.equals(id))).getSingle();
      final stamp = Hlc.parse(
        (RegExp(r'"name":"([^"]+)"').firstMatch(row.fieldHlcs))!.group(1)!,
      );
      expect(stamp.node, newId);
      expect(stamp.compareTo(oldLast), greaterThan(0));
    });

    test('sign out offline still finishes locally', () async {
      await app.signedInAndSynced();
      app.auth.signOutOffline = true;
      await app.session.signOut();
      expect(app.session.state, const LocalSession());
      expect(await app.db.select(app.db.lists).get(), isEmpty);
    });

    test('sign out with unsynced changes asks first', () async {
      await app.signedInAndSynced();
      app.transport.inner.offline = true;
      await app.writer.write(EntityType.list, 'l2', {'name': 'B'});

      final result = await app.session.signOut();

      expect(result, const PendingChanges(1));
      expect(app.session.state, const SignedIn(_user));
      expect(await app.listIds(), {'l1', 'l2'});
      expect(_events, ['auth.signIn']);

      expect(
        await app.session.signOut(discardPending: true),
        const SessionOk(),
      );
      expect(app.session.state, const LocalSession());
      expect(await app.listIds(), isEmpty);
    });

    test('sign out pushes pending changes first when online', () async {
      await app.signedInAndSynced();
      await app.writer.write(EntityType.list, 'l2', {'name': 'B'});
      expect(await app.session.signOut(), const SessionOk());
      expect(await app.serverIds(), contains('l2'));
    });

    test('next sign-in after sign-out syncs with the new device id', () async {
      await app.signedInAndSynced();
      await app.session.signOut();
      final newId = app.deviceId;

      await app.session.signIn('a@example.com', 'pw');
      await app.untilSignedIn();
      await app.sl<SyncEngine>().syncNow();
      expect(app.transports[newId]!.calls, contains('pull'));
      expect(await app.listIds(), {'l1'});
    });

    test('deleteAccount calls gateway and wipes', () async {
      await app.signedInAndSynced();
      final oldId = app.deviceId;

      expect(await app.session.deleteAccount(), const SessionOk());

      expect(app.session.state, const LocalSession());
      expect(_events, [
        'auth.signIn',
        'auth.deleteAccount',
        'db.wipe',
        'notifications.cancelAll',
        'auth.signOut',
      ]);
      expect(await app.db.select(app.db.lists).get(), isEmpty);
      expect(await app.db.select(app.db.items).get(), isEmpty);
      expect(app.deviceId, isNot(oldId));
    });

    test('deleteAccount failure changes nothing locally', () async {
      await app.signedInAndSynced();
      app.auth.deleteError = AuthError.network;
      final engine = app.sl<SyncEngine>();
      final id = app.deviceId;
      final states = <SessionState>[];
      final sub = app.session.stream.listen(states.add);

      final result = await app.session.deleteAccount();
      await sub.cancel();

      expect(result, const SessionFailed(AuthError.network));
      expect(states, isEmpty, reason: 'no SigningOut before the RPC');
      expect(app.session.state, const SignedIn(_user));
      expect(await app.db.select(app.db.lists).get(), hasLength(1));
      expect(await app.db.select(app.db.items).get(), hasLength(2));
      expect(identical(app.sl<SyncEngine>(), engine), isTrue);
      expect(app.deviceId, id);
      expect(app.sl<OutboxGate>().enabled, isTrue);
      expect(_events, isNot(contains('db.wipe')));
    });

    test('double tap: second signIn and signOut while signing in are '
        'refused as busy', () async {
      final gate = app.auth.signInGate = Completer<void>();
      final first = app.session.signIn('a@example.com', 'pw');
      expect(app.session.state, const SigningIn());

      expect(
        await app.session.signIn('a@example.com', 'pw'),
        const SessionBusy(),
      );
      expect(
        await app.session.signUp('a@example.com', 'pw'),
        const SessionBusy(),
      );
      expect(await app.session.signOut(), const SessionBusy());
      expect(await app.session.deleteAccount(), const SessionBusy());
      expect(app.session.state, const SigningIn());

      gate.complete();
      expect(await first, const SessionOk());
      expect(app.session.state, const SignedIn(_user));
      expect(app.auth.signInCalls, 1);
      expect(_events, ['auth.signIn']);
    });

    test(
      'accountSignedOut: only after a server-side sign-out (badge)',
      () async {
        expect(app.session.accountSignedOut, isFalse, reason: 'local mode');
        await app.signedInAndSynced();
        expect(app.session.accountSignedOut, isFalse, reason: 'signed in');
        expect(app.session.currentUser, _user);

        app.auth.expire();
        await pumpEventQueue();
        expect(app.session.state, const LocalSession());
        expect(app.session.accountSignedOut, isTrue, reason: 'owner kept');
        expect(app.session.currentUser, isNull);

        await app.session.signIn('a@example.com', 'pw');
        await app.untilSignedIn();
        await app.session.signOut();
        expect(app.session.accountSignedOut, isFalse, reason: 'wiped');
      },
    );

    test('server-side sign-out keeps data and outbox, stops sync', () async {
      await app.signedInAndSynced();
      app.transport.inner.offline = true;
      await app.writer.write(EntityType.list, 'l2', {'name': 'B'});
      final engine = app.sl<SyncEngine>();
      final id = app.deviceId;

      app.auth.expire();
      await pumpEventQueue();

      expect(app.session.state, const LocalSession());
      expect(await app.listIds(), {'l1', 'l2'});
      expect(await app.outboxCount(), 1);
      expect((await app.kv())[BulkUploader.ownerKey], 'u1');
      expect(app.sl<OutboxGate>().enabled, isTrue, reason: 'follows owner');
      expect(() => engine.start(), throwsStateError, reason: 'disposed');
      expect(app.deviceId, id, reason: 'same device');
      expect(app.sl<SyncStatusCubit>().state, SyncStatus.localOnly);
      expect(_events, isNot(contains('db.wipe')));
      await app.writer.write(EntityType.list, 'l3', {'name': 'C'});
      expect(await app.outboxCount(), 2, reason: 'edits still queue');
    });

    test(
      'delete forever after a server-side sign-out reaches the server',
      () async {
        await app.signedInAndSynced();
        app.auth.expire();
        await pumpEventQueue();
        expect(app.session.state, const LocalSession());

        await app.sl<ListsRepository>().deleteForever('l1');
        expect(await app.listIds(), isEmpty);

        await app.session.signIn('a@example.com', 'pw');
        await app.untilSignedIn();
        await app.sl<SyncEngine>().syncNow();

        final other = _App(app.server);
        await other.start();
        addTearDown(other.dispose);
        await other.session.signIn('a@example.com', 'pw');
        await other.untilSignedIn();
        await other.sl<SyncEngine>().syncNow();
        expect(await other.listIds(), isEmpty, reason: 'purge was sent');
      },
    );

    test(
      'a null auth user during a busy action signs out afterwards',
      () async {
        await app.signedInAndSynced();
        app.auth
          ..deleteError = AuthError.network
          ..deleteGate = Completer<void>();
        final delete = app.session.deleteAccount();
        await pumpEventQueue();
        app.auth.expire(); // dropped by the listener: busy
        app.auth.deleteGate!.complete();

        expect(await delete, const SessionFailed(AuthError.network));
        await pumpEventQueue();
        expect(app.session.state, const LocalSession());
        expect(await app.listIds(), {'l1'}, reason: 'no wipe');
      },
    );

    test('same-user sign-in keeps the outbox, no snapshot', () async {
      await app.signedInAndSynced();
      app.transport.inner.offline = true;
      // Unpushed purge marker (delete forever) while signed in.
      await app.writer.write(EntityType.list, 'gone', {'deletedAt': 0});
      app.auth.expire();
      await pumpEventQueue();
      // Edit made while signed out queues for the owner.
      await app.writer.write(EntityType.list, 'l3', {'name': 'C'});
      expect(await app.outboxCount(), 2);

      expect(
        await app.session.signIn('a@example.com', 'pw'),
        const SessionOk(),
      );
      await app.untilSignedIn();
      await app.sl<SyncEngine>().syncNow();

      expect(await app.serverIds(), containsAll(['gone', 'l3']));
      expect(await app.outboxCount(), 0);
    });

    test(
      'sign-in into an account with another device data merges both',
      () async {
        final other = _App(app.server);
        await other.start();
        addTearDown(other.dispose);
        await other.writer.write(EntityType.list, 'r1', {'name': 'Remote'});
        await other.session.signIn('a@example.com', 'pw');
        await other.untilSignedIn();
        await other.sl<SyncEngine>().syncNow();

        await app.addLocalData();
        await app.session.signIn('a@example.com', 'pw');
        await app.untilSignedIn();
        await app.sl<SyncEngine>().syncNow();
        await other.sl<SyncEngine>().syncNow();

        expect(await app.listIds(), {'l1', 'r1'});
        expect(await other.listIds(), {'l1', 'r1'});
      },
    );
  });

  group('restored session', () {
    Future<_App> restored({String? owner, bool withData = true}) async {
      final app = _App();
      await app.start(
        restored: _user,
        seed: (db, local) async {
          if (withData) {
            await local.write(EntityType.list, 'l1', {'name': 'A'});
            await db.delete(db.outbox).go(); // as written in local mode
          }
          if (owner != null) await _kv(db, BulkUploader.ownerKey, owner);
        },
      );
      addTearDown(app.dispose);
      return app;
    }

    test('owned by the user → SignedIn with no upload', () async {
      final app = await restored(owner: 'u1');
      expect(app.session.state, const SigningIn());

      expect(await app.session.restore(), const SessionOk());

      expect(app.session.state, const SignedIn(_user));
      expect(app.sl<OutboxGate>().enabled, isTrue);
      await app.sl<SyncEngine>().syncNow();
      expect(app.transport.calls, contains('pull'), reason: 'sync started');
      expect(await app.serverIds(), isEmpty, reason: 'no snapshot');
    });

    test('an edit before restore resolves is queued', () async {
      final app = await restored(owner: 'u1');
      expect(app.sl<OutboxGate>().enabled, isTrue, reason: 'set at startup');
      await app.writer.write(EntityType.list, 'early', {'name': 'E'});
      expect(await app.outboxCount(), 1);

      await app.session.restore();
      await app.sl<SyncEngine>().syncNow();
      expect(await app.serverIds(), {'early'});
    });

    test('local data and no owner → snapshot (interrupted sign-in)', () async {
      final app = await restored();

      await app.session.restore();
      await app.untilSignedIn();

      expect(await app.serverIds(), {'l1'});
      expect((await app.kv())[BulkUploader.ownerKey], 'u1');
    });

    test('owned by another account → refused, data kept', () async {
      final app = await restored(owner: 'uA');

      expect(await app.session.restore(), const OtherAccountData());
      expect(app.session.startupResult, const OtherAccountData());

      expect(app.session.state, const LocalSession());
      expect(await app.listIds(), {'l1'});
      expect(_events, ['auth.signOut']);
      expect(app.transport.calls, isEmpty);
    });
  });

  group('another account data on the device', () {
    late _App app;

    setUp(() async {
      app = _App();
      await app.start(
        seed: (db, local) async {
          await local.write(EntityType.list, 'a1', {'name': 'A'});
          await _kv(db, BulkUploader.ownerKey, 'uA');
        },
      );
    });
    tearDown(() => app.dispose());

    test('sign-in is refused without changing anything', () async {
      final id = app.deviceId;
      final outbox = await app.outboxCount();

      final result = await app.session.signIn('b@example.com', 'pw');

      expect(result, const OtherAccountData());
      expect(app.session.state, const LocalSession());
      expect(await app.listIds(), {'a1'});
      expect(await app.outboxCount(), outbox);
      expect((await app.kv())[BulkUploader.ownerKey], 'uA');
      expect(app.deviceId, id);
      expect(app.auth.current, isNull, reason: 'auth signed out again');
      expect(app.transport.calls, isEmpty);
      expect(await app.serverIds(), isEmpty);
    });

    test(
      'replace with a failed wipe never uploads the other account data',
      () async {
        app.db.failWipe = true;

        final result = await app.session.signIn(
          'b@example.com',
          'pw',
          replaceOtherAccountData: true,
        );
        await pumpEventQueue();

        expect(result, const SessionFailed(AuthError.unknown));
        expect(app.session.state, const LocalSession());
        expect(app.auth.current, isNull, reason: 'auth signed out again');
        expect((await app.kv())[BulkUploader.ownerKey], 'uA');
        expect(await app.listIds(), {'a1'});
        expect(await app.serverIds(), isEmpty, reason: 'nothing of A sent');
      },
    );

    test('with replaceOtherAccountData the data is wiped, then sync', () async {
      final oldId = app.deviceId;
      final result = await app.session.signIn(
        'b@example.com',
        'pw',
        replaceOtherAccountData: true,
      );
      await app.untilSignedIn();
      await app.sl<SyncEngine>().syncNow();

      expect(result, const SessionOk());
      expect(await app.listIds(), isEmpty);
      expect(await app.serverIds(), isEmpty);
      expect((await app.kv())[BulkUploader.ownerKey], 'u1');
      expect(app.deviceId, isNot(oldId));
      expect(_events, [
        'auth.signIn',
        'db.wipe',
        'notifications.cancelAll',
      ], reason: 'no auth sign-out of the new user');
    });
  });

  group('with fakes only', () {
    late _Db db;
    late ChangeWriter writer;
    late _FakeAuth auth;
    late OutboxGate gate;
    late StreamController<SyncStatus> status;
    late SyncStatus engineNow;
    late bool failStop;
    Future<void> Function()? onStop;
    late SessionCubit session;

    SessionCubit build({BulkUploader? uploader}) => SessionCubit(
      auth: auth,
      db: db,
      outbox: gate,
      uploader: uploader ?? BulkUploader(db),
      notifications: _FakeNotifications(),
      log: (_) {},
      sync: SessionSync(
        start: () => _events.add('sync.start'),
        stop: () async {
          _events.add('sync.stop');
          await onStop?.call();
          if (failStop) throw StateError('stop');
        },
        register: () async => _events.add('sync.register'),
        renewDevice: () async => _events.add('sync.renewDevice'),
        syncNow: () async => _events.add('sync.syncNow'),
        status: () => status.stream,
        current: () => engineNow,
      ),
    );

    setUp(() {
      db = _Db();
      gate = OutboxGate();
      writer = ChangeWriter(
        db,
        HlcClock('dev-a'),
        outboxEnabled: () => gate.enabled,
      );
      auth = _FakeAuth();
      status = StreamController<SyncStatus>.broadcast();
      engineNow = SyncStatus.syncing;
      failStop = false;
      onStop = null;
      session = build();
    });
    tearDown(() async {
      await session.close();
      await status.close();
      await db.close();
    });

    Future<void> pushOne() async {
      final row = await (db.select(db.outbox)..limit(1)).getSingle();
      await (db.delete(
        db.outbox,
      )..where((t) => t.changeId.equals(row.changeId))).go();
      await pumpEventQueue();
    }

    test('Uploading progress counts down to SignedIn', () async {
      for (final id in ['l1', 'l2', 'l3']) {
        await writer.write(EntityType.list, id, {'name': id});
      }
      final states = <SessionState>[];
      final sub = session.stream.listen(states.add);

      await session.signIn('a@example.com', 'pw');
      await pumpEventQueue();
      expect(_events, contains('sync.start'));
      expect(session.state, const Uploading(0, 3));

      await pushOne();
      expect(session.state, const Uploading(1, 3));
      // An edit while uploading joins the queue; done never goes back.
      await writer.write(EntityType.list, 'l4', {'name': 'l4'});
      await pumpEventQueue();
      expect(session.state, const Uploading(1, 4));
      await pushOne();
      await pushOne();
      expect(session.state, const Uploading(3, 4));
      await pushOne();
      await sub.cancel();

      expect(states, [
        const SigningIn(),
        const Uploading(0, 3),
        const Uploading(1, 3),
        const Uploading(1, 4),
        const Uploading(2, 4),
        const Uploading(3, 4),
        const SignedIn(_user),
      ]);
    });

    test('Uploading becomes SignedIn when the engine goes offline', () async {
      await writer.write(EntityType.list, 'l1', {'name': 'x'});
      await session.signIn('a@example.com', 'pw');
      expect(session.state, const Uploading(0, 1));

      status.add(SyncStatus.offline);
      await pumpEventQueue();

      expect(session.state, const SignedIn(_user));
      expect(await db.select(db.outbox).get(), hasLength(1), reason: 'kept');
    });

    test(
      'Uploading ends when the engine was offline before the watch',
      () async {
        await writer.write(EntityType.list, 'l1', {'name': 'x'});
        engineNow = SyncStatus.offline; // emitted before anyone listened

        await session.signIn('a@example.com', 'pw');

        expect(session.state, const SignedIn(_user));
      },
    );

    test('an error reading the owner ends in LocalSession', () async {
      final uploader = _HookedUploader(db, failOwner: true);
      await session.close();
      session = build(uploader: uploader);

      expect(
        await session.signIn('a@example.com', 'pw'),
        const SessionFailed(AuthError.unknown),
      );
      expect(session.state, const LocalSession());
      expect(auth.current, isNull, reason: 'auth signed out again');

      // restore() never throws either.
      auth.signedIn = _user;
      await session.close();
      session = build(uploader: uploader);
      expect(session.state, const SigningIn());
      expect(await session.restore(), const SessionFailed(AuthError.unknown));
      expect(session.state, const LocalSession());
    });

    test(
      'the gate is on before enqueueAll: a racing edit is not lost',
      () async {
        await writer.write(EntityType.list, 'l1', {'name': 'x'});
        bool? gateAtSnapshot;
        Future<void>? racing;
        await session.close();
        session = build(
          uploader: _HookedUploader(
            db,
            before: () {
              gateAtSnapshot = gate.enabled;
              // Queued behind (or before) the snapshot transaction.
              racing = writer.write(EntityType.list, 'race', {'name': 'r'});
            },
          ),
        );

        await session.signIn('a@example.com', 'pw');
        await racing;

        expect(gateAtSnapshot, isTrue);
        final ids = (await db.select(db.outbox).get()).map((r) => r.entityId);
        expect(ids, containsAll(['l1', 'race']));
      },
    );

    test('sign-out steps run in order', () async {
      await session.signIn('a@example.com', 'pw');
      _events.clear();

      expect(await session.signOut(), const SessionOk());

      expect(_events, [
        'sync.stop',
        'db.wipe',
        'notifications.cancelAll',
        'auth.signOut',
        'sync.renewDevice',
        'sync.register',
      ]);
    });

    test(
      'an edit while sync stops is queued when the wipe then fails',
      () async {
        await session.signIn('a@example.com', 'pw');
        expect(gate.enabled, isTrue);
        onStop = () => writer.write(EntityType.list, 'late', {'name': 'L'});
        db.failWipe = true;

        await session.signOut();

        final ids = (await db.select(db.outbox).get()).map((r) => r.entityId);
        expect(ids, contains('late'));
      },
    );

    test('a failing sign-out step still ends in LocalSession', () async {
      await session.signIn('a@example.com', 'pw');
      failStop = true;
      db.failWipe = true;
      _events.clear();

      expect(
        await session.signOut(),
        const SessionFailed(AuthError.unknown),
        reason: 'the wipe failed',
      );

      expect(session.state, const LocalSession());
      expect(gate.enabled, isTrue, reason: 'wipe failed: owner data kept');
      expect(
        _events,
        containsAllInOrder(['sync.renewDevice', 'sync.register']),
      );
      // Recoverable: the next sign-in works.
      db.failWipe = false;
      await (db.delete(db.kv)).go();
      expect(await session.signIn('a@example.com', 'pw'), const SessionOk());
    });

    test(
      'sign out while Uploading tries a sync, then reports pending',
      () async {
        await writer.write(EntityType.list, 'l1', {'name': 'x'});
        await session.signIn('a@example.com', 'pw');
        expect(session.state, isA<Uploading>());

        expect(await session.signOut(), const PendingChanges(1));

        expect(_events, contains('sync.syncNow'));
        expect(session.state, isA<Uploading>());
        expect(await db.select(db.lists).get(), hasLength(1));
        expect(_events, isNot(contains('db.wipe')));
      },
    );

    test('deleteAccount keeps SignedIn during the RPC; a second tap is '
        'busy', () async {
      await session.signIn('a@example.com', 'pw');
      final rpc = auth.deleteGate = Completer<void>();
      final first = session.deleteAccount();
      await pumpEventQueue();

      expect(session.state, const SignedIn(_user));
      expect(await session.deleteAccount(), const SessionBusy());
      expect(await session.signOut(), const SessionBusy());

      rpc.complete();
      expect(await first, const SessionOk());
      expect(session.state, const LocalSession());
    });
  });
}

class _HookedUploader extends BulkUploader {
  _HookedUploader(super.db, {this.before, this.failOwner = false});

  final void Function()? before;
  bool failOwner;

  @override
  Future<String?> owner() async {
    if (failOwner) throw StateError('kv');
    return super.owner();
  }

  @override
  Future<int> enqueueAll(String userId) {
    before?.call();
    return super.enqueueAll(userId);
  }
}
