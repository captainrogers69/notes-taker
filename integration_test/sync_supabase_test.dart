// Day 3 gate: two engines converge through the real Supabase backend.
//
// Run: flutter test integration_test/sync_supabase_test.dart -d macos \
//        --flavor dev --dart-define-from-file=config/dev.json
//
// Skipped unless SUPABASE_URL, SUPABASE_ANON_KEY, TEST_EMAIL and
// TEST_PASSWORD are defined (a dedicated test user). Deletes only that
// user's `changes` rows and the `devices` rows this test creates. Prints
// ids and timings only.
import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/ids/new_id.dart';
import 'package:weave/core/sync/change_merger.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/device_directory.dart';
import 'package:weave/core/sync/device_info.dart';
import 'package:weave/core/sync/device_names.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/core/sync/passthrough_payload_cipher.dart';
import 'package:weave/core/sync/pulled_change.dart';
import 'package:weave/core/sync/remote_change.dart';
import 'package:weave/core/sync/supabase_sync_transport.dart';
import 'package:weave/core/sync/sync_engine.dart';
import 'package:weave/core/sync/sync_offline_exception.dart';
import 'package:weave/core/sync/sync_status.dart';
import 'package:weave/core/sync/sync_transport.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');
const _email = String.fromEnvironment('TEST_EMAIL');
const _password = String.fromEnvironment('TEST_PASSWORD');

/// The real transport, switchable offline for the offline-edit case.
class _Switchable implements SyncTransport {
  _Switchable(this.inner);

  final SupabaseSyncTransport inner;
  bool offline = false;

  void _check() {
    if (offline) throw const SyncOfflineException();
  }

  @override
  Future<void> push(List<RemoteChange> changes) {
    _check();
    return inner.push(changes);
  }

  @override
  Future<PulledPage> pull({required int afterSeq, int limit = 500}) {
    _check();
    return inner.pull(afterSeq: afterSeq, limit: limit);
  }

  @override
  Stream<void> hints() => inner.hints();

  @override
  Future<void> touchDevice(String id, String name, String platform) {
    _check();
    return inner.touchDevice(id, name, platform);
  }

  @override
  Future<List<DeviceInfo>> devices() {
    _check();
    return inner.devices();
  }
}

class _Device {
  _Device(this.id, this.name, this.client) {
    db = WeaveDatabase.memory();
    clock = HlcClock(id);
    writer = ChangeWriter(db, clock);
    names = DeviceNames(db, selfId: id, selfName: name);
    real = SupabaseSyncTransport(client, deviceId: id);
    transport = _Switchable(real);
    directory = DeviceDirectory(
      transport: transport,
      names: names,
      platform: 'macos',
    );
    engine = SyncEngine(
      db: db,
      transport: transport,
      cipher: const PassthroughPayloadCipher(),
      merger: ChangeMerger(db, clock, writer, names.nameOf),
      deviceId: id,
      onForeignDevices: directory.ensureKnown,
      log: logs.add,
    );
  }

  final String id;
  final String name;
  final SupabaseClient client;
  final logs = <String>[];
  late final WeaveDatabase db;
  late final HlcClock clock;
  late final ChangeWriter writer;
  late final DeviceNames names;
  late final SupabaseSyncTransport real;
  late final _Switchable transport;
  late final DeviceDirectory directory;
  late final SyncEngine engine;

  Future<ListRow?> list(String listId) => (db.select(
    db.lists,
  )..where((t) => t.id.equals(listId))).getSingleOrNull();

  Future<List<ItemRow>> items() => (db.select(
    db.items,
  )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

  Future<int> outboxCount() async => (await db.select(db.outbox).get()).length;

  Future<void> close() async {
    await engine.dispose();
    await real.dispose();
    await db.close();
  }
}

List<Object?> _synced(ItemRow r) => [
  r.id,
  r.listId,
  r.kind,
  r.body,
  r.done,
  r.doneAt,
  r.indent,
  r.sortKey,
  r.deletedAt,
];

/// Polls [check] until true; returns the time it took, or fails.
Future<Duration> _until(
  FutureOr<bool> Function() check, {
  Duration timeout = const Duration(seconds: 15),
  String what = 'condition',
}) async {
  final watch = Stopwatch()..start();
  while (!await check()) {
    if (watch.elapsed > timeout) fail('$what not met in $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return watch.elapsed;
}

Future<SupabaseClient> _signedInClient() async {
  final c = SupabaseClient(
    _url,
    _key,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await c.auth.signInWithPassword(email: _email, password: _password);
  return c;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Two in-memory databases, one per simulated device: separate executors.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final missing =
      _url.isEmpty || _key.isEmpty || _email.isEmpty || _password.isEmpty;

  group(
    'Supabase sync',
    skip: missing
        ? 'SUPABASE_URL / SUPABASE_ANON_KEY / TEST_EMAIL / TEST_PASSWORD '
              'not defined'
        : null,
    () {
      late SupabaseClient clientA;
      late SupabaseClient clientB;
      late String userId;
      late _Device a;
      late _Device b;
      final runTag = newId().substring(24);

      Future<void> cleanUp() async {
        await clientA.from('changes').delete().eq('user_id', userId);
        await clientA.from('devices').delete().inFilter('id', [a.id, b.id]);
      }

      setUpAll(() async {
        clientA = await _signedInClient();
        clientB = await _signedInClient();
        final id = clientA.auth.currentUser?.id;
        if (id == null) fail('sign-in returned no user');
        userId = id;
        a = _Device('it-a-$runTag', 'IT device A', clientA);
        b = _Device('it-b-$runTag', 'IT device B', clientB);
        await cleanUp();
      });

      tearDownAll(() async {
        try {
          await cleanUp();
        } finally {
          await a.close();
          await b.close();
          await clientA.auth.signOut();
          await clientB.auth.signOut();
          await clientA.dispose();
          await clientB.dispose();
        }
      });

      test('a list made on A reaches B within 3 s (NFR1)', () async {
        // Wait for B's realtime channel: it hints once when subscribed.
        final subscribed = Completer<void>();
        final hintSub = b.transport.hints().listen((_) {
          if (!subscribed.isCompleted) subscribed.complete();
        });
        addTearDown(hintSub.cancel);

        await a.directory.start();
        await b.directory.start();
        a.engine.start();
        b.engine.start();
        await subscribed.future.timeout(const Duration(seconds: 20));
        await _until(
          () =>
              a.engine.current == SyncStatus.synced &&
              b.engine.current == SyncStatus.synced,
          what: 'first passes',
        );

        // Counts hints for other devices' inserts only, so a resubscribe
        // hint cannot satisfy the check.
        final insertHintsBefore = b.real.foreignInsertHints;
        final listId = newId();
        final watch = Stopwatch()..start();
        await a.writer.write(EntityType.list, listId, {'name': 'Gate list'});
        await _until(
          () async => await b.list(listId) != null,
          timeout: const Duration(seconds: 10),
          what: 'list on B',
        );
        final latency = watch.elapsed;
        // ignore: avoid_print
        print('NFR1 latency A→B: ${latency.inMilliseconds} ms');

        expect(
          b.real.foreignInsertHints,
          greaterThan(insertHintsBefore),
          reason: 'arrived by an insert hint',
        );
        expect(latency, lessThan(const Duration(seconds: 3)));
        expect((await b.list(listId))!.name, 'Gate list');
        expect(await b.names.nameOf(a.id), 'IT device A');
      });

      test('offline edits converge when back online', () async {
        final listId = newId();
        final i1 = newId();
        final i2 = newId();
        await a.writer.write(EntityType.list, listId, {'name': 'Offline'});
        await a.writer.write(EntityType.item, i1, {
          'listId': listId,
          'text': 'task 1',
        });
        await a.writer.write(EntityType.item, i2, {
          'listId': listId,
          'text': 'task 2',
        });
        await _until(
          () async => (await b.items()).length >= 2,
          what: 'seed on B',
        );

        b.transport.offline = true;
        await a.writer.write(EntityType.item, i1, {'done': true});
        await b.writer.write(EntityType.item, i2, {'text': 'from b'});
        await b.engine.syncNow();
        expect(b.engine.current, SyncStatus.offline);
        expect(await b.outboxCount(), greaterThan(0));
        await _until(() async => await a.outboxCount() == 0, what: 'A pushed');

        b.transport.offline = false;
        for (var i = 0; i < 2; i++) {
          await b.engine.syncNow();
          await a.engine.syncNow();
        }
        await _until(
          () async =>
              (await a.items()).map(_synced).toString() ==
              (await b.items()).map(_synced).toString(),
          what: 'convergence',
        );

        final itemsA = {for (final r in await a.items()) r.id: r};
        expect(itemsA[i1]!.done, isTrue);
        expect(itemsA[i2]!.body, 'from b');
        expect(await a.outboxCount(), 0);
        expect(await b.outboxCount(), 0);
      });
    },
  );
}
