import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/sync/conflict_losers.dart';
import 'package:weave/features/items/domain/entities/item_conflict.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/features/items/data/items_repository_impl.dart';
import 'package:weave/features/items/domain/entities/due_spec.dart';
import 'package:weave/features/items/domain/entities/reminder_spec.dart';
import 'package:weave/features/items/domain/entities/repeat_rule.dart';
import 'package:weave/features/items/domain/usecases/add_item.dart';
import 'package:weave/features/items/domain/usecases/move_item.dart';
import 'package:weave/features/items/domain/usecases/resolve_conflict.dart';
import 'package:weave/features/items/domain/usecases/set_due.dart';
import 'package:weave/features/items/domain/usecases/toggle_done.dart';
import 'package:weave/features/items/domain/usecases/uncheck_all.dart';

void main() {
  late WeaveDatabase db;
  late ChangeWriter writer;
  late ItemsRepositoryImpl repo;
  final now = DateTime(2026, 11, 5, 10, 0);

  setUp(() {
    db = WeaveDatabase.memory();
    writer = ChangeWriter(db, HlcClock('dev-a', now: () => 1000));
    repo = ItemsRepositoryImpl(db, writer, clock: () => now);
  });
  tearDown(() => db.close());

  Future<void> list(String id, {int? archivedAt, int? deletedAt}) =>
      writer.write(EntityType.list, id, {
        'name': id,
        'color': 'blue',
        'sortKey': id,
        'archivedAt': archivedAt,
        'deletedAt': deletedAt,
      });

  Future<void> item(
    String id,
    String listId, {
    String kind = 'task',
    String text = '',
    bool done = false,
    int? doneAt,
    String? dueDate,
    int? dueMinutes,
    String sortKey = 'a',
    String? repeat,
    List<String> reminders = const [],
  }) => writer.write(EntityType.item, id, {
    'listId': listId,
    'kind': kind,
    'text': text,
    'done': done,
    'doneAt': doneAt,
    'dueDate': dueDate,
    'dueMinutes': dueMinutes,
    'sortKey': sortKey,
    'repeat': repeat,
    'reminders': jsonEncode(reminders),
  });

  test('add parses due from raw text', () async {
    await list('L');
    final id = await AddItem(repo)('L', 'Call mum tomorrow 3pm', now);
    final it = (await repo.get(id))!;
    expect(it.text, 'Call mum');
    expect(it.due, DueSpec(date: DateTime(2026, 11, 6), minutes: 15 * 60));
    expect(it.done, isFalse);
    expect(() => AddItem(repo)('L', '   ', now), throwsArgumentError);
  });

  test('add timer stores AtTime reminder and sorts after last item', () async {
    await list('L');
    await item('x', 'L', sortKey: 'm');
    final id = await AddItem(repo)('L', 'Tea in 20 min', now);
    final it = (await repo.get(id))!;
    expect(it.reminders, [AtTime(DateTime(2026, 11, 5, 10, 20))]);
    expect(it.sortKey.compareTo('m'), greaterThan(0));
  });

  test('watchList orders overdue, timed, untimed, then done', () async {
    await list('L');
    await item('t', 'L', kind: 'text', sortKey: 'b');
    await item('done1', 'L', done: true, doneAt: 5);
    await item('done2', 'L', done: true, doneAt: 9);
    await item('nodue-old', 'L', sortKey: 'c');
    await item('nodue-new', 'L', sortKey: 'd');
    await item('later-untimed', 'L', dueDate: '2026-11-07');
    await item('later-timed', 'L', dueDate: '2026-11-07', dueMinutes: 600);
    await item('today-untimed', 'L', dueDate: '2026-11-05');
    await item('today-timed', 'L', dueDate: '2026-11-05', dueMinutes: 700);
    await item('today-past', 'L', dueDate: '2026-11-05', dueMinutes: 60);
    await item('yesterday', 'L', dueDate: '2026-11-04');
    await item('gone', 'L');
    await writer.write(EntityType.item, 'gone', {'deletedAt': 1});
    final ids = (await repo.watchList('L').first).map((i) => i.id).toList();
    expect(ids, [
      't',
      'yesterday',
      'today-past',
      'today-timed',
      'today-untimed',
      'later-timed',
      'later-untimed',
      'nodue-new',
      'nodue-old',
      'done2',
      'done1',
    ]);
  });

  test(
    'ticking repeating weekly task moves due +7 days and stays open',
    () async {
      await list('L');
      await item(
        'r',
        'L',
        dueDate: '2026-11-05',
        dueMinutes: 540,
        repeat: const RepeatRule(RepeatUnit.week, 1).encode(),
        reminders: ['before:30', 'at:2026-11-01T09:00', 'at:2026-11-20T09:00'],
      );
      final prev = await ToggleDone(repo)('r', now);
      final it = (await repo.get('r'))!;
      expect(it.done, isFalse);
      expect(it.due, DueSpec(date: DateTime(2026, 11, 12), minutes: 540));
      expect(it.reminders, [
        const Before(Duration(minutes: 30)),
        AtTime(DateTime(2026, 11, 20, 9)),
      ]);
      expect(prev['dueDate'], '2026-11-05');
    },
  );

  test('ticking and unticking a plain task', () async {
    await list('L');
    await item('p', 'L');
    await ToggleDone(repo)('p', now);
    var it = (await repo.get('p'))!;
    expect(it.done, isTrue);
    expect(it.doneAt, now.toUtc());
    final prev = await ToggleDone(repo)('p', now);
    it = (await repo.get('p'))!;
    expect(it.done, isFalse);
    expect(it.doneAt, isNull);
    expect(prev['done'], true);
  });

  test('SetDue keeps Before reminders', () async {
    await list('L');
    await item('b', 'L', dueDate: '2026-11-05', reminders: ['before:15']);
    await SetDue(repo)('b', DueSpec(date: DateTime(2026, 11, 9), minutes: 60));
    final it = (await repo.get('b'))!;
    expect(it.reminders, [const Before(Duration(minutes: 15))]);
    expect(it.due?.date, DateTime(2026, 11, 9));
  });

  test('uncheckAll clears every done item in list only', () async {
    await list('L');
    await list('M');
    await item('a', 'L', done: true, doneAt: 1);
    await item('b', 'L', done: true, doneAt: 2);
    await item('c', 'M', done: true, doneAt: 3);
    final prev = await UncheckAll(repo)('L');
    expect(prev.keys, unorderedEquals(['a', 'b']));
    expect((await repo.get('a'))!.done, isFalse);
    expect((await repo.get('b'))!.done, isFalse);
    expect((await repo.get('c'))!.done, isTrue);
  });

  test('upNext excludes archived lists and future tasks', () async {
    await list('L');
    await list('A', archivedAt: 5);
    await list('D', deletedAt: 5);
    await item('ok', 'L', dueDate: '2026-11-05');
    await item('over', 'L', dueDate: '2026-11-01');
    await item('future', 'L', dueDate: '2026-11-06');
    await item('arch', 'A', dueDate: '2026-11-05');
    await item('del', 'D', dueDate: '2026-11-05');
    await item('nodue', 'L');
    final ids = (await repo.watchUpNext(now).first).map((i) => i.id).toList();
    expect(ids, ['over', 'ok']);
  });

  test('laterThisWeek includes day +6, excludes day +7', () async {
    await list('L');
    await item('d1', 'L', dueDate: '2026-11-06');
    await item('d6', 'L', dueDate: '2026-11-11');
    await item('d7', 'L', dueDate: '2026-11-12');
    await item('today', 'L', dueDate: '2026-11-05');
    final ids = (await repo.watchLaterThisWeek(now).first)
        .map((i) => i.id)
        .toList();
    expect(ids, ['d1', 'd6']);
  });

  test(
    'resolve keepBoth inserts new task after original and clears conflict',
    () async {
      await list('L');
      await item('o', 'L', text: 'mine', sortKey: 'a');
      await item('n', 'L', text: 'next', sortKey: 'b');
      await writer.writeLocalOnly(EntityType.item, 'o', {
        'conflictText': 'theirs',
        'conflictFrom': 'dev-b',
      });
      final prev = await ResolveConflict(repo)('o', ConflictChoice.keepBoth);
      expect(prev['conflictText'], 'theirs');
      final items = await repo.watchList('L').first;
      final byKey = [...items]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
      expect(byKey.map((i) => i.text), ['mine', 'theirs', 'next']);
      expect((await repo.get('o'))!.conflicts, isEmpty);
      // Missing item: no ghost row.
      expect(await ResolveConflict(repo)('nope', ConflictChoice.keepMine), {});
      expect(await repo.get('nope'), isNull);
    },
  );

  test('resolve keepTheirs writes their text', () async {
    await list('L');
    await item('o', 'L', text: 'mine');
    await writer.writeLocalOnly(EntityType.item, 'o', {
      'conflictText': 'theirs',
      'conflictFrom': 'dev-b',
    });
    await ResolveConflict(repo)('o', ConflictChoice.keepTheirs);
    final it = (await repo.get('o'))!;
    expect(it.text, 'theirs');
    expect(it.conflicts, isEmpty);
  });

  test('resolve keepTheirs takes the chosen loser and clears all', () async {
    await list('L');
    await item('o', 'L', text: 'mine');
    await writer.writeLocalOnly(
      EntityType.item,
      'o',
      encodeLosers([
        (text: 'first', from: 'Pixel 8', hlc: ''),
        (text: 'second\nline', from: 'Tablet', hlc: ''),
      ]),
    );
    final before = (await repo.get('o'))!;
    expect(before.conflicts, [
      const ItemConflict(otherText: 'first', fromDevice: 'Pixel 8'),
      const ItemConflict(otherText: 'second\nline', fromDevice: 'Tablet'),
    ]);
    await ResolveConflict(repo)('o', ConflictChoice.keepTheirs, index: 1);
    final it = (await repo.get('o'))!;
    expect(it.text, 'second\nline');
    expect(it.conflicts, isEmpty);
  });

  test('resolve keepMine keeps text and clears every loser', () async {
    await list('L');
    await item('o', 'L', text: 'mine');
    await writer.writeLocalOnly(
      EntityType.item,
      'o',
      encodeLosers([
        (text: 'first', from: 'Pixel 8', hlc: ''),
        (text: 'second', from: 'Tablet', hlc: ''),
      ]),
    );
    await ResolveConflict(repo)('o', ConflictChoice.keepMine);
    final row = await (db.select(
      db.items,
    )..where((t) => t.id.equals('o'))).getSingle();
    expect(row.body, 'mine');
    expect(row.conflictText, isNull);
    expect(row.conflictFrom, isNull);
  });

  test('search matches case-insensitively across lists', () async {
    await list('L');
    await list('M');
    await list('D', deletedAt: 5);
    await item('1', 'L', text: 'Buy MILK');
    await item('2', 'M', text: 'milk run');
    await item('3', 'D', text: 'milk gone');
    await item('4', 'L', text: '100% milk_free');
    await item('5', 'L', text: 'deleted milk');
    await writer.write(EntityType.item, '5', {'deletedAt': 1});
    expect((await repo.search('milk').first).map((i) => i.id), ['1', '4', '2']);
    expect((await repo.search('  ').first), isEmpty);
    expect((await repo.search('%').first).map((i) => i.id), ['4']);
    expect((await repo.search('_f').first).map((i) => i.id), ['4']);
  });
  Future<List<String>> order(String listId) async => [
    for (final i in await repo.watchList(listId).first) i.id,
  ];

  test('move between equal sortKeys does not throw', () async {
    await list('L');
    await item('a', 'L', kind: 'text', sortKey: 'm');
    await item('b', 'L', kind: 'text', sortKey: 'm');
    await item('c', 'L', kind: 'text', sortKey: 'z');
    await item('x', 'L', kind: 'text', sortKey: 'zz');
    await MoveItem(repo)('x', afterId: 'a', beforeId: 'b');
    expect(await order('L'), ['a', 'b', 'x', 'c']);
  });

  test('move to top and directly after afterId', () async {
    await list('L');
    await item('a', 'L', kind: 'text', sortKey: 'b');
    await item('b', 'L', kind: 'text', sortKey: 'c');
    await item('c', 'L', kind: 'text', sortKey: 'd');
    await MoveItem(repo)('c', afterId: null, beforeId: 'a');
    expect(await order('L'), ['c', 'a', 'b']);
    await MoveItem(repo)('c', afterId: 'a');
    expect(await order('L'), ['a', 'c', 'b']);
  });

  test('add with an empty-key item in the list succeeds', () async {
    await list('L');
    await item('e', 'L', sortKey: '');
    final id = await AddItem(repo)('L', 'new', now);
    expect(await repo.get(id), isNotNull);
  });

  test('resolve rolls back everything when a later write fails', () async {
    final failing = _FailingClear(db, writer);
    await list('L');
    await item('o', 'L', text: 'mine', sortKey: 'a');
    await writer.writeLocalOnly(EntityType.item, 'o', {
      'conflictText': 'theirs',
      'conflictFrom': 'dev-b',
    });
    await expectLater(
      ResolveConflict(failing)('o', ConflictChoice.keepBoth),
      throwsStateError,
    );
    expect(await order('L'), ['o']);
    expect((await repo.get('o'))!.conflicts, isNotEmpty);
  });

  test('keepBoth copies the kind of the conflicted item', () async {
    await list('L');
    await item('o', 'L', kind: 'text', text: 'mine', sortKey: 'a');
    await writer.writeLocalOnly(EntityType.item, 'o', {
      'conflictText': 'theirs',
      'conflictFrom': 'dev-b',
    });
    final prev = await ResolveConflict(repo)('o', ConflictChoice.keepBoth);
    final created = (await repo.get(prev['createdId'] as String))!;
    expect(created.kind.name, 'text');
  });
}

class _FailingClear extends ItemsRepositoryImpl {
  _FailingClear(super.db, super.writer);

  @override
  Future<void> clearConflict(String id) async => throw StateError('boom');
}
