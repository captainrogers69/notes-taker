import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/features/items/data/items_repository_impl.dart';
import 'package:weave/features/items/domain/usecases/add_item.dart';
import 'package:weave/features/items/domain/usecases/add_item_below.dart';
import 'package:weave/features/items/domain/usecases/delete_item.dart';
import 'package:weave/features/items/domain/usecases/edit_text.dart';
import 'package:weave/features/items/domain/usecases/indent_item.dart';
import 'package:weave/features/items/domain/usecases/move_item.dart';
import 'package:weave/features/items/domain/usecases/toggle_done.dart';
import 'package:weave/features/items/domain/usecases/uncheck_all.dart';
import 'package:weave/features/lists/data/lists_repository_impl.dart';
import 'package:weave/features/lists/domain/usecases/archive_list.dart';
import 'package:weave/features/lists/domain/usecases/trash_list.dart';
import 'package:weave/features/lists/domain/usecases/update_list.dart';
import 'package:weave/features/lists/presentation/list_cubit.dart';

/// The cubit on the real queries: the visual moves depend on the SQL order.
void main() {
  late WeaveDatabase db;
  late ChangeWriter writer;
  late ItemsRepositoryImpl items;
  late ListsRepositoryImpl lists;
  late ListCubit cubit;
  final now = DateTime(2026, 11, 5, 10, 0);

  Future<void> task(
    String id,
    String key, {
    String? due,
    bool done = false,
    String kind = 'task',
  }) => writer.write(EntityType.item, id, {
    'listId': 'L',
    'kind': kind,
    'text': id,
    'done': done,
    'doneAt': done ? 1000 : null,
    'indent': 0,
    'sortKey': key,
    'dueDate': due,
  });

  Future<List<String>> order() async => [
    for (final i in await items.watchList('L').first) i.id,
  ];

  setUp(() async {
    db = WeaveDatabase.memory();
    writer = ChangeWriter(db, HlcClock('dev-a', now: () => 1000));
    items = ItemsRepositoryImpl(db, writer, clock: () => now);
    lists = ListsRepositoryImpl(db, writer, clock: () => now);
    await writer.write(EntityType.list, 'L', {
      'name': 'L',
      'color': 'blue',
      'sortKey': 'a',
    });
    cubit = ListCubit(
      listId: 'L',
      items: items,
      lists: lists,
      addItem: AddItem(items),
      addItemBelow: AddItemBelow(items),
      toggleDone: ToggleDone(items),
      editText: EditText(items),
      deleteItem: DeleteItem(items),
      indentItem: IndentItem(items),
      moveItem: MoveItem(items),
      uncheckAll: UncheckAll(items),
      updateList: UpdateList(lists),
      archiveList: ArchiveList(lists, clock: () => now),
      trashList: TrashList(lists, clock: () => now),
      now: () => now,
    );
  });
  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  Future<void> settle() => pumpEventQueue(times: 50);

  test('moving follows the screen order, not the key order', () async {
    await task('a', 'a1');
    await task('b', 'a2');
    await task('c', 'a3');
    await settle();
    expect(await order(), ['c', 'b', 'a']);
    await cubit.move('c', 1);
    await settle();
    expect(await order(), ['b', 'c', 'a']);
    await cubit.move('a', -1);
    await settle();
    expect(await order(), ['b', 'a', 'c']);
    await cubit.move('b', -1); // already first
    await settle();
    expect(await order(), ['b', 'a', 'c']);
  });

  test('moving skips dated tasks, text lines and done tasks', () async {
    await task('note', 'a0', kind: 'text');
    await task('dated', 'a5', due: '2026-11-06');
    await task('x', 'a1');
    await task('y', 'a2');
    await task('gone', 'a9', done: true);
    await settle();
    expect(await order(), ['note', 'dated', 'y', 'x', 'gone']);
    await cubit.move('dated', 1);
    await cubit.move('note', 1);
    await cubit.move('gone', -1);
    await cubit.move('y', -1);
    await settle();
    expect(await order(), ['note', 'dated', 'y', 'x', 'gone']);
    await cubit.move('y', 1);
    await settle();
    expect(await order(), ['note', 'dated', 'x', 'y', 'gone']);
  });

  test('drop onto a position keeps the row where it was dropped', () async {
    await task('a', 'a1');
    await task('b', 'a2');
    await task('c', 'a3');
    await task('d', 'a4');
    await settle();
    expect(cubit.state.rows.map((i) => i.id), ['d', 'c', 'b', 'a']);
    await cubit.drop(0, 2); // d lands between b and a
    await settle();
    expect(await order(), ['c', 'b', 'd', 'a']);
    await cubit.drop(3, 0); // a to the top
    await settle();
    expect(await order(), ['a', 'c', 'b', 'd']);
    await cubit.drop(0, 3); // a to the bottom
    await settle();
    expect(await order(), ['c', 'b', 'd', 'a']);
  });

  test('a drop among dated tasks changes nothing', () async {
    await task('dated1', 'a8', due: '2026-11-06');
    await task('dated2', 'a9', due: '2026-11-07');
    await task('x', 'a1');
    await settle();
    await cubit.drop(2, 1);
    await settle();
    expect(await order(), ['dated1', 'dated2', 'x']);
  });

  test('Enter under an untimed task lands right below it', () async {
    await task('a', 'a1');
    await task('b', 'a2');
    await task('c', 'a3');
    await settle();
    final id = await cubit.addBelow(cubit.state.rows[0]); // c
    await settle();
    expect(await order(), ['c', id, 'b', 'a']);
    expect(cubit.state.focusId, id);
    final last = await cubit.addBelow(
      cubit.state.rows.firstWhere((i) => i.id == 'a'),
    );
    await settle();
    expect(await order(), ['c', id, 'b', 'a', last]);
  });

  test('Enter under a dated task starts the untimed tasks', () async {
    await task('dated', 'a5', due: '2026-11-06');
    await task('x', 'a1');
    await settle();
    final id = await cubit.addBelow(cubit.state.rows[0]);
    await settle();
    expect(await order(), ['dated', id, 'x']);
  });

  test('mini bar is written on this device only', () async {
    await settle();
    await cubit.setMiniBar(shown: true);
    await settle();
    expect(cubit.state.inMiniBar, isTrue);
    final before = (await db.select(db.outbox).get()).length;
    await cubit.setMiniBar(shown: false);
    await settle();
    expect(cubit.state.inMiniBar, isFalse);
    expect((await db.select(db.outbox).get()).length, before);
  });
}
