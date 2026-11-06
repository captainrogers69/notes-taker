import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:weave/core/domain/note_color_id.dart';
import 'package:weave/features/items/domain/entities/due_spec.dart';
import 'package:weave/features/items/domain/entities/item.dart';
import 'package:weave/features/items/domain/repositories/items_repository.dart';
import 'package:weave/features/lists/domain/entities/task_list.dart';
import 'package:weave/features/lists/domain/repositories/lists_repository.dart';

/// A stream source that replays its latest value to every new listener
/// (as a Drift watch query does).
class Replay<T> {
  Replay(this.value);

  T value;
  final _c = StreamController<T>.broadcast();

  Stream<T> get stream => Stream.multi((m) {
    m.add(value);
    final s = _c.stream.listen(m.add);
    m.onCancel = s.cancel;
  });

  void add(T v) {
    value = v;
    _c.add(v);
  }
}

class FakeLists extends Fake implements ListsRepository {
  final active = Replay<List<TaskList>>(const []);

  @override
  Stream<List<TaskList>> watchActive() => active.stream;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// An in-memory [ItemsRepository] with the Up next queries, enough for the
/// real `AddItem` and `ToggleDone` use cases.
class FakeItemsStore extends Fake implements ItemsRepository {
  final items = <String, Item>{};
  final upNextAt = <DateTime>[];
  final doneTodayAt = <DateTime>[];

  /// Ids passed to [update], in order (every synced write).
  final writes = <String>[];

  /// Makes the next [update] throw (a failing write).
  bool failNext = false;
  final _changed = StreamController<void>.broadcast();

  void put(Item i) {
    items[i.id] = i;
    _changed.add(null);
  }

  Stream<List<Item>> _watch(List<Item> Function() q) => Stream.multi((m) {
    m.add(q());
    final s = _changed.stream.listen((_) => m.add(q()));
    m.onCancel = s.cancel;
  });

  static bool _overdue(Item i, DateTime now) {
    final due = i.due!;
    final today = _day(now);
    if (due.date.isBefore(today)) return true;
    final m = due.minutes;
    return due.date == today && m != null && m < now.hour * 60 + now.minute;
  }

  static int _byDue(Item a, Item b, DateTime now) {
    final o = (_overdue(a, now) ? 0 : 1) - (_overdue(b, now) ? 0 : 1);
    if (o != 0) return o;
    final d = a.due!.date.compareTo(b.due!.date);
    if (d != 0) return d;
    final am = a.due!.minutes ?? 1 << 20;
    final bm = b.due!.minutes ?? 1 << 20;
    return am - bm;
  }

  List<Item> _tasks(bool Function(Item) f) => items.values
      .where((i) => i.kind == ItemKind.task && i.due != null && f(i))
      .toList();

  @override
  Stream<List<Item>> watchUpNext(DateTime now) {
    upNextAt.add(now);
    return _watch(
      () =>
          _tasks((i) => !i.done && !i.due!.date.isAfter(_day(now)))
            ..sort((a, b) => _byDue(a, b, now)),
    );
  }

  @override
  Stream<List<Item>> watchLaterThisWeek(DateTime now) {
    final today = _day(now);
    final end = DateTime(now.year, now.month, now.day + 6);
    return _watch(
      () => _tasks(
        (i) =>
            !i.done && i.due!.date.isAfter(today) && !i.due!.date.isAfter(end),
      )..sort((a, b) => _byDue(a, b, now)),
    );
  }

  @override
  Stream<List<Item>> watchDoneToday(DateTime now) {
    doneTodayAt.add(now);
    return _watch(
      () =>
          _tasks((i) => i.done && i.due!.date == _day(now))
            ..sort((a, b) => _byDue(a, b, now)),
    );
  }

  @override
  Future<Item?> get(String id) async => items[id];

  @override
  Future<String?> lastSortKey(String listId) async {
    final keys =
        items.values
            .where((i) => i.listId == listId)
            .map((i) => i.sortKey)
            .toList()
          ..sort();
    return keys.isEmpty ? null : keys.last;
  }

  @override
  Future<Map<String, Object?>> fieldsOf(
    String id,
    Iterable<String> fields,
  ) async {
    final i = items[id];
    if (i == null) return {};
    return {
      for (final f in fields)
        f: switch (f) {
          'done' => i.done,
          'doneAt' => i.doneAt?.millisecondsSinceEpoch,
          'dueDate' => i.due?.encodeDate(),
          'dueMinutes' => i.due?.minutes,
          'reminders' => '[]',
          _ => null,
        },
    };
  }

  @override
  Future<void> update(String id, Map<String, Object?> fields) async {
    if (failNext) {
      failNext = false;
      throw StateError('write failed');
    }
    writes.add(id);
    final old = items[id];
    Object? f(String k, Object? fallback) =>
        fields.containsKey(k) ? fields[k] : fallback;
    final dueDate = f('dueDate', old?.due?.encodeDate());
    final dueMinutes = f('dueMinutes', old?.due?.minutes);
    final doneAt = f('doneAt', old?.doneAt?.millisecondsSinceEpoch);
    put(
      Item(
        id: id,
        listId: '${f('listId', old?.listId)}',
        kind: f('kind', old?.kind.name) == 'text'
            ? ItemKind.text
            : ItemKind.task,
        text: '${f('text', old?.text ?? '')}',
        done: f('done', old?.done ?? false) == true,
        doneAt: doneAt is int
            ? DateTime.fromMillisecondsSinceEpoch(doneAt, isUtc: true)
            : null,
        indent: 0,
        sortKey: '${f('sortKey', old?.sortKey ?? 'a')}',
        due: DueSpec.decode(
          dueDate is String ? dueDate : null,
          dueMinutes is int ? dueMinutes : null,
        ),
      ),
    );
  }
}

TaskList taskList(
  String id,
  String name, {
  NoteColor color = NoteColor.yellow,
}) => TaskList(
  id: id,
  name: name,
  color: color,
  sortKey: id,
  pinnedToTop: false,
  hideDone: false,
);

Item task(
  String id,
  String listId,
  String text, {
  DateTime? date,
  int? minutes,
  bool done = false,
}) => Item(
  id: id,
  listId: listId,
  kind: ItemKind.task,
  text: text,
  done: done,
  indent: 0,
  sortKey: id,
  due: date == null ? null : DueSpec(date: date, minutes: minutes),
);
