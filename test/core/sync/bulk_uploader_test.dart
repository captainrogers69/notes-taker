import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/helpers/json_map.dart';
import 'package:weave/core/sync/bulk_uploader.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/core/sync/synced_fields.dart';

void main() {
  late WeaveDatabase db;
  late ChangeWriter local;
  late ChangeWriter queued;

  setUp(() {
    db = WeaveDatabase.memory();
    var wall = 1000;
    final clock = HlcClock('dev-a', now: () => wall++);
    local = ChangeWriter(db, clock, outboxEnabled: () => false);
    queued = ChangeWriter(db, clock);
  });
  tearDown(() => db.close());

  Future<Map<String, Map<String, Object?>>> outboxFor(String id) async {
    final rows = await (db.select(
      db.outbox,
    )..where((t) => t.entityId.equals(id))).get();
    expect(rows, hasLength(1), reason: 'one change per entity');
    return {
      for (final e in decodeJsonMap(rows.single.fields).entries)
        e.key: Map<String, Object?>.from(e.value! as Map),
    };
  }

  test('enqueueAll snapshots fields and hlcs and clears stale rows', () async {
    await local.write(EntityType.list, 'l1', {
      'name': 'Errands',
      'color': 'sun',
      'sortKey': 'a0',
      'pinnedToTop': true,
      'dueMinutes': 60,
    });
    await local.write(EntityType.list, 'l2', {'name': 'Home'});
    await local.write(EntityType.item, 'i1', {
      'listId': 'l1',
      'text': 'milk',
      'done': false,
      'sortKey': 'a0',
    });
    await local.write(EntityType.item, 'i1', {'text': 'oat milk'});
    await local.write(EntityType.item, 'i2', {'listId': 'l1', 'done': true});
    await local.writeLocalOnly(EntityType.item, 'i2', {'conflictText': 'x'});
    // Stale rows from before the snapshot (e.g. an older build).
    await queued.write(EntityType.list, 'l1', {'name': 'Old'});
    await local.write(EntityType.list, 'l1', {'name': 'Errands'});
    expect(await db.select(db.outbox).get(), hasLength(1));

    final count = await BulkUploader(db).enqueueAll('u1');

    expect(count, 4);
    expect(await BulkUploader(db).owner(), 'u1');
    expect(await db.select(db.outbox).get(), hasLength(4));
    for (final list in await db.select(db.lists).get()) {
      final hlcs = decodeJsonMap(list.fieldHlcs);
      final out = await outboxFor(list.id);
      expect(out.keys.toSet(), hlcs.keys.toSet(), reason: 'fields with hlcs');
      for (final f in out.keys) {
        expect(out[f]!['h'], hlcs[f], reason: f);
      }
      expect(out['name']!['v'], list.name);
    }
    final l1 = await outboxFor('l1');
    expect(l1['pinnedToTop']!['v'], true);
    expect(l1['dueMinutes']!['v'], 60);
    expect(l1['color']!['v'], 'sun');

    final i1Row = await (db.select(
      db.items,
    )..where((t) => t.id.equals('i1'))).getSingle();
    final i1Hlcs = decodeJsonMap(i1Row.fieldHlcs);
    final i1 = await outboxFor('i1');
    expect(i1.keys.toSet(), {'listId', 'text', 'done', 'sortKey'});
    expect(i1['text']!['v'], 'oat milk');
    expect(i1['text']!['h'], i1Hlcs['text']);
    expect(i1['text']!['b'], i1Hlcs[textBaseKey], reason: 'base kept');
    expect(i1['done']!['v'], false);
    final i2 = await outboxFor('i2');
    expect(i2.keys.toSet(), {'listId', 'done'}, reason: 'no local-only');
    expect(i2['done']!['v'], true);
  });

  test('enqueueAll on an empty database writes only the owner', () async {
    expect(await BulkUploader(db).owner(), isNull);
    expect(await BulkUploader(db).enqueueAll('u1'), 0);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await BulkUploader(db).owner(), 'u1');
  });
}
