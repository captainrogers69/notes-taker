import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/domain/note_color_id.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/features/lists/data/lists_repository_impl.dart';
import 'package:weave/features/lists/domain/usecases/archive_list.dart';
import 'package:weave/features/lists/domain/usecases/create_list.dart';
import 'package:weave/features/lists/domain/usecases/delete_list_forever.dart';
import 'package:weave/features/lists/domain/usecases/reorder_list.dart';
import 'package:weave/features/lists/domain/usecases/restore_deleted_list.dart';
import 'package:weave/features/lists/domain/usecases/restore_list.dart';
import 'package:weave/features/lists/domain/usecases/trash_list.dart';
import 'package:weave/features/lists/domain/usecases/update_list.dart';

void main() {
  late WeaveDatabase db;
  late ChangeWriter writer;
  late ListsRepositoryImpl repo;
  late DateTime now;

  setUp(() {
    db = WeaveDatabase.memory();
    now = DateTime(2026, 11, 5, 10, 0);
    writer = ChangeWriter(db, HlcClock('dev-a', now: () => 1000));
    repo = ListsRepositoryImpl(db, writer, clock: () => now);
  });
  tearDown(() => db.close());

  Future<void> addItem(
    String id,
    String listId, {
    String kind = 'task',
    bool done = false,
    String? dueDate,
    int? dueMinutes,
    int? deletedAt,
  }) => writer.write(EntityType.item, id, {
    'listId': listId,
    'kind': kind,
    'done': done,
    'dueDate': dueDate,
    'dueMinutes': dueMinutes,
    'deletedAt': deletedAt,
  });

  test('create then watchActive emits list with openCount 0', () async {
    final id = await CreateList(repo)('Errands', NoteColor.blue);
    final lists = await repo.watchActive().first;
    expect(lists.single.id, id);
    expect(lists.single.name, 'Errands');
    expect(lists.single.color, NoteColor.blue);
    expect(lists.single.openCount, 0);
    expect(lists.single.overdueCount, 0);
  });

  test('create places new list after the last one', () async {
    final a = await CreateList(repo)('A', NoteColor.yellow);
    final b = await CreateList(repo)('B', NoteColor.yellow);
    final lists = await repo.watchActive().first;
    expect(lists.map((l) => l.id), [a, b]);
  });

  test('archive hides from active and shows in archived', () async {
    final id = await CreateList(repo)('A', NoteColor.yellow);
    await ArchiveList(repo, clock: () => now)(id);
    expect(await repo.watchActive().first, isEmpty);
    expect((await repo.watchArchived().first).single.id, id);
  });

  test('trash then restore returns list to active', () async {
    final id = await CreateList(repo)('A', NoteColor.yellow);
    await ArchiveList(repo, clock: () => now)(id);
    await TrashList(repo, clock: () => now)(id);
    expect(await repo.watchActive().first, isEmpty);
    expect(await repo.watchArchived().first, isEmpty);
    expect((await repo.watchTrashed().first).single.id, id);
    await RestoreList(repo)(id);
    expect((await repo.watchActive().first).single.id, id);
    expect(await repo.watchTrashed().first, isEmpty);
  });

  test('pinnedToTop sorts first', () async {
    final a = await CreateList(repo)('A', NoteColor.yellow);
    final b = await CreateList(repo)('B', NoteColor.yellow);
    await UpdateList(repo)(b, {'pinnedToTop': true});
    expect((await repo.watchActive().first).map((l) => l.id), [b, a]);
  });

  test('equal sortKeys tiebreak by id', () async {
    await writer.write(EntityType.list, 'z', {'sortKey': 'a0'});
    await writer.write(EntityType.list, 'b', {'sortKey': 'a0'});
    expect((await repo.watchActive().first).map((l) => l.id), ['b', 'z']);
  });

  test('reorder moves a list between neighbours', () async {
    final a = await CreateList(repo)('A', NoteColor.yellow);
    final b = await CreateList(repo)('B', NoteColor.yellow);
    final c = await CreateList(repo)('C', NoteColor.yellow);
    final lists = await repo.watchActive().first;
    final prev = await ReorderList(repo)(
      c,
      before: null,
      after: lists.first.sortKey,
    );
    expect(prev.keys, ['sortKey']);
    expect((await repo.watchActive().first).map((l) => l.id), [c, a, b]);
  });

  test('openCount ignores text lines, done and deleted items', () async {
    final id = await CreateList(repo)('A', NoteColor.yellow);
    await addItem('i1', id);
    await addItem('i2', id);
    await addItem('i3', id, done: true);
    await addItem('i4', id, kind: 'text');
    await addItem('i5', id, deletedAt: 5);
    expect((await repo.watchActive().first).single.openCount, 2);
  });

  test('overdueCount counts open tasks due before now', () async {
    final id = await CreateList(repo)('A', NoteColor.yellow);
    await addItem('i1', id, dueDate: '2026-11-04'); // overdue
    await addItem('i2', id, dueDate: '2026-11-05'); // untimed today
    await addItem('i3', id, dueDate: '2026-11-05', dueMinutes: 9 * 60); // past
    await addItem('i4', id, dueDate: '2026-11-05', dueMinutes: 11 * 60);
    await addItem('i5', id, dueDate: '2026-11-06');
    await addItem('i6', id, dueDate: '2026-11-01', done: true);
    final l = (await repo.watchActive().first).single;
    expect(l.openCount, 6 - 1);
    expect(l.overdueCount, 2);
  });

  test('counts update when items change', () async {
    final id = await CreateList(repo)('A', NoteColor.yellow);
    final it = StreamIterator(repo.watchActive());
    await it.moveNext();
    expect(it.current.single.openCount, 0);
    await addItem('i1', id);
    while (it.current.single.openCount != 1) {
      expect(await it.moveNext(), isTrue);
    }
    await it.cancel();
  });

  test('watch emits one list or null', () async {
    final id = await CreateList(repo)('A', NoteColor.yellow);
    expect((await repo.watch(id).first)?.name, 'A');
    expect(await repo.watch('nope').first, isNull);
  });

  test(
    'purgeTrash removes lists trashed > 30 days ago and their items',
    () async {
      final old = await CreateList(repo)('Old', NoteColor.yellow);
      final recent = await CreateList(repo)('Recent', NoteColor.yellow);
      await addItem('io', old);
      await addItem('ir', recent);
      final day = const Duration(days: 1).inMilliseconds;
      final n = now.millisecondsSinceEpoch;
      await UpdateList(repo)(old, {'deletedAt': n - 31 * day});
      await UpdateList(repo)(recent, {'deletedAt': n - 29 * day});
      await writer.write(EntityType.list, 'marker', {'deletedAt': 0});
      final outboxBefore = (await db.select(db.outbox).get()).length;
      await repo.purgeTrash(now);
      final lists = await db.select(db.lists).get();
      expect(lists.map((l) => l.id).toSet(), {recent, 'marker'});
      expect((await db.select(db.items).get()).map((i) => i.id), ['ir']);
      expect((await db.select(db.outbox).get()).length, outboxBefore);
    },
  );

  test('undo map from TrashList restores exact previous fields', () async {
    final id = await CreateList(repo)('A', NoteColor.green);
    await UpdateList(repo)(id, {'pinnedToTop': true});
    final before = await db.select(db.lists).getSingle();
    final undo = await TrashList(repo, clock: () => now)(id);
    expect((await repo.watchTrashed().first).single.id, id);
    await UpdateList(repo)(id, undo);
    final after = await db.select(db.lists).getSingle();
    expect(after.deletedAt, before.deletedAt);
    expect(after.name, before.name);
    expect(after.pinnedToTop, isTrue);
    expect(after.sortKey, before.sortKey);
  });

  test('deleteForever syncs purge marker then removes rows locally', () async {
    final id = await CreateList(repo)('A', NoteColor.green);
    await addItem('i1', id);
    await DeleteListForever(repo)(id);
    expect(await db.select(db.lists).get(), isEmpty);
    expect(await db.select(db.items).get(), isEmpty);
    final out = await db.select(db.outbox).get();
    final marker = out.where(
      (o) => o.entityId == id && o.fields.contains('"deletedAt"'),
    );
    final fields = jsonDecode(marker.last.fields) as Map<String, dynamic>;
    expect((fields['deletedAt'] as Map)['v'], 0);
  });

  test('undo of deleteForever restores list and all items', () async {
    final id = await CreateList(repo)('A', NoteColor.green);
    await writer.write(EntityType.item, 'i1', {
      'listId': id,
      'text': 'one',
      'done': true,
      'doneAt': 77,
      'sortKey': 'a0',
    });
    await writer.write(EntityType.item, 'i2', {
      'listId': id,
      'text': 'two',
      'sortKey': 'a1',
      'deletedAt': 99,
    });
    await writer.write(EntityType.item, 'i3', {
      'listId': id,
      'kind': 'text',
      'text': 'note',
      'sortKey': 'a2',
    });
    final before = {for (final r in await db.select(db.items).get()) r.id: r};
    final snap = await DeleteListForever(repo)(id);
    expect(await db.select(db.items).get(), isEmpty);
    await RestoreDeletedList(repo)(id, snap);
    final back = await repo.watchActive().first;
    expect(back.single.name, 'A');
    expect(back.single.color, NoteColor.green);
    final after = {for (final r in await db.select(db.items).get()) r.id: r};
    expect(after.keys, before.keys);
    for (final k in before.keys) {
      expect(after[k]!.body, before[k]!.body);
      expect(after[k]!.done, before[k]!.done);
      expect(after[k]!.sortKey, before[k]!.sortKey);
      expect(after[k]!.kind, before[k]!.kind);
      expect(after[k]!.deletedAt, before[k]!.deletedAt);
      expect(after[k]!.listId, id);
    }
  });

  test('update with an empty map is a no-op', () async {
    final id = await CreateList(repo)('A', NoteColor.green);
    final n = (await db.select(db.outbox).get()).length;
    await UpdateList(repo)(id, {});
    await UpdateList(repo)('missing', {});
    expect((await db.select(db.outbox).get()).length, n);
    expect(await db.select(db.lists).get(), hasLength(1));
  });
}
