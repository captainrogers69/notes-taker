import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:weave/core/domain/note_color_id.dart';
import 'package:weave/features/items/domain/entities/item.dart';
import 'package:weave/features/lists/domain/entities/task_list.dart';
import 'package:weave/features/lists/domain/repositories/lists_repository.dart';

import '../up_next/up_next_fakes.dart';

/// [FakeItemsStore] with the list screen's queries: `watchList` keeps the
/// real order for text lines, dated tasks, untimed newest first, then done.
class FakeListItems extends FakeItemsStore {
  List<Item> _live(String listId) => items.values
      .where((i) => i.listId == listId && i.deletedAt == null)
      .toList();

  @override
  Stream<List<Item>> watchList(String listId) => watch(() {
    int rank(Item i) => i.kind == ItemKind.text
        ? 0
        : i.done
        ? 3
        : i.due != null
        ? 1
        : 2;
    return _live(listId)..sort((a, b) {
      final r = rank(a) - rank(b);
      if (r != 0) return r;
      return switch (rank(a)) {
        1 => a.due!.date.compareTo(b.due!.date),
        2 => b.sortKey.compareTo(a.sortKey),
        _ => a.sortKey.compareTo(b.sortKey),
      };
    });
  });

  List<String> _keys(String listId) =>
      _live(listId).map((i) => i.sortKey).toList()..sort();

  @override
  Future<String?> sortKeyAfter(String listId, String key) async =>
      _keys(listId).where((k) => k.compareTo(key) > 0).firstOrNull;

  @override
  Future<String?> sortKeyBefore(String listId, String key) async =>
      _keys(listId).where((k) => k.compareTo(key) < 0).lastOrNull;

  @override
  Future<List<String>> doneTaskIds(String listId) async => [
    for (final i in _live(listId))
      if (i.done) i.id,
  ];
}

/// An in-memory [ListsRepository] for one screen's list.
class FakeListStore extends Fake implements ListsRepository {
  final lists = <String, TaskList>{};
  final shown = <String>{};
  final _changed = StreamController<void>.broadcast();

  void put(TaskList l) {
    lists[l.id] = l;
    _changed.add(null);
  }

  Stream<T> _watch<T>(T Function() q) => Stream.multi((m) {
    m.add(q());
    final s = _changed.stream.listen((_) => m.add(q()));
    m.onCancel = s.cancel;
  });

  @override
  Stream<TaskList?> watch(String id) => _watch(() => lists[id]);

  @override
  Stream<List<TaskList>> watchActive() => Stream.value(lists.values.toList());

  @override
  Future<String> create(String name, NoteColor color) async {
    final id = 'new${lists.length}';
    put(
      TaskList(
        id: id,
        name: name,
        color: color,
        sortKey: id,
        pinnedToTop: false,
        hideDone: false,
      ),
    );
    return id;
  }

  @override
  Stream<Set<String>> watchShownInMiniBar() => _watch(() => {...shown});

  @override
  Future<void> setShownInMiniBar(String id, {required bool shown}) async {
    shown ? this.shown.add(id) : this.shown.remove(id);
    _changed.add(null);
  }

  @override
  Future<Map<String, Object?>> fieldsOf(
    String id,
    Iterable<String> fields,
  ) async {
    final l = lists[id];
    if (l == null) return {};
    return {
      for (final f in fields)
        f: switch (f) {
          'name' => l.name,
          'color' => l.color.apiValue,
          'pinnedToTop' => l.pinnedToTop,
          'hideDone' => l.hideDone,
          'archivedAt' => l.archivedAt?.millisecondsSinceEpoch,
          'deletedAt' => l.deletedAt?.millisecondsSinceEpoch,
          _ => null,
        },
    };
  }

  @override
  Future<void> update(String id, Map<String, Object?> fields) async {
    final o = lists[id]!;
    Object? f(String k, Object? fallback) =>
        fields.containsKey(k) ? fields[k] : fallback;
    DateTime? at(Object? v) =>
        v is int ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true) : null;
    put(
      TaskList(
        id: id,
        name: '${f('name', o.name)}',
        color: NoteColor.fromApi('${f('color', o.color.apiValue)}'),
        sortKey: o.sortKey,
        pinnedToTop: f('pinnedToTop', o.pinnedToTop) == true,
        hideDone: f('hideDone', o.hideDone) == true,
        archivedAt: at(f('archivedAt', o.archivedAt?.millisecondsSinceEpoch)),
        deletedAt: at(f('deletedAt', o.deletedAt?.millisecondsSinceEpoch)),
      ),
    );
  }
}

/// A task with an explicit sort key (`task()` uses the id).
Item keyed(
  String id,
  String listId,
  String text,
  String sortKey, {
  bool done = false,
  int indent = 0,
  ItemKind kind = ItemKind.task,
}) => Item(
  id: id,
  listId: listId,
  kind: kind,
  text: text,
  done: done,
  indent: indent,
  sortKey: sortKey,
);
