import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/field_value.dart';
import 'package:weave/core/sync/in_memory_sync_transport.dart';
import 'package:weave/core/sync/passthrough_payload_cipher.dart';
import 'package:weave/core/sync/remote_change.dart';
import 'package:weave/core/sync/sync_offline_exception.dart';

RemoteChange change(String id, {String device = 'a'}) => RemoteChange(
  changeId: id,
  type: EntityType.item,
  entityId: 'e-$id',
  deviceId: device,
  hlc: 'h$id',
  payload: 'p$id',
);

void main() {
  test('pushing same changeId twice stores once', () async {
    final a = InMemorySyncTransport.newServer()('a');
    await a.push([change('1')]);
    await a.push([change('1'), change('2')]);
    final rows = await a.pull(afterSeq: 0);
    expect(rows.map((r) => r.change.changeId), ['1', '2']);
    expect(rows.map((r) => r.seq), [1, 2]);
  });

  test('pull afterSeq returns only newer rows in order', () async {
    final a = InMemorySyncTransport.newServer()('a');
    await a.push([change('1'), change('2'), change('3')]);
    final rows = await a.pull(afterSeq: 1);
    expect(rows.map((r) => r.seq), [2, 3]);
    expect((await a.pull(afterSeq: 0, limit: 2)).length, 2);
  });

  test('hints fire for other clients, not the pusher', () async {
    final make = InMemorySyncTransport.newServer();
    final a = make('a');
    final b = make('b');
    var aHints = 0;
    var bHints = 0;
    final sa = a.hints().listen((_) => aHints++);
    final sb = b.hints().listen((_) => bHints++);
    await a.push([change('1')]);
    await Future<void>.delayed(Duration.zero);
    expect(aHints, 0);
    expect(bHints, 1);
    await sa.cancel();
    await sb.cancel();
  });

  test('offline throws SyncOfflineException', () async {
    final a = InMemorySyncTransport.newServer()('a')..offline = true;
    await expectLater(
      a.push([change('1')]),
      throwsA(isA<SyncOfflineException>()),
    );
    await expectLater(
      a.pull(afterSeq: 0),
      throwsA(isA<SyncOfflineException>()),
    );
    await expectLater(a.devices(), throwsA(isA<SyncOfflineException>()));
    await expectLater(
      a.touchDevice('a', 'n', 'ios'),
      throwsA(isA<SyncOfflineException>()),
    );
    a.offline = false;
    await a.push([change('1')]);
    expect((await a.pull(afterSeq: 0)).length, 1);
  });

  test('devices are shared across clients', () async {
    final make = InMemorySyncTransport.newServer();
    await make('a').touchDevice('a', 'Phone', 'ios');
    final list = await make('b').devices();
    expect(list.single.name, 'Phone');
  });

  test(
    'commitOutOfOrder holds rows until releaseHeld (seq gap hazard)',
    () async {
      final make = InMemorySyncTransport.newServer();
      final a = make('a');
      final b = make('b');
      a.commitOutOfOrder();
      await a.push([change('1')]); // seq 1, held
      await b.push([change('2', device: 'b')]); // seq 2, visible
      expect((await b.pull(afterSeq: 0)).map((r) => r.seq), [2]);
      expect(await b.pull(afterSeq: 2), isEmpty);
      b.releaseHeld();
      expect(await b.pull(afterSeq: 2), isEmpty); // cursor skipped seq 1
      expect((await b.pull(afterSeq: 0)).map((r) => r.seq), [1, 2]);
      expect((await b.pull(afterSeq: max(0, 2 - 100))).map((r) => r.seq), [
        1,
        2,
      ]);
    },
  );

  test(
    'commitOutOfOrder armed flag survives empty and duplicate pushes',
    () async {
      final make = InMemorySyncTransport.newServer();
      final a = make('a');
      await a.push([change('0')]);
      a.commitOutOfOrder();
      await a.push([]);
      await a.push([change('0')]);
      await a.push([change('1')]);
      await a.push([change('2')]);
      expect((await a.pull(afterSeq: 0)).map((r) => r.seq), [1, 3]);
    },
  );

  test(
    'held push emits no hint; releaseHeld hints others, not origin',
    () async {
      final make = InMemorySyncTransport.newServer();
      final a = make('a');
      final b = make('b');
      var aHints = 0;
      var bHints = 0;
      final sa = a.hints().listen((_) => aHints++);
      final sb = b.hints().listen((_) => bHints++);
      a.commitOutOfOrder();
      await a.push([change('1')]);
      await Future<void>.delayed(Duration.zero);
      expect(bHints, 0);
      b.releaseHeld();
      await Future<void>.delayed(Duration.zero);
      expect(bHints, 1);
      expect(aHints, 0);
      await sa.cancel();
      await sb.cancel();
    },
  );

  test('duplicate-only push emits no hint', () async {
    final make = InMemorySyncTransport.newServer();
    final a = make('a');
    final b = make('b');
    await a.push([change('1')]);
    var bHints = 0;
    final sb = b.hints().listen((_) => bHints++);
    await a.push([change('1')]);
    await Future<void>.delayed(Duration.zero);
    expect(bHints, 0);
    await sb.cancel();
  });

  test('duplicate inside one batch stores once', () async {
    final a = InMemorySyncTransport.newServer()('a');
    await a.push([change('1'), change('1')]);
    expect((await a.pull(afterSeq: 0)).length, 1);
  });

  test('duplicate of a held row is not re-stored and keeps its seq', () async {
    final make = InMemorySyncTransport.newServer();
    final a = make('a');
    a.commitOutOfOrder();
    await a.push([change('1')]);
    await a.push([change('1')]);
    await a.push([change('2')]);
    a.releaseHeld();
    final rows = await a.pull(afterSeq: 0);
    expect(rows.map((r) => (r.seq, r.change.changeId)), [(1, '1'), (2, '2')]);
  });

  test('offline push of a multi-row batch stores nothing', () async {
    final a = InMemorySyncTransport.newServer()('a')..offline = true;
    await expectLater(
      a.push([change('1'), change('2')]),
      throwsA(isA<SyncOfflineException>()),
    );
    a.offline = false;
    expect(await a.pull(afterSeq: 0), isEmpty);
  });

  group('cipher', () {
    const cipher = PassthroughPayloadCipher();

    test('cipher round-trip', () async {
      const fields = {
        'text': FieldValue('hi', 'h1'),
        'done': FieldValue(true, 'h2'),
        'n': FieldValue(3, 'h3'),
        'd': FieldValue(1.5, 'h4'),
        'gone': FieldValue(null, 'h5'),
      };
      final sealed = await cipher.seal(EntityType.item, 'x', fields);
      expect(jsonDecode(utf8.decode(base64.decode(sealed))), {
        'text': {'v': 'hi', 'h': 'h1'},
        'done': {'v': true, 'h': 'h2'},
        'n': {'v': 3, 'h': 'h3'},
        'd': {'v': 1.5, 'h': 'h4'},
        'gone': {'v': null, 'h': 'h5'},
      });
      expect(await cipher.open(EntityType.item, 'x', sealed), fields);
    });

    test('cipher carries the text base hlc b', () async {
      const fields = {
        'text': FieldValue('hi', 'h2', b: 'h1'),
        'done': FieldValue(true, 'h2'),
      };
      final sealed = await cipher.seal(EntityType.item, 'x', fields);
      expect(jsonDecode(utf8.decode(base64.decode(sealed))), {
        'text': {'v': 'hi', 'h': 'h2', 'b': 'h1'},
        'done': {'v': true, 'h': 'h2'},
      });
      expect(await cipher.open(EntityType.item, 'x', sealed), fields);
    });

    test('cipher treats a wrong-typed b as absent', () async {
      final sealed = base64.encode(
        utf8.encode('{"text": {"v": "hi", "h": "h2", "b": 5}}'),
      );
      final out = await cipher.open(EntityType.item, 'x', sealed);
      expect(out['text'], const FieldValue('hi', 'h2'));
      expect(out['text']!.b, isNull);
    });

    test('double 1.0 round-trips as a double', () async {
      const fields = {'d': FieldValue(1.0, 'h')};
      final sealed = await cipher.seal(EntityType.item, 'x', fields);
      final out = await cipher.open(EntityType.item, 'x', sealed);
      expect(out['d']!.v, isA<double>());
    });

    test('seal rejects unsupported values', () async {
      for (final bad in <Object?>[
        double.nan,
        double.infinity,
        [1],
        {'a': 1},
      ]) {
        await expectLater(
          cipher.seal(EntityType.item, 'x', {'k': FieldValue(bad, 'h')}),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('cipher open on garbage throws FormatException', () async {
      String enc(String s) => base64.encode(utf8.encode(s));
      for (final bad in [
        '!!!not base64',
        enc('not json'),
        enc('[1,2]'),
        enc('{"a": 1}'),
        enc('{"a": {"v": 1}}'),
        enc('{"a": {"v": 1, "h": 5}}'),
        enc('{"a": {"v": [1], "h": "x"}}'),
      ]) {
        expect(
          cipher.open(EntityType.item, 'x', bad),
          throwsA(isA<FormatException>()),
          reason: bad,
        );
      }
    });
  });
}
