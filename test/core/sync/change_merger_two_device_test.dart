import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/sync/conflict_losers.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/sync/change_merger.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/field_value.dart';
import 'package:weave/core/sync/passthrough_payload_cipher.dart';
import 'package:weave/core/sync/remote_change.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/features/items/data/items_repository_impl.dart';
import 'package:weave/features/items/domain/usecases/resolve_conflict.dart';

const _cipher = PassthroughPayloadCipher();

List<({String text, String from})> _losers(ItemRow row) => [
  for (final l in decodeLosers(row.conflictText, row.conflictFrom))
    (text: l.text, from: l.from),
];

/// Full loser entries (with HLC) as a set: order may differ per device.
Set<ConflictLoser> _loserSet(ItemRow row) =>
    decodeLosers(row.conflictText, row.conflictFrom).toSet();

String _name(String deviceId) => switch (deviceId) {
  'dev-a' => 'Phone',
  'dev-b' => 'Laptop',
  _ => 'Tablet',
};

/// One simulated device: its own database, clock, writer and merger. Pushes
/// its outbox to a shared list (the "server") and pulls the others' changes,
/// sealed and opened with the real cipher.
class _Device {
  _Device(this.id) {
    db = WeaveDatabase.memory();
    clock = HlcClock(id, now: () => wall);
    writer = ChangeWriter(db, clock, now: () => wall);
    merger = ChangeMerger(db, clock, writer, (d) async => _name(d));
  }

  final String id;
  int wall = 1000;
  late final WeaveDatabase db;
  late final HlcClock clock;
  late final ChangeWriter writer;
  late final ChangeMerger merger;
  int cursor = 0;

  Future<int> outboxCount() async => (await db.select(db.outbox).get()).length;

  Future<void> push(List<RemoteChange> server) async {
    final rows = await db
        .customSelect('SELECT * FROM outbox ORDER BY rowid')
        .get();
    for (final r in rows) {
      final raw = jsonDecode(r.read<String>('fields')) as Map<String, dynamic>;
      final fields = {
        for (final e in raw.entries)
          e.key: FieldValue(
            (e.value as Map)['v'],
            (e.value as Map)['h'] as String,
            b: (e.value as Map)['b'] as String?,
          ),
      };
      final top = fields.values
          .map((f) => f.h)
          .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
      final type = EntityType.values.firstWhere(
        (t) => t.apiValue == r.read<String>('entity_type'),
      );
      final entityId = r.read<String>('entity_id');
      server.add(
        RemoteChange(
          changeId: r.read<String>('change_id'),
          type: type,
          entityId: entityId,
          deviceId: id,
          hlc: top,
          payload: await _cipher.seal(type, entityId, fields),
        ),
      );
    }
    await db.delete(db.outbox).go();
  }

  /// Applies every change after the cursor (or all, with [from] = 0).
  Future<List<MergeResult>> pull(List<RemoteChange> server, {int? from}) async {
    final results = <MergeResult>[];
    for (var i = from ?? cursor; i < server.length; i++) {
      final c = server[i];
      if (c.deviceId == id) continue;
      final fields = await _cipher.open(c.type, c.entityId, c.payload);
      results.add(await merger.apply(c, fields));
    }
    cursor = server.length;
    return results;
  }

  Future<ItemRow> item(String itemId) =>
      (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingle();
}

void main() {
  late List<RemoteChange> server;
  late _Device a;
  late _Device b;

  setUp(() async {
    server = [];
    a = _Device('dev-a');
    b = _Device('dev-b');
    await a.writer.write(EntityType.item, 'i1', {
      'listId': 'l1',
      'text': 'start',
    });
    await a.push(server);
    await b.pull(server);
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  /// A second exchange redelivering the server from [from]: no new
  /// conflicts, no outbox growth, rows unchanged.
  Future<void> expectSettled({int from = 0}) async {
    final rowA = await a.item('i1');
    final rowB = await b.item('i1');
    for (final d in [a, b]) {
      final results = await d.pull(server, from: from);
      expect(results, everyElement(MergeResult.ignored), reason: d.id);
      expect(await d.outboxCount(), 0, reason: d.id);
    }
    expect(await a.item('i1'), rowA);
    expect(await b.item('i1'), rowB);
  }

  test(
    'case P: phone edit then later offline laptop edit keeps both',
    () async {
      a.wall = 2000;
      await a.writer.write(EntityType.item, 'i1', {'text': 'a'});
      await a.push(server);
      b.wall = 3000;
      await b.writer.write(EntityType.item, 'i1', {'text': 'b'});

      expect(await b.pull(server), [MergeResult.conflict]);
      await b.push(server);
      expect(await a.pull(server), [MergeResult.conflict]);

      for (final d in [a, b]) {
        final row = await d.item('i1');
        expect(row.body, 'b', reason: d.id);
        expect(_losers(row), [(text: 'a', from: 'Phone')], reason: d.id);
      }
      await expectSettled();
    },
  );

  test('case S: both push before pulling keeps both', () async {
    a.wall = 2000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'a'});
    b.wall = 3000;
    await b.writer.write(EntityType.item, 'i1', {'text': 'b'});
    await a.push(server);
    await b.push(server);

    expect(await a.pull(server), [MergeResult.conflict]);
    expect(await b.pull(server), [MergeResult.conflict]);

    for (final d in [a, b]) {
      final row = await d.item('i1');
      expect(row.body, 'b', reason: d.id);
      expect(_losers(row), [(text: 'a', from: 'Phone')], reason: d.id);
    }
    await expectSettled();
  });

  test('sequential edits across devices never conflict', () async {
    a.wall = 2000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'a'});
    await a.push(server);
    expect(await b.pull(server), [MergeResult.applied]);
    b.wall = 3000;
    await b.writer.write(EntityType.item, 'i1', {'text': 'b'});
    await b.push(server);
    expect(await a.pull(server), [MergeResult.applied]);
    a.wall = 4000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'c'});
    await a.push(server);
    expect(await b.pull(server), [MergeResult.applied]);

    for (final d in [a, b]) {
      final row = await d.item('i1');
      expect(row.body, 'c', reason: d.id);
      expect(row.conflictText, isNull, reason: d.id);
    }
    await expectSettled();
  });

  test('resolving a conflict then syncing is sequential everywhere', () async {
    a.wall = 2000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'a'});
    b.wall = 3000;
    await b.writer.write(EntityType.item, 'i1', {'text': 'b'});
    await a.push(server);
    await b.push(server);
    await a.pull(server);
    await b.pull(server);

    b.wall = 4000;
    final repoB = ItemsRepositoryImpl(b.db, b.writer);
    await ResolveConflict(repoB)('i1', ConflictChoice.keepTheirs);
    await b.push(server);
    expect(await a.pull(server), [MergeResult.applied]);
    final repoA = ItemsRepositoryImpl(a.db, a.writer);
    await ResolveConflict(repoA)('i1', ConflictChoice.keepMine);

    for (final d in [a, b]) {
      final row = await d.item('i1');
      expect(row.body, 'a', reason: d.id);
      expect(row.conflictText, isNull, reason: d.id);
    }
    expect(await a.pull(server), isEmpty);
    expect(await b.pull(server), isEmpty);
    expect(await a.outboxCount(), 0);
  });

  test(
    'trash vs a newer edit on the other device: edit wins, no loop',
    () async {
      a.wall = 5000;
      await a.writer.write(EntityType.item, 'i1', {'deletedAt': 5000});
      b.wall = 6000;
      await b.writer.write(EntityType.item, 'i1', {'done': true});
      await a.push(server);
      await b.push(server);

      expect(await a.pull(server), [MergeResult.resurrected]);
      expect(await b.pull(server), [MergeResult.resurrected]);

      // Each side pushed one "deletedAt: null"; exchange until quiet.
      for (var round = 0; round < 3; round++) {
        await a.push(server);
        await b.push(server);
        final ra = await a.pull(server);
        final rb = await b.pull(server);
        expect([...ra, ...rb], isNot(contains(MergeResult.resurrected)));
      }
      expect(await a.outboxCount(), 0);
      expect(await b.outboxCount(), 0);
      for (final d in [a, b]) {
        final row = await d.item('i1');
        expect(row.deletedAt, isNull, reason: d.id);
        expect(row.done, isTrue, reason: d.id);
      }
    },
  );

  test(
    'unresolved conflict then a second concurrent edit keeps both losers',
    () async {
      a.wall = 2000;
      await a.writer.write(EntityType.item, 'i1', {'text': 'a'});
      b.wall = 3000;
      await b.writer.write(EntityType.item, 'i1', {'text': 'b'});
      await a.push(server);
      await b.push(server);
      await a.pull(server);
      await b.pull(server);

      a.wall = 5000;
      await a.writer.write(EntityType.item, 'i1', {'text': 'a2'});
      b.wall = 6000;
      await b.writer.write(EntityType.item, 'i1', {'text': 'b2'});
      await a.push(server);
      await b.push(server);
      expect(await a.pull(server), [MergeResult.conflict]);
      expect(await b.pull(server), [MergeResult.conflict]);

      for (final d in [a, b]) {
        final row = await d.item('i1');
        expect(row.body, 'b2', reason: d.id);
        expect(_losers(row), [
          (text: 'a', from: 'Phone'),
          (text: 'a2', from: 'Phone'),
        ], reason: d.id);
      }
      await expectSettled();
    },
  );

  Future<void> runThreeDevices(
    Future<void> Function(_Device a, _Device b, _Device c) order,
  ) async {
    final c = _Device('dev-c');
    addTearDown(c.db.close);
    await c.pull(server);

    a.wall = 2000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'A'});
    b.wall = 3000;
    await b.writer.write(EntityType.item, 'i1', {'text': 'B'});
    c.wall = 4000;
    await c.writer.write(EntityType.item, 'i1', {'text': 'C'});

    await order(a, b, c);

    final rows = <ItemRow>[];
    for (final d in [a, b, c]) {
      final row = await d.item('i1');
      rows.add(row);
      expect(row.body, 'C', reason: d.id);
      final losers = [for (final l in _losers(row)) l.text];
      expect(losers, unorderedEquals(['A', 'B']), reason: d.id);
      expect(_loserSet(row), _loserSet(rows.first), reason: d.id);
    }
    for (final d in [a, b, c]) {
      final results = await d.pull(server, from: 0);
      expect(results, everyElement(MergeResult.ignored), reason: d.id);
      expect(await d.outboxCount(), 0, reason: d.id);
    }
    for (final (i, d) in [a, b, c].indexed) {
      expect(await d.item('i1'), rows[i], reason: d.id);
    }
  }

  test('three concurrent edits keep every loser', () async {
    await runThreeDevices((a, b, c) async {
      await a.push(server);
      await b.pull(server);
      await b.push(server);
      await c.pull(server);
      await c.push(server);
      await a.pull(server);
      await b.pull(server);
    });
  });

  test('three concurrent edits keep every loser, reverse order', () async {
    await runThreeDevices((a, b, c) async {
      await c.push(server);
      await b.pull(server);
      await b.push(server);
      await a.pull(server);
      await a.push(server);
      await c.pull(server);
      await b.pull(server);
    });
  });

  Future<void> expectSameLosers(String text) async {
    final rowA = await a.item('i1');
    final rowB = await b.item('i1');
    expect(rowA.body, text);
    expect(rowB.body, text);
    expect(_loserSet(rowA), _loserSet(rowB));
    expect(_loserSet(rowA), isNotEmpty);
  }

  test('S1: a chain on A vs one newer edit on B: same losers', () async {
    a.wall = 2000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'a1'});
    a.wall = 2500;
    await a.writer.write(EntityType.item, 'i1', {'text': 'a2'});
    b.wall = 3000;
    await b.writer.write(EntityType.item, 'i1', {'text': 'b1'});
    await a.push(server);
    await b.push(server);
    await a.pull(server);
    await b.pull(server);

    await expectSameLosers('b1');
    expect(_losers(await b.item('i1')), [(text: 'a2', from: 'Phone')]);
    await expectSettled();
  });

  test('S1 variant: B edit between the two A edits: same losers', () async {
    a.wall = 2000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'a1'});
    a.wall = 3000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'a2'});
    b.wall = 2500;
    await b.writer.write(EntityType.item, 'i1', {'text': 'b1'});
    await a.push(server);
    await b.push(server);
    await a.pull(server);
    await b.pull(server);

    await expectSameLosers('a2');
    expect(_losers(await a.item('i1')), [(text: 'b1', from: 'Laptop')]);
    await expectSettled();
  });

  Future<void> caseS() async {
    a.wall = 2000;
    await a.writer.write(EntityType.item, 'i1', {'text': 'a'});
    b.wall = 3000;
    await b.writer.write(EntityType.item, 'i1', {'text': 'b'});
    await a.push(server);
    await b.push(server);
    await a.pull(server);
    await b.pull(server);
  }

  test('S2: keepTheirs on A clears the matching loser on B', () async {
    await caseS();
    a.wall = 4000;
    await ResolveConflict(ItemsRepositoryImpl(a.db, a.writer))(
      'i1',
      ConflictChoice.keepTheirs,
    );
    await a.push(server);
    expect(await b.pull(server), [MergeResult.applied]);
    final row = await b.item('i1');
    expect(row.body, 'a');
    expect(row.conflictText, isNull);
    expect(row.conflictFrom, isNull);
  });

  test('S3: keepMine on A leaves the conflict on B', () async {
    await caseS();
    await ResolveConflict(ItemsRepositoryImpl(a.db, a.writer))(
      'i1',
      ConflictChoice.keepMine,
    );
    await a.push(server);
    expect(await b.pull(server), isEmpty);
    expect((await a.item('i1')).conflictText, isNull);
    expect(_losers(await b.item('i1')), [(text: 'a', from: 'Phone')]);
  });
}
