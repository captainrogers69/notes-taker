import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/sync/conflict_losers.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/sync/change_merger.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/field_value.dart';
import 'package:weave/core/sync/hlc.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/core/sync/remote_change.dart';

Map<String, Object?> _obj(String json) =>
    Map<String, Object?>.from(jsonDecode(json) as Map);

String _h(int millis, {int counter = 0, String node = 'dev-b'}) =>
    Hlc(millis, counter, node).pack();

RemoteChange _meta(
  EntityType type,
  String id,
  String hlc, {
  String deviceId = 'dev-b',
}) => RemoteChange(
  changeId: 'c-$id-$hlc',
  type: type,
  entityId: id,
  deviceId: deviceId,
  hlc: hlc,
  payload: '',
);

List<({String text, String from})> losersOf(ItemRow row) => [
  for (final l in decodeLosers(row.conflictText, row.conflictFrom))
    (text: l.text, from: l.from),
];

void main() {
  late WeaveDatabase db;
  late int wall;
  late HlcClock clock;
  late ChangeWriter writer;
  late ChangeMerger merger;

  setUp(() {
    db = WeaveDatabase.memory();
    wall = 1000;
    clock = HlcClock('dev-a', now: () => wall);
    writer = ChangeWriter(db, clock, now: () => 5000);
    merger = ChangeMerger(
      db,
      clock,
      writer,
      (deviceId) async => switch (deviceId) {
        'dev-a' => 'MacBook',
        'dev-b' => 'Pixel 8',
        _ => 'Other',
      },
    );
  });
  tearDown(() => db.close());

  Future<MergeResult> apply(
    EntityType type,
    String id,
    Map<String, FieldValue> fields, {
    String? hlc,
  }) {
    final top =
        hlc ??
        fields.values.map((f) => f.h).reduce((a, b) {
          return a.compareTo(b) >= 0 ? a : b;
        });
    return merger.apply(_meta(type, id, top), fields);
  }

  Future<ItemRow?> item(String id) =>
      (db.select(db.items)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ListRow?> list(String id) =>
      (db.select(db.lists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String?> kv(String key) async => (await (db.select(
    db.kv,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  test('newer remote field wins, older ignored', () async {
    wall = 2000;
    await writer.write(EntityType.list, 'l1', {
      'name': 'Local',
      'color': 'sun',
    });
    final localHlcs = _obj((await list('l1'))!.fieldHlcs);

    final older = await apply(EntityType.list, 'l1', {
      'name': FieldValue('Old remote', _h(1500)),
    });
    expect(older, MergeResult.ignored);
    expect((await list('l1'))!.name, 'Local');

    final newer = await apply(EntityType.list, 'l1', {
      'name': FieldValue('New remote', _h(3000)),
    });
    expect(newer, MergeResult.applied);
    final row = (await list('l1'))!;
    expect(row.name, 'New remote');
    expect(row.color, 'sun');
    final hlcs = _obj(row.fieldHlcs);
    expect(hlcs['name'], _h(3000));
    expect(hlcs['color'], localHlcs['color']);
  });

  test('different fields from two devices both survive', () async {
    await writer.write(EntityType.item, 'i1', {
      'listId': 'l1',
      'text': 'Milk',
      'done': false,
    });
    wall = 1100;
    await writer.write(EntityType.item, 'i1', {'done': true});
    final res = await apply(EntityType.item, 'i1', {
      'sortKey': FieldValue('b0', _h(1050)),
    });
    expect(res, MergeResult.applied);
    final row = (await item('i1'))!;
    expect(row.done, isTrue);
    expect(row.sortKey, 'b0');
    expect(row.body, 'Milk');
  });

  test('concurrent text edits keep both: newer remote wins', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    final outboxBefore = await db.select(db.outbox).get();
    // No base on the payload (older format) + a pending local edit.
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Theirs', _h(4000)),
    });
    expect(res, MergeResult.conflict);
    final row = (await item('i1'))!;
    expect(row.body, 'Theirs');
    expect(losersOf(row), [(text: 'Mine', from: 'MacBook')]);
    expect(_obj(row.fieldHlcs)['text'], _h(4000));
    // No re-write: the winner is the same on every device.
    expect(await db.select(db.outbox).get(), outboxBefore);
  });

  test('concurrent text edits keep both: newer local wins', () async {
    wall = 5000;
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    final localHlcs = _obj((await item('i1'))!.fieldHlcs);
    await db.delete(db.outbox).go(); // pushed: no pending edit needed
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Theirs', _h(4000), b: _h(500, node: 'dev-c')),
    });
    expect(res, MergeResult.conflict);
    final row = (await item('i1'))!;
    expect(row.body, 'Mine');
    expect(losersOf(row), [(text: 'Theirs', from: 'Pixel 8')]);
    expect(_obj(row.fieldHlcs), localHlcs);
    expect(await db.select(db.outbox).get(), isEmpty);

    // Redelivery does not raise it again.
    final again = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Theirs', _h(4000), b: _h(500, node: 'dev-c')),
    });
    expect(again, MergeResult.ignored);
    expect(await item('i1'), row);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('remote text made on top of the local text applies', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    final local = _obj((await item('i1'))!.fieldHlcs)['text']! as String;
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Theirs', _h(4000), b: local),
    });
    expect(res, MergeResult.applied);
    final row = (await item('i1'))!;
    expect(row.body, 'Theirs');
    expect(row.conflictText, isNull);
    final hlcs = _obj(row.fieldHlcs);
    expect(hlcs['text'], _h(4000));
    expect(hlcs['text.b'], local);
  });

  test('redelivered ancestor text is ignored', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    await db.delete(db.outbox).go();
    final x = {'text': FieldValue('X', _h(3000), b: _h(10, node: 'dev-c'))};
    // Concurrent with 'Mine' (other base): newer remote wins as a conflict.
    expect(await apply(EntityType.item, 'i1', x), MergeResult.conflict);
    final y = {'text': FieldValue('Y', _h(4000), b: _h(3000))};
    expect(await apply(EntityType.item, 'i1', y), MergeResult.applied);
    final row = (await item('i1'))!;
    expect(row.body, 'Y');
    expect(_obj(row.fieldHlcs)['text.b'], _h(3000));
    expect(await apply(EntityType.item, 'i1', x), MergeResult.ignored);
    expect(await apply(EntityType.item, 'i1', y), MergeResult.ignored);
    expect(await item('i1'), row);
  });

  test('text.b is local only and never read as a field', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    await writer.write(EntityType.item, 'i1', {'text': 'B'});
    final before = (await item('i1'))!;
    expect(_obj(before.fieldHlcs).containsKey('text.b'), isTrue);
    final res = await apply(EntityType.item, 'i1', {
      'text.b': FieldValue('zzz', _h(9000)),
    });
    expect(res, MergeResult.ignored);
    expect(await item('i1'), before);
  });

  test('concurrent equal text edits do not conflict', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Same'});
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Same', _h(4000)),
    });
    expect(res, MergeResult.applied);
    final row = (await item('i1'))!;
    expect(row.body, 'Same');
    expect(row.conflictText, isNull);
    expect(_obj(row.fieldHlcs)['text'], _h(4000));
  });

  test('remote text edit without pending local edit just applies', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    await db.delete(db.outbox).go(); // pushed
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Theirs', _h(4000)),
    });
    expect(res, MergeResult.applied);
    final row = (await item('i1'))!;
    expect(row.body, 'Theirs');
    expect(row.conflictText, isNull);
    expect(row.conflictFrom, isNull);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('edit after delete resurrects', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    wall = 2000;
    await writer.write(EntityType.item, 'i1', {'deletedAt': 2000});
    await db.delete(db.outbox).go();
    final res = await apply(EntityType.item, 'i1', {
      'done': FieldValue(true, _h(3000)),
    });
    expect(res, MergeResult.resurrected);
    final row = (await item('i1'))!;
    expect(row.deletedAt, isNull);
    expect(row.done, isTrue);
    // The resurrection is pushed so other devices converge.
    final outbox = await db.select(db.outbox).get();
    expect(outbox, hasLength(1));
    expect(_obj(outbox.single.fields).keys, {'deletedAt'});
  });

  test('edit older than delete does not resurrect', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    wall = 5000;
    await writer.write(EntityType.item, 'i1', {'deletedAt': 5000});
    final res = await apply(EntityType.item, 'i1', {
      'done': FieldValue(true, _h(3000)),
    });
    expect(res, MergeResult.applied);
    expect((await item('i1'))!.deletedAt, 5000);
  });

  test('purge marker deletes row', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    final res = await apply(EntityType.item, 'i1', {
      'deletedAt': FieldValue(0, _h(3000)),
    });
    expect(res, MergeResult.applied);
    expect(await item('i1'), isNull);
    expect(await kv('purged.i1'), '1');
  });

  test('purged item is never re-inserted by a late change', () async {
    await apply(EntityType.item, 'i1', {'deletedAt': FieldValue(0, _h(3000))});
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Late', _h(9000)),
    });
    expect(res, MergeResult.ignored);
    expect(await item('i1'), isNull);
  });

  test('list purge cascades to items and records purged', () async {
    await writer.write(EntityType.list, 'l1', {'name': 'L'});
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    await writer.write(EntityType.item, 'i2', {'listId': 'l1', 'text': 'B'});
    await writer.write(EntityType.item, 'x1', {'listId': 'l2', 'text': 'X'});
    final res = await apply(EntityType.list, 'l1', {
      'deletedAt': FieldValue(0, _h(3000)),
    });
    expect(res, MergeResult.applied);
    expect(await list('l1'), isNull);
    expect(await item('i1'), isNull);
    expect(await item('i2'), isNull);
    expect(await item('x1'), isNotNull);
    expect(await kv('purged.l1'), '1');
  });

  test('late item change for a purged list is ignored', () async {
    await writer.write(EntityType.list, 'l1', {'name': 'L'});
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    await apply(EntityType.list, 'l1', {'deletedAt': FieldValue(0, _h(3000))});

    final newItem = await apply(EntityType.item, 'i9', {
      'listId': FieldValue('l1', _h(9000)),
      'text': FieldValue('Late', _h(9000)),
    });
    expect(newItem, MergeResult.ignored);
    expect(await item('i9'), isNull);

    // A partial change for an item that lived in the purged list.
    final partial = await apply(EntityType.item, 'i1', {
      'done': FieldValue(true, _h(9000)),
    });
    expect(partial, MergeResult.ignored);
    expect(await item('i1'), isNull);
  });

  test('late list change for a purged list is ignored', () async {
    await writer.write(EntityType.list, 'l1', {'name': 'L'});
    await apply(EntityType.list, 'l1', {'deletedAt': FieldValue(0, _h(3000))});
    final res = await apply(EntityType.list, 'l1', {
      'name': FieldValue('Renamed', _h(9000)),
    });
    expect(res, MergeResult.ignored);
    expect(await list('l1'), isNull);
  });

  test('missing row is inserted with defaults', () async {
    final res = await apply(EntityType.item, 'i1', {
      'listId': FieldValue('l1', _h(3000)),
      'text': FieldValue('New', _h(3000)),
    });
    expect(res, MergeResult.applied);
    final row = (await item('i1'))!;
    expect(row.body, 'New');
    expect(row.kind, 'task');
    expect(row.done, isFalse);
    expect(row.reminders, '[]');
    expect(_obj(row.fieldHlcs).keys, {'listId', 'text'});
  });

  test('unknown field in payload is ignored, not thrown', () async {
    final res = await apply(EntityType.list, 'l1', {
      'name': FieldValue('L', _h(3000)),
      'futureField': FieldValue('x', _h(3000)),
    });
    expect(res, MergeResult.applied);
    final row = (await list('l1'))!;
    expect(row.name, 'L');
    expect(_obj(row.fieldHlcs).keys, {'name'});
  });

  test('wrong-typed value is skipped, others applied', () async {
    final res = await apply(EntityType.item, 'i1', {
      'listId': FieldValue('l1', _h(3000)),
      'text': FieldValue('T', _h(3000)),
      'done': FieldValue('yes', _h(3000)),
      'indent': FieldValue(null, _h(3000)), // not nullable
      'dueMinutes': FieldValue(1.5, _h(3000)),
    });
    expect(res, MergeResult.applied);
    final row = (await item('i1'))!;
    expect(row.body, 'T');
    expect(row.done, isFalse);
    expect(row.indent, 0);
    expect(row.dueMinutes, isNull);
    expect(_obj(row.fieldHlcs).keys, {'listId', 'text'});
  });

  test('nullable field accepts null', () async {
    await writer.write(EntityType.item, 'i1', {
      'listId': 'l1',
      'dueDate': '2026-11-05',
    });
    final res = await apply(EntityType.item, 'i1', {
      'dueDate': FieldValue(null, _h(3000)),
    });
    expect(res, MergeResult.applied);
    expect((await item('i1'))!.dueDate, isNull);
  });

  test('apply is idempotent', () async {
    final fields = {
      'listId': FieldValue('l1', _h(3000)),
      'text': FieldValue('T', _h(3000)),
      'done': FieldValue(true, _h(3000)),
    };
    expect(await apply(EntityType.item, 'i1', fields), MergeResult.applied);
    final first = (await item('i1'))!;
    expect(await apply(EntityType.item, 'i1', fields), MergeResult.ignored);
    expect(await item('i1'), first);
  });

  test('conflict apply is idempotent', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    final fields = {'text': FieldValue('Theirs', _h(4000))};
    expect(await apply(EntityType.item, 'i1', fields), MergeResult.conflict);
    final first = (await item('i1'))!;
    final outboxCount = (await db.select(db.outbox).get()).length;
    expect(await apply(EntityType.item, 'i1', fields), MergeResult.ignored);
    expect(await item('i1'), first);
    expect(await db.select(db.outbox).get(), hasLength(outboxCount));
  });

  test('result priority: conflict beats resurrected beats applied', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    wall = 2000;
    await writer.write(EntityType.item, 'i1', {'deletedAt': 2000});
    // Outbox still holds the pending text edit.
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Theirs', _h(4000)),
      'done': FieldValue(true, _h(4000)),
    });
    expect(res, MergeResult.conflict);
    final row = (await item('i1'))!;
    expect(row.deletedAt, isNull);
    expect(row.body, 'Theirs');
    expect(losersOf(row), [(text: 'Mine', from: 'MacBook')]);
    expect(row.done, isTrue);
  });

  test('a second concurrent loser is appended, not overwritten', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    await db.delete(db.outbox).go();
    final base = _h(500, node: 'dev-c');
    final x = {'text': FieldValue('X', _h(4000), b: base)};
    expect(await apply(EntityType.item, 'i1', x), MergeResult.conflict);
    final y = {'text': FieldValue('Y', _h(5000, node: 'dev-c'), b: base)};
    final res = await merger.apply(
      _meta(EntityType.item, 'i1', _h(5000, node: 'dev-c'), deviceId: 'dev-c'),
      y,
    );
    expect(res, MergeResult.conflict);
    final row = (await item('i1'))!;
    expect(row.body, 'Y');
    expect(losersOf(row), [
      (text: 'Mine', from: 'MacBook'),
      (text: 'X', from: 'Pixel 8'),
    ]);
    // Redelivering a loser already kept changes nothing.
    expect(await apply(EntityType.item, 'i1', x), MergeResult.ignored);
    expect(await item('i1'), row);
  });

  test('each loser keeps its own device name', () async {
    wall = 9000;
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    final base = _h(500, node: 'dev-c');
    await apply(EntityType.item, 'i1', {
      'text': FieldValue('X', _h(4000), b: base),
    });
    await apply(EntityType.item, 'i1', {
      'text': FieldValue('Z', _h(4000, counter: 1), b: base),
    });
    final row = (await item('i1'))!;
    expect(row.body, 'Mine');
    expect(losersOf(row), [
      (text: 'X', from: 'Pixel 8'),
      (text: 'Z', from: 'Pixel 8'),
    ]);
  });

  test('a field with an overflowing hlc is skipped', () async {
    const poisoned = '999999999999999-99999-x';
    final res = await apply(EntityType.list, 'l1', {
      'name': FieldValue('Bad', poisoned),
      'color': FieldValue('sun', _h(3000)),
    }, hlc: _h(3000));
    expect(res, MergeResult.applied);
    final row = (await list('l1'))!;
    expect(row.color, 'sun');
    expect(row.name, isNot('Bad'));
    expect(_obj(row.fieldHlcs).keys, {'color'});
    clock.tick(); // still usable
  });

  test('an overflowing meta hlc is ignored without side effects', () async {
    const poisoned = '000000000003000-99999-dev-b';
    final res = await merger.apply(_meta(EntityType.list, 'l1', poisoned), {
      'name': FieldValue('L', _h(3000)),
    });
    expect(res, MergeResult.ignored);
    expect(await list('l1'), isNull);
    expect(await kv('hlc.last'), isNull);
  });

  test('an hlc with millis at or above 10^14 is malformed', () async {
    const farMeta = '100000000000000-00000-dev-b';
    expect(
      await merger.apply(_meta(EntityType.list, 'l1', farMeta), {
        'name': FieldValue('L', _h(3000)),
      }),
      MergeResult.ignored,
    );
    expect(await list('l1'), isNull);
    expect(await kv('hlc.last'), isNull);

    final res = await apply(EntityType.list, 'l1', {
      'name': FieldValue('Bad', '999999999999999-00000-dev-b'),
      'color': FieldValue('sun', _h(3000)),
    }, hlc: _h(3000));
    expect(res, MergeResult.applied);
    final row = (await list('l1'))!;
    expect(row.color, 'sun');
    expect(_obj(row.fieldHlcs).keys, {'color'});
    expect(clock.last.millis, lessThan(100000000000000));
  });

  test('a base not older than its hlc counts as absent', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    await db.delete(db.outbox).go(); // no pending edit: absent b = sequential
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Theirs', _h(4000), b: _h(4000)),
    });
    expect(res, MergeResult.applied);
    expect((await item('i1'))!.conflictText, isNull);
  });

  test(
    'older text from the same device is an ancestor, newer is sequential',
    () async {
      await apply(EntityType.item, 'i1', {
        'listId': FieldValue('l1', _h(2000)),
        'text': FieldValue('one', _h(2000)),
      });
      final other = _h(100, node: 'dev-c');
      // Newer from the same device, unrelated base: sequential.
      expect(
        await apply(EntityType.item, 'i1', {
          'text': FieldValue('three', _h(3000), b: other),
        }),
        MergeResult.applied,
      );
      // Older from the same device: already superseded.
      expect(
        await apply(EntityType.item, 'i1', {
          'text': FieldValue('two', _h(2500), b: other),
        }),
        MergeResult.ignored,
      );
      final row = (await item('i1'))!;
      expect(row.body, 'three');
      expect(row.conflictText, isNull);
    },
  );

  test('a multi-line loser redelivered is not duplicated', () async {
    wall = 9000;
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    final x = {
      'text': FieldValue('one\ntwo', _h(4000), b: _h(500, node: 'dev-c')),
    };
    expect(await apply(EntityType.item, 'i1', x), MergeResult.conflict);
    final row = (await item('i1'))!;
    expect(losersOf(row), [(text: 'one\ntwo', from: 'Pixel 8')]);
    expect(await apply(EntityType.item, 'i1', x), MergeResult.ignored);
    expect(await item('i1'), row);
  });

  test('a legacy plain-string conflict is kept as one loser', () async {
    wall = 9000;
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    await writer.writeLocalOnly(EntityType.item, 'i1', {
      'conflictText': 'old',
      'conflictFrom': 'Tablet',
    });
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('X', _h(4000), b: _h(500, node: 'dev-c')),
    });
    expect(res, MergeResult.conflict);
    expect(losersOf((await item('i1'))!), [
      (text: 'old', from: 'Tablet'),
      (text: 'X', from: 'Pixel 8'),
    ]);
  });

  test(
    'newer remote text whose loser is already kept is just applied',
    () async {
      await writer.write(EntityType.item, 'i1', {
        'listId': 'l1',
        'text': 'Mine',
      });
      await writer.writeLocalOnly(
        EntityType.item,
        'i1',
        encodeLosers([(text: 'Mine', from: 'Tablet', hlc: '')]),
      );
      final res = await apply(EntityType.item, 'i1', {
        'text': FieldValue('Theirs', _h(4000)),
      });
      expect(res, MergeResult.applied);
      final row = (await item('i1'))!;
      expect(row.body, 'Theirs');
      expect(losersOf(row), [(text: 'Mine', from: 'Tablet')]);
    },
  );

  test('applying a text drops a loser equal to it', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    await db.delete(db.outbox).go();
    await writer.writeLocalOnly(
      EntityType.item,
      'i1',
      encodeLosers([(text: 'Theirs', from: 'Pixel 8', hlc: '')]),
    );
    final local = _obj((await item('i1'))!.fieldHlcs)['text']! as String;
    final res = await apply(EntityType.item, 'i1', {
      'text': FieldValue('Theirs', _h(4000), b: local),
    });
    expect(res, MergeResult.applied);
    final row = (await item('i1'))!;
    expect(row.conflictText, isNull);
    expect(row.conflictFrom, isNull);
  });

  test('a later edit in the same device chain replaces its loser', () async {
    wall = 9000;
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    final a1 = {'text': FieldValue('a1', _h(4000), b: _h(500, node: 'dev-c'))};
    expect(await apply(EntityType.item, 'i1', a1), MergeResult.conflict);
    // a2 (made on a1) never arrived; a3 is made on a2.
    final a3 = {'text': FieldValue('a3', _h(4500), b: _h(4200))};
    expect(await apply(EntityType.item, 'i1', a3), MergeResult.conflict);
    final row = (await item('i1'))!;
    expect(losersOf(row), [(text: 'a3', from: 'Pixel 8')]);
    // The superseded ancestor is not brought back.
    expect(await apply(EntityType.item, 'i1', a1), MergeResult.ignored);
    expect(await item('i1'), row);
  });

  test('item insert without a list is ignored', () async {
    expect(
      await apply(EntityType.item, 'i1', {'text': FieldValue('T', _h(3000))}),
      MergeResult.ignored,
    );
    expect(
      await apply(EntityType.item, 'i2', {
        'listId': FieldValue('', _h(3000)),
        'text': FieldValue('T', _h(3000)),
      }),
      MergeResult.ignored,
    );
    expect(await db.select(db.items).get(), isEmpty);
  });

  test('purge drops pending outbox rows and the mini bar', () async {
    await writer.write(EntityType.list, 'l1', {'name': 'L'});
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    await writer.write(EntityType.item, 'x1', {'listId': 'l2', 'text': 'X'});
    await db.into(db.miniBars).insert(MiniBarsCompanion.insert(listId: 'l1'));
    await db.into(db.miniBars).insert(MiniBarsCompanion.insert(listId: 'l2'));
    await apply(EntityType.list, 'l1', {'deletedAt': FieldValue(0, _h(3000))});
    final outbox = await db.select(db.outbox).get();
    expect(outbox.map((o) => o.entityId), ['x1']);
    final bars = await db.select(db.miniBars).get();
    expect(bars.map((b) => b.listId), ['l2']);
    expect(await kv('purged.i1'), '1');

    await apply(EntityType.item, 'x1', {'deletedAt': FieldValue(0, _h(3000))});
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('trash older than a local edit is undone everywhere', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    wall = 5000;
    await writer.write(EntityType.item, 'i1', {'done': true});
    await db.delete(db.outbox).go();
    final res = await apply(EntityType.item, 'i1', {
      'deletedAt': FieldValue(3000, _h(3000)),
    });
    expect(res, MergeResult.resurrected);
    final row = (await item('i1'))!;
    expect(row.deletedAt, isNull);
    expect(row.done, isTrue);
    final outbox = await db.select(db.outbox).get();
    expect(outbox, hasLength(1));
    final sent = _obj(outbox.single.fields);
    expect(sent.keys, {'deletedAt'});
    expect((sent['deletedAt']! as Map)['v'], isNull);
  });

  test('trash newer than every local field applies', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'A'});
    await db.delete(db.outbox).go();
    final res = await apply(EntityType.item, 'i1', {
      'deletedAt': FieldValue(3000, _h(3000)),
    });
    expect(res, MergeResult.applied);
    expect((await item('i1'))!.deletedAt, 3000);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('receive uses the newest field hlc', () async {
    await merger.apply(_meta(EntityType.list, 'l1', _h(3000)), {
      'name': FieldValue('L', _h(9000)),
    });
    expect(clock.last.compareTo(Hlc.parse(_h(9000))), greaterThan(0));
  });

  test('receive advances the local clock past the remote hlc', () async {
    await apply(EntityType.list, 'l1', {'name': FieldValue('L', _h(9000))});
    expect(clock.last.compareTo(Hlc.parse(_h(9000))), greaterThan(0));
    expect(await kv('hlc.last'), clock.last.pack());
  });

  test('changes roll back together on failure', () async {
    final failing = ChangeMerger(
      db,
      clock,
      writer,
      (_) async => throw StateError('boom'),
    );
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'Mine'});
    wall = 2000;
    await writer.write(EntityType.item, 'i1', {'deletedAt': 2000});
    final before = (await item('i1'))!;
    final outboxBefore = await db.select(db.outbox).get();
    // Resurrects (writes to the outbox), then fails on the conflict.
    await expectLater(
      failing.apply(_meta(EntityType.item, 'i1', _h(4000)), {
        'text': FieldValue('Theirs', _h(4000)),
        'done': FieldValue(true, _h(4000)),
      }),
      throwsStateError,
    );
    expect(await item('i1'), before);
    expect(await db.select(db.outbox).get(), outboxBefore);
  });
}
