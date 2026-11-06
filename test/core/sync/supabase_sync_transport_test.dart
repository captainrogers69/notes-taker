import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/remote_change.dart';
import 'package:weave/core/sync/supabase_sync_transport.dart';
import 'package:weave/core/sync/sync_offline_exception.dart';

Map<String, Object?> _row(int seq, {String device = 'dev-b'}) => {
  'seq': seq,
  'change_id': 'c$seq',
  'entity_type': 'list',
  'entity_id': 'l$seq',
  'device_id': device,
  'hlc': '000000000001000-0000-$device',
  'payload': 'p$seq',
};

/// A fake realtime feed: records opens/closes and lets the test drive rows
/// and statuses.
class _Feed {
  final opened = <String>[];
  int closed = 0;
  void Function(Map<String, dynamic>)? onInsert;
  void Function(RealtimeSubscribeStatus)? onStatus;

  Future<void> Function() call(
    String userId, {
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function(RealtimeSubscribeStatus status) onStatus,
  }) {
    opened.add(userId);
    this.onInsert = onInsert;
    this.onStatus = onStatus;
    return () async => closed++;
  }
}

void main() {
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handler;
  late SupabaseClient client;
  late List<String> logs;

  SupabaseSyncTransport transport({
    _Feed? feed,
    Stream<String?> Function()? users,
    Duration timeout = const Duration(seconds: 10),
  }) => SupabaseSyncTransport(
    client,
    deviceId: 'dev-a',
    timeout: timeout,
    insertFeed: feed?.call,
    userIds: users,
    log: logs.add,
  );

  setUp(() {
    requests = [];
    logs = [];
    handler = (_) async => http.Response('[]', 200);
    client = SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        final res = await handler(r);
        return http.Response.bytes(
          res.bodyBytes,
          res.statusCode,
          headers: res.headers,
          request: r,
        );
      }),
    );
  });

  tearDown(() => client.dispose());

  group('push', () {
    test('upserts on change_id, ignoring duplicates', () async {
      await transport().push([
        const RemoteChange(
          changeId: 'c1',
          type: EntityType.item,
          entityId: 'i1',
          deviceId: 'dev-a',
          hlc: 'h1',
          payload: 'p1',
        ),
      ]);
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/rest/v1/changes');
      expect(r.url.queryParameters['on_conflict'], 'change_id');
      expect(r.headers['Prefer'], contains('resolution=ignore-duplicates'));
      expect(r.headers['Prefer'], contains('missing=default'));
      expect(jsonDecode(r.body), [
        {
          'change_id': 'c1',
          'entity_type': 'item',
          'entity_id': 'i1',
          'device_id': 'dev-a',
          'hlc': 'h1',
          'payload': 'p1',
        },
      ]);
    });

    test('an empty push sends nothing', () async {
      await transport().push(const []);
      expect(requests, isEmpty);
    });
  });

  group('pull', () {
    test('asks for seq > afterSeq ordered by seq with the limit', () async {
      handler = (_) async => http.Response(jsonEncode([_row(6), _row(7)]), 200);
      final page = await transport().pull(afterSeq: 5, limit: 50);
      final rows = page.rows;
      final q = requests.single.url.queryParameters;
      expect(requests.single.method, 'GET');
      expect(q['seq'], 'gt.5');
      expect(q['order'], startsWith('seq.asc'));
      expect(q['limit'], '50');
      expect(rows.map((r) => r.seq), [6, 7]);
      expect(rows.first.change.changeId, 'c6');
      expect(rows.first.change.type, EntityType.list);
      expect(rows.first.change.deviceId, 'dev-b');
      expect(rows.first.change.payload, 'p6');
      expect(page.full, isFalse);
      expect(page.lastSeq, 7);
    });

    test('skips malformed rows without throwing', () async {
      handler = (_) async => http.Response(
        jsonEncode([
          _row(1),
          {..._row(2), 'seq': '2'},
          {..._row(3), 'entity_type': 'note'},
          {..._row(4)}..remove('payload'),
          {..._row(5), 'hlc': null},
          _row(6),
        ]),
        200,
      );
      final page = await transport().pull(afterSeq: 0, limit: 6);
      expect(page.rows.map((r) => r.seq), [1, 6]);
      expect(page.full, isTrue, reason: 'raw page had limit rows');
      expect(page.lastSeq, 6);
      expect(logs, hasLength(4));
      expect(logs.join(), isNot(contains('p4')), reason: 'ids only');
    });
  });

  group('network errors become SyncOfflineException', () {
    final cases = <String, Object>{
      'SocketException': const SocketException('down'),
      'ClientException': http.ClientException('down'),
    };
    for (final e in cases.entries) {
      test(e.key, () async {
        handler = (_) async => throw e.value;
        final t = transport();
        await expectLater(
          t.pull(afterSeq: 0),
          throwsA(isA<SyncOfflineException>()),
        );
        await expectLater(
          t.push([
            const RemoteChange(
              changeId: 'c',
              type: EntityType.list,
              entityId: 'l',
              deviceId: 'dev-a',
              hlc: 'h',
              payload: 'p',
            ),
          ]),
          throwsA(isA<SyncOfflineException>()),
        );
        await expectLater(
          t.touchDevice('dev-a', 'Mac', 'macos'),
          throwsA(isA<SyncOfflineException>()),
        );
        await expectLater(t.devices(), throwsA(isA<SyncOfflineException>()));
      });
    }

    test('a pull is not retried by the client (one request only)', () async {
      handler = (_) async => throw const SocketException('down');
      await expectLater(
        transport().pull(afterSeq: 0),
        throwsA(isA<SyncOfflineException>()),
      );
      expect(requests, hasLength(1));
    });

    test('no answer within the timeout', () async {
      handler = (_) => Completer<http.Response>().future;
      await expectLater(
        transport(timeout: const Duration(milliseconds: 20)).pull(afterSeq: 0),
        throwsA(isA<SyncOfflineException>()),
      );
    });

    test('a session refresh that cannot reach the server', () async {
      handler = (_) async => throw AuthRetryableFetchException();
      await expectLater(
        transport().pull(afterSeq: 0),
        throwsA(isA<SyncOfflineException>()),
      );
    });

    test('other auth errors stay errors', () async {
      handler = (_) async => throw const AuthException('expired');
      await expectLater(
        transport().pull(afterSeq: 0),
        throwsA(
          isA<AuthException>().having(
            (e) => e,
            'not offline',
            isNot(isA<SyncOfflineException>()),
          ),
        ),
      );
    });

    test('a server error is not offline', () async {
      handler = (_) async => http.Response(
        jsonEncode({'code': '42501', 'message': 'denied'}),
        403,
      );
      await expectLater(
        transport().pull(afterSeq: 0),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('devices', () {
    test('touchDevice upserts on id with last_seen_at', () async {
      await transport().touchDevice('dev-a', 'Mac', 'macos');
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/rest/v1/devices');
      expect(r.url.queryParameters['on_conflict'], 'id');
      expect(r.headers['Prefer'], contains('resolution=merge-duplicates'));
      final body = jsonDecode(r.body);
      expect(body, isA<Map<String, dynamic>>());
      final map = body as Map<String, dynamic>;
      expect(map['id'], 'dev-a');
      expect(map['name'], 'Mac');
      expect(map['platform'], 'macos');
      expect(DateTime.tryParse('${map['last_seen_at']}'), isNotNull);
    });

    test('devices maps rows and skips malformed ones', () async {
      handler = (_) async => http.Response(
        jsonEncode([
          {
            'id': 'dev-b',
            'name': 'Phone',
            'platform': 'ios',
            'last_seen_at': '2026-11-06T10:00:00+00:00',
          },
          {'id': 'dev-c', 'name': null, 'platform': 'android'},
          {'id': 'dev-d', 'name': 'Old', 'platform': 'windows'},
        ]),
        200,
      );
      final list = await transport().devices();
      expect(list.map((d) => d.id), ['dev-b', 'dev-d']);
      expect(list.first.lastSeen, DateTime.utc(2026, 11, 6, 10));
      expect(list.last.lastSeen, DateTime.utc(1970));
    });
  });

  group('hints', () {
    test('emit for other devices only', () async {
      final feed = _Feed();
      final t = transport(feed: feed, users: () => Stream.value('u1'));
      var hints = 0;
      final sub = t.hints().listen((_) => hints++);
      await pumpEventQueue();
      expect(feed.opened, ['u1']);

      feed.onInsert!({'device_id': 'dev-a'});
      feed.onInsert!({'device_id': 'dev-b'});
      feed.onInsert!(<String, dynamic>{});
      await pumpEventQueue();
      expect(hints, 2, reason: 'own insert filtered; unknown device wakes');
      expect(t.foreignInsertHints, 2);

      await sub.cancel();
      await t.dispose();
    });

    test('emit once each time the channel (re)subscribes', () async {
      final feed = _Feed();
      final t = transport(feed: feed, users: () => Stream.value('u1'));
      var hints = 0;
      final sub = t.hints().listen((_) => hints++);
      await pumpEventQueue();
      feed.onStatus!(RealtimeSubscribeStatus.subscribed);
      feed.onStatus!(RealtimeSubscribeStatus.subscribed);
      await pumpEventQueue();
      expect(hints, 2);
      await sub.cancel();
      await t.dispose();
    });

    test(
      'resubscribe when the auth user changes, none when signed out',
      () async {
        final feed = _Feed();
        final users = StreamController<String?>();
        final t = transport(feed: feed, users: () => users.stream);
        final sub = t.hints().listen((_) {});

        users.add(null);
        await pumpEventQueue();
        expect(feed.opened, isEmpty);

        users.add('u1');
        await pumpEventQueue();
        users.add('u1');
        await pumpEventQueue();
        expect(feed.opened, ['u1']);

        users.add('u2');
        await pumpEventQueue();
        expect(feed.opened, ['u1', 'u2']);
        expect(feed.closed, 1);

        users.add(null);
        await pumpEventQueue();
        expect(feed.closed, 2);
        expect(feed.opened, ['u1', 'u2']);

        await sub.cancel();
        await t.dispose();
        await users.close();
      },
    );

    test('a channel error reopens the channel after a delay', () async {
      final feed = _Feed();
      final t = SupabaseSyncTransport(
        client,
        deviceId: 'dev-a',
        insertFeed: feed.call,
        userIds: () => Stream.value('u1'),
        resubscribeBase: const Duration(milliseconds: 50),
        log: logs.add,
      );
      final sub = t.hints().listen((_) {});
      await pumpEventQueue();
      expect(feed.opened, ['u1']);

      feed.onStatus!(RealtimeSubscribeStatus.channelError);
      await pumpEventQueue();
      expect(feed.opened, hasLength(1), reason: 'waits before reopening');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(feed.opened, ['u1', 'u1']);
      expect(feed.closed, 1);
      expect(logs.single, contains('channelError'));

      await sub.cancel();
      await t.dispose();
    });

    test('a server-side close reopens; our own close does not', () async {
      final feed = _Feed();
      final t = SupabaseSyncTransport(
        client,
        deviceId: 'dev-a',
        insertFeed: feed.call,
        userIds: () => Stream.value('u1'),
        resubscribeBase: const Duration(milliseconds: 20),
        log: logs.add,
      );
      final sub = t.hints().listen((_) {});
      await pumpEventQueue();
      final serverSide = feed.onStatus!;
      serverSide(RealtimeSubscribeStatus.closed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(feed.opened, ['u1', 'u1']);

      // Our close: the old channel's late `closed` is ignored.
      final current = feed.onStatus!;
      await sub.cancel();
      await pumpEventQueue();
      current(RealtimeSubscribeStatus.closed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(feed.opened, hasLength(2));
      expect(feed.closed, 2);
      await t.dispose();
    });

    test('cancel then listen at once still ends with one channel', () async {
      final feed = _Feed();
      final t = SupabaseSyncTransport(
        client,
        deviceId: 'dev-a',
        insertFeed: feed.call,
        // Cancelling the auth listener takes a while.
        userIds: () {
          final c = StreamController<String?>(
            onCancel: () =>
                Future<void>.delayed(const Duration(milliseconds: 30)),
          )..add('u1');
          return c.stream;
        },
        log: logs.add,
      );
      final first = t.hints().listen((_) {});
      await pumpEventQueue();
      expect(feed.opened, ['u1']);

      unawaited(first.cancel());
      final second = t.hints().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(feed.opened, ['u1', 'u1']);
      expect(feed.closed, 1, reason: 'the new channel stays open');

      await second.cancel();
      await t.dispose();
    });

    test('dispose closes the channel and the hints stream', () async {
      final feed = _Feed();
      final t = transport(feed: feed, users: () => Stream.value('u1'));
      var done = false;
      t.hints().listen((_) {}, onDone: () => done = true);
      await pumpEventQueue();
      expect(feed.opened, ['u1']);

      await t.dispose();
      await pumpEventQueue();
      expect(feed.closed, 1);
      expect(done, isTrue);
      expect(await t.hints().isEmpty, isTrue);
    });

    test('the last listener leaving closes the channel', () async {
      final feed = _Feed();
      final t = transport(feed: feed, users: () => Stream.value('u1'));
      final sub = t.hints().listen((_) {});
      await pumpEventQueue();
      await sub.cancel();
      await pumpEventQueue();
      expect(feed.closed, 1);

      // A later listener (engine restarted) opens it again.
      final again = t.hints().listen((_) {});
      await pumpEventQueue();
      expect(feed.opened, ['u1', 'u1']);
      await again.cancel();
      await t.dispose();
    });
  });
}
