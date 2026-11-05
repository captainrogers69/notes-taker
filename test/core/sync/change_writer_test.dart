import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/hlc.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/core/theme/note_color.dart';

Map<String, Object?> _obj(String json) =>
    Map<String, Object?>.from(jsonDecode(json) as Map);

void main() {
  late WeaveDatabase db;
  late int wall;
  late HlcClock clock;
  late ChangeWriter writer;

  setUp(() {
    db = WeaveDatabase.memory();
    wall = 1000;
    clock = HlcClock('dev-a', now: () => wall);
    writer = ChangeWriter(db, clock, now: () => 5000);
  });
  tearDown(() => db.close());

  test('write inserts row, field hlcs and one outbox entry', () async {
    await writer.write(EntityType.list, 'l1', {
      'name': 'Errands',
      'color': 'sun',
      'sortKey': 'a0',
    });
    final row = await db.select(db.lists).getSingle();
    expect(row.name, 'Errands');
    expect(row.pinnedToTop, isFalse);
    expect(_obj(row.fieldHlcs).keys, {'name', 'color', 'sortKey'});
    final out = await db.select(db.outbox).get();
    expect(out, hasLength(1));
    expect(out.single.entityType, 'list');
    expect(out.single.entityId, 'l1');
    expect(out.single.createdAt, 5000);
    final fields = _obj(out.single.fields);
    expect((fields['name'] as Map)['v'], 'Errands');
    expect((fields['name'] as Map)['h'], _obj(row.fieldHlcs)['name']);
  });

  test('second write to one field updates only that field hlc', () async {
    await writer.write(EntityType.list, 'l1', {'name': 'A', 'sortKey': 'a0'});
    final before = _obj((await db.select(db.lists).getSingle()).fieldHlcs);
    wall = 2000;
    await writer.write(EntityType.list, 'l1', {'name': 'B'});
    final row = await db.select(db.lists).getSingle();
    final after = _obj(row.fieldHlcs);
    expect(row.name, 'B');
    expect(row.sortKey, 'a0');
    expect(after['sortKey'], before['sortKey']);
    expect(after['name'], isNot(before['name']));
    expect(
      Hlc.parse(
        after['name']! as String,
      ).compareTo(Hlc.parse(before['name']! as String)),
      greaterThan(0),
    );
    expect(await db.select(db.outbox).get(), hasLength(2));
  });

  test(
    'all fields in one call share one hlc; bools and nulls encode',
    () async {
      await writer.write(EntityType.item, 'i1', {
        'listId': 'l1',
        'text': 'Milk',
        'done': true,
        'doneAt': null,
        'indent': 1,
        'sortKey': 'a0',
      });
      final fields = _obj((await db.select(db.outbox).getSingle()).fields);
      expect({for (final v in fields.values) (v! as Map)['h']}, hasLength(1));
      expect((fields['done'] as Map)['v'], true);
      expect((fields['doneAt'] as Map)['v'], isNull);
      expect((fields['indent'] as Map)['v'], 1);
      final item = await db.select(db.items).getSingle();
      expect(item.done, isTrue);
      expect(item.kind, 'task');
      expect(item.reminders, '[]');
    },
  );

  test('partial create uses documented defaults', () async {
    await writer.write(EntityType.list, 'l1', {'name': 'X'});
    final l = await db.select(db.lists).getSingle();
    expect(l.color, NoteColor.values.first.apiValue);
    expect(l.sortKey, '');
    expect(l.hideDone, isFalse);
  });

  test('failed write rolls back row and outbox', () async {
    await expectLater(
      writer.write(EntityType.list, 'l1', {'name': 'A', 'bogus': 1}),
      throwsArgumentError,
    );
    expect(await db.select(db.lists).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('wrong value type and never-sent fields are rejected', () async {
    await expectLater(
      writer.write(EntityType.item, 'i1', {'done': 'yes'}),
      throwsArgumentError,
    );
    await expectLater(
      writer.write(EntityType.item, 'i1', {'conflictText': 'x'}),
      throwsArgumentError,
    );
    expect(await db.select(db.items).get(), isEmpty);
  });

  test('writeLocalOnly sets conflict fields with no hlc or outbox', () async {
    await writer.write(EntityType.item, 'i1', {'text': 'a'});
    await writer.writeLocalOnly(EntityType.item, 'i1', {
      'conflictText': 'b',
      'conflictFrom': 'dev-b',
    });
    final item = await db.select(db.items).getSingle();
    expect(item.conflictText, 'b');
    expect(item.conflictFrom, 'dev-b');
    expect(_obj(item.fieldHlcs).keys, {'text'});
    expect(await db.select(db.outbox).get(), hasLength(1));
    await expectLater(
      writer.writeLocalOnly(EntityType.item, 'i1', {'text': 'z'}),
      throwsArgumentError,
    );
  });

  test('text write carries the base hlc it was made on', () async {
    await writer.write(EntityType.item, 'i1', {'listId': 'l1', 'text': 'a'});
    final first = _obj((await db.select(db.items).getSingle()).fieldHlcs);
    final created = _obj((await db.select(db.outbox).get()).single.fields);
    expect((created['text']! as Map).containsKey('b'), isFalse);
    expect((created['listId']! as Map).containsKey('b'), isFalse);
    expect(first.containsKey('text.b'), isFalse);

    wall = 2000;
    await writer.write(EntityType.item, 'i1', {'text': 'b', 'done': true});
    final row = await db.select(db.items).getSingle();
    final hlcs = _obj(row.fieldHlcs);
    expect(hlcs['text.b'], first['text']);
    final edit = _obj((await db.select(db.outbox).get()).last.fields);
    expect((edit['text']! as Map)['b'], first['text']);
    expect((edit['text']! as Map)['h'], hlcs['text']);
    expect((edit['done']! as Map).containsKey('b'), isFalse);

    // A write without text leaves the base alone.
    await writer.write(EntityType.item, 'i1', {'done': false});
    final after = _obj((await db.select(db.items).getSingle()).fieldHlcs);
    expect(after['text.b'], first['text']);
  });

  test('corrupt field hlcs are treated as empty', () async {
    await writer.write(EntityType.item, 'i1', {'text': 'a'});
    await db.customStatement("UPDATE items SET field_hlcs = 'not json'");
    await writer.write(EntityType.item, 'i1', {'text': 'b'});
    final row = await db.select(db.items).getSingle();
    expect(row.body, 'b');
    expect(_obj(row.fieldHlcs).keys, {'text'});
  });

  test('write persists last hlc in Kv', () async {
    await writer.write(EntityType.list, 'l1', {'name': 'A'});
    final kv = await (db.select(
      db.kv,
    )..where((t) => t.key.equals('hlc.last'))).getSingle();
    expect(kv.value, clock.last.pack());
  });

  test('clock seeded from Kv after restart issues stamps greater than the '
      'last persisted one even when wall clock went back', () async {
    wall = 9000;
    await writer.write(EntityType.list, 'l1', {'name': 'A'});
    final persisted = Hlc.parse(
      (await (db.select(
        db.kv,
      )..where((t) => t.key.equals('hlc.last'))).getSingle()).value,
    );
    final restarted = HlcClock('dev-a', now: () => 100, seed: persisted);
    expect(restarted.tick().compareTo(persisted), greaterThan(0));
    final w2 = ChangeWriter(db, restarted, now: () => 5000);
    await w2.write(EntityType.list, 'l1', {'name': 'B'});
    final stored = Hlc.parse(
      (await (db.select(
        db.kv,
      )..where((t) => t.key.equals('hlc.last'))).getSingle()).value,
    );
    expect(stored.compareTo(persisted), greaterThan(0));
  });

  test('wipe empties every table', () async {
    await writer.write(EntityType.list, 'l1', {'name': 'A'});
    await writer.write(EntityType.item, 'i1', {'text': 'a'});
    await db.into(db.miniBars).insert(MiniBarsCompanion.insert(listId: 'l1'));
    await db.wipe();
    expect(await db.select(db.lists).get(), isEmpty);
    expect(await db.select(db.items).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await db.select(db.kv).get(), isEmpty);
    expect(await db.select(db.miniBars).get(), isEmpty);
  });
}
