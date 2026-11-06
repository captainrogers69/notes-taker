import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/note_color_id.dart';
import '../../../core/helpers/due_label.dart';
import '../../../core/helpers/minute_ticker.dart';
import '../../items/domain/entities/item.dart';
import '../../items/domain/repositories/items_repository.dart';
import '../../items/domain/usecases/add_item.dart';
import '../../items/domain/usecases/add_item_below.dart';
import '../../items/domain/usecases/delete_item.dart';
import '../../items/domain/usecases/edit_text.dart';
import '../../items/domain/usecases/indent_item.dart';
import '../../items/domain/usecases/move_item.dart';
import '../../items/domain/usecases/toggle_done.dart';
import '../../items/domain/usecases/uncheck_all.dart';
import '../domain/entities/task_list.dart';
import '../domain/repositories/lists_repository.dart';
import '../domain/usecases/archive_list.dart';
import '../domain/usecases/trash_list.dart';
import '../domain/usecases/update_list.dart';

class ListState extends Equatable {
  const ListState({
    required this.now,
    this.list,
    this.loaded = false,
    this.items = const [],
    this.selectedItemId,
    this.doneOpen = false,
    this.focusId,
    this.inMiniBar = false,
  });

  /// The minute the rows are drawn for.
  final DateTime now;

  /// Null until loaded, or once the list is gone.
  final TaskList? list;
  final bool loaded;

  /// In repository order: text lines, open tasks, done tasks.
  final List<Item> items;

  /// The highlighted row, whose details open beside it (Task 17).
  final String? selectedItemId;

  /// The Done group is open (this screen only).
  final bool doneOpen;

  /// The row that should take keyboard focus.
  final String? focusId;

  /// This list has a mini bar on this device.
  final bool inMiniBar;

  bool get gone =>
      loaded &&
      (list == null || list?.archivedAt != null || list?.deletedAt != null);

  /// Text lines and open tasks: the rows above the add field.
  List<Item> get rows =>
      items.where((i) => i.kind == ItemKind.text || !i.done).toList();

  List<Item> get done =>
      items.where((i) => i.kind == ItemKind.task && i.done).toList();

  List<Item> get open =>
      items.where((i) => i.kind == ItemKind.task && !i.done).toList();

  /// Whether the user can place [i] by hand: the list keeps text lines
  /// first, dated tasks in time order and done tasks by when they were done,
  /// so only untimed open tasks have an order of their own.
  static bool movable(Item i) =>
      i.kind == ItemKind.task && !i.done && i.due == null;

  /// The next timed task that is not overdue (03 `nextUp`).
  Item? get next {
    final timed =
        open
            .where((i) => i.due?.minutes != null && !isOverdue(i.due!, now))
            .toList()
          ..sort((a, b) => a.due!.at()!.compareTo(b.due!.at()!));
    return timed.firstOrNull;
  }

  ListState copyWith({
    DateTime? now,
    TaskList? Function()? list,
    bool? loaded,
    List<Item>? items,
    String? Function()? selectedItemId,
    bool? doneOpen,
    String? Function()? focusId,
    bool? inMiniBar,
  }) => ListState(
    now: now ?? this.now,
    list: list == null ? this.list : list(),
    loaded: loaded ?? this.loaded,
    items: items ?? this.items,
    selectedItemId: selectedItemId == null
        ? this.selectedItemId
        : selectedItemId(),
    doneOpen: doneOpen ?? this.doneOpen,
    focusId: focusId == null ? this.focusId : focusId(),
    inMiniBar: inMiniBar ?? this.inMiniBar,
  );

  @override
  List<Object?> get props => [
    now,
    list,
    loaded,
    items,
    selectedItemId,
    doneOpen,
    focusId,
    inMiniBar,
  ];
}

/// One list's screen. Overdue is fixed when the query starts, so on every
/// wall-clock minute ([MinuteTicker]) and on resume ([refresh]) the query is
/// re-created.
class ListCubit extends Cubit<ListState> {
  ListCubit({
    required this.listId,
    required this._items,
    required this._lists,
    required this._addItem,
    required this._addItemBelow,
    required this._toggleDone,
    required this._editText,
    required this._deleteItem,
    required this._indentItem,
    required this._moveItem,
    required this._uncheckAll,
    required this._updateList,
    required this._archiveList,
    required this._trashList,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(ListState(now: (now ?? DateTime.now)())) {
    _listSub = _lists.watch(listId).listen((l) {
      _set(state.copyWith(list: () => l, loaded: true));
    });
    _barSub = _lists.watchShownInMiniBar().listen((ids) {
      _set(state.copyWith(inMiniBar: ids.contains(listId)));
    });
    refresh();
    _ticker = MinuteTicker(refresh, now: _now);
  }

  final String listId;
  final ItemsRepository _items;
  final ListsRepository _lists;
  final AddItem _addItem;
  final AddItemBelow _addItemBelow;
  final ToggleDone _toggleDone;
  final EditText _editText;
  final DeleteItem _deleteItem;
  final IndentItem _indentItem;
  final MoveItem _moveItem;
  final UncheckAll _uncheckAll;
  final UpdateList _updateList;
  final ArchiveList _archiveList;
  final TrashList _trashList;
  final DateTime Function() _now;

  static const untitled = 'Untitled list';

  final _madeHere = <String>{};
  MinuteTicker? _ticker;
  StreamSubscription<Object?>? _listSub;
  StreamSubscription<Object?>? _barSub;
  StreamSubscription<Object?>? _itemsSub;

  /// Re-reads the items with the current time.
  void refresh() {
    if (isClosed) return;
    unawaited(_itemsSub?.cancel());
    _set(state.copyWith(now: _now()));
    _itemsSub = _items.watchList(listId).listen((i) {
      _set(state.copyWith(items: i));
    });
  }

  // ---- Items ----

  /// Adds a quick-capture line (the add row, or the phone's add bar).
  Future<void> add(String raw) async {
    await _addItem(listId, raw, _now());
  }

  /// Ticks or unticks [id]. Returns the previous fields for [restore].
  Future<Map<String, Object?>> toggle(String id) => _toggleDone(id, _now());

  Future<void> restore(String id, Map<String, Object?> previous) =>
      _items.update(id, previous);

  /// Nothing to do once the row has gone: a write would bring it back.
  Future<void> editText(String id, String text) async {
    if (state.items.any((i) => i.id == id)) await _editText(id, text);
  }

  /// Enter: a blank task under [after], focused. Returns its id.
  Future<String> addBelow(Item after) async {
    final id = await _addItemBelow(after);
    _madeHere.add(id);
    _set(state.copyWith(focusId: () => id));
    return id;
  }

  /// Backspace on an empty row: removes it and focuses the row above.
  Future<void> removeAndGoUp(Item item) async {
    final all = [...state.rows, ...state.done];
    final at = all.indexWhere((i) => i.id == item.id);
    final above = at > 0 ? all[at - 1] : null;
    _set(state.copyWith(focusId: () => above?.id));
    await _deleteItem(item.id, _now());
  }

  /// Whether this screen made [id], with Enter.
  bool madeHere(String id) => _madeHere.contains(id);

  /// Removes [id] without moving focus (a blank row left behind).
  Future<void> removeBlank(String id) => _deleteItem(id, _now());

  Future<void> setIndent(String id, int indent) => _indentItem(id, indent);

  /// Alt+↑ (-1) / Alt+↓ (1): one place among the tasks that have an order.
  /// Untimed tasks show newest first, so up on screen is a higher key.
  Future<void> move(String id, int dir) async {
    final peers = state.rows.where(ListState.movable).toList();
    final at = peers.indexWhere((i) => i.id == id);
    final to = at + dir;
    if (at < 0 || to < 0 || to >= peers.length) return;
    _set(state.copyWith(focusId: () => id));
    if (dir < 0) {
      await _moveItem(id, afterId: peers[to].id);
    } else {
      await _moveItem(id, beforeId: peers[to].id);
    }
  }

  /// A row of [ListState.rows] was dragged from [from] to [to] (its place
  /// once removed). It stays where it was dropped when a movable row is next
  /// to it; otherwise nothing changes.
  Future<void> drop(int from, int to) async {
    final rows = state.rows;
    if (from < 0 || from >= rows.length || from == to) return;
    final item = rows.removeAt(from);
    if (!ListState.movable(item)) return;
    final below = to < rows.length ? rows[to] : null;
    final above = to > 0 ? rows[to - 1] : null;
    final String? afterId;
    final String? beforeId;
    if (below != null && ListState.movable(below)) {
      (afterId, beforeId) = (below.id, null);
    } else if (above != null && ListState.movable(above)) {
      (afterId, beforeId) = (null, above.id);
    } else {
      return;
    }
    // Drawn at once: the row must not hop back until the query answers.
    rows.insert(to, item);
    _set(state.copyWith(items: [...rows, ...state.done]));
    await _moveItem(item.id, afterId: afterId, beforeId: beforeId);
  }

  /// Reopens every done task. Returns what [restoreAll] needs.
  Future<Map<String, Map<String, Object?>>> uncheckAll() => _uncheckAll(listId);

  Future<void> restoreAll(Map<String, Map<String, Object?>> previous) async {
    for (final e in previous.entries) {
      await _items.update(e.key, e.value);
    }
  }

  // ---- Screen ----

  void select(String? id) => _set(state.copyWith(selectedItemId: () => id));

  void toggleDoneOpen() => _set(state.copyWith(doneOpen: !state.doneOpen));

  void focused() => _set(state.copyWith(focusId: () => null));

  // ---- The list ----

  Future<void> rename(String name) async {
    // Once the list has gone, a write would bring it back.
    final current = state.list;
    if (current == null) return;
    final n = name.trim().isEmpty ? untitled : name.trim();
    if (n != current.name) await _updateList(listId, {'name': n});
  }

  Future<void> setColor(NoteColor c) =>
      _updateList(listId, {'color': c.apiValue});

  Future<void> setPinned({required bool pinned}) =>
      _updateList(listId, {'pinnedToTop': pinned});

  Future<void> setHideDone({required bool hide}) =>
      _updateList(listId, {'hideDone': hide});

  Future<void> setMiniBar({required bool shown}) =>
      _lists.setShownInMiniBar(listId, shown: shown);

  /// Returns the previous fields for [restoreList].
  Future<Map<String, Object?>> archive() => _archiveList(listId);

  /// Moves the list to Trash. Returns the previous fields for [restoreList].
  Future<Map<String, Object?>> trash() => _trashList(listId);

  Future<void> restoreList(Map<String, Object?> previous) =>
      _updateList(listId, previous);

  void _set(ListState s) {
    if (!isClosed) emit(s);
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    unawaited(_listSub?.cancel());
    unawaited(_barSub?.cancel());
    unawaited(_itemsSub?.cancel());
    return super.close();
  }
}
