import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/helpers/due_label.dart';
import '../../../core/helpers/minute_ticker.dart';
import '../../items/domain/entities/item.dart';
import '../../items/domain/repositories/items_repository.dart';
import '../../items/domain/usecases/toggle_done.dart';
import '../../lists/domain/entities/task_list.dart';
import '../../lists/domain/repositories/lists_repository.dart';

class UpNextState extends Equatable {
  const UpNextState({
    required this.now,
    this.open = const [],
    this.doneToday = const [],
    this.later = const [],
    this.lists = const [],
  });

  /// The minute the page and the thread are drawn for.
  final DateTime now;

  /// Open tasks due today or earlier, overdue first (`watchUpNext`).
  final List<Item> open;

  /// Done tasks due today (`watchDoneToday`).
  final List<Item> doneToday;

  /// Open tasks due in the next 6 days (`watchLaterThisWeek`).
  final List<Item> later;

  /// Active lists, for names and colours.
  final List<TaskList> lists;

  TaskList? listOf(String id) => lists.where((l) => l.id == id).firstOrNull;

  /// The Today card's rows: overdue, upcoming, then done (03 `todayCard`).
  List<Item> get todayRows {
    final late = open.where((i) => _overdue(i)).toList();
    final upcoming = open.where((i) => !_overdue(i)).toList();
    return [...late, ...upcoming, ...doneToday];
  }

  /// Every task due today, open or done: the day thread's marks.
  List<Item> get dueToday {
    final today = DateTime(now.year, now.month, now.day);
    return [...open.where((i) => i.due?.date == today), ...doneToday];
  }

  /// The next open task today that is not overdue and has a time, for the
  /// subline ("next … at 17:00").
  Item? get next {
    final today = DateTime(now.year, now.month, now.day);
    return open
        .where(
          (i) => i.due?.date == today && i.due?.minutes != null && !_overdue(i),
        )
        .firstOrNull;
  }

  bool _overdue(Item i) {
    final due = i.due;
    return due != null && isOverdue(due, now);
  }

  UpNextState copyWith({
    DateTime? now,
    List<Item>? open,
    List<Item>? doneToday,
    List<Item>? later,
    List<TaskList>? lists,
  }) => UpNextState(
    now: now ?? this.now,
    open: open ?? this.open,
    doneToday: doneToday ?? this.doneToday,
    later: later ?? this.later,
    lists: lists ?? this.lists,
  );

  @override
  List<Object?> get props => [now, open, doneToday, later, lists];
}

/// Up next: today across every list, the day thread and later this week.
///
/// The queries fix "now" when they start, so on every wall-clock minute
/// ([MinuteTicker]) the time-based ones are re-created and [UpNextState.now]
/// advances with them; [refresh] (on app resume) re-creates every source.
class UpNextCubit extends Cubit<UpNextState> {
  UpNextCubit({
    required this._items,
    required this._lists,
    required this._toggleDone,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(UpNextState(now: _minute((now ?? DateTime.now)()))) {
    refresh();
    _ticker = MinuteTicker(_watchTimed, now: _now);
  }

  final ItemsRepository _items;
  final ListsRepository _lists;
  final ToggleDone _toggleDone;
  final DateTime Function() _now;
  MinuteTicker? _ticker;
  StreamSubscription<Object?>? _listsSub;
  final _timed = <StreamSubscription<Object?>>[];

  static DateTime _minute(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);

  /// Re-subscribes every source with the current time.
  void refresh() {
    if (isClosed) return;
    unawaited(_listsSub?.cancel());
    _listsSub = _lists.watchActive().listen(
      (l) => _set(state.copyWith(lists: l)),
    );
    _watchTimed();
  }

  void _watchTimed() {
    if (isClosed) return;
    _cancelTimed();
    final now = _minute(_now());
    _set(state.copyWith(now: now));
    _timed.addAll([
      _items.watchUpNext(now).listen((i) => _set(state.copyWith(open: i))),
      _items
          .watchDoneToday(now)
          .listen((i) => _set(state.copyWith(doneToday: i))),
      _items
          .watchLaterThisWeek(now)
          .listen((i) => _set(state.copyWith(later: i))),
    ]);
  }

  /// Ticks or unticks [id]. Returns the previous fields for [restore]
  /// (empty when nothing changed).
  Future<Map<String, Object?>> toggle(String id) => _toggleDone(id, _now());

  /// Undo: writes [previous] back (a ticked task reopens).
  Future<void> restore(String id, Map<String, Object?> previous) =>
      _items.update(id, previous);

  void _set(UpNextState s) {
    if (!isClosed) emit(s);
  }

  void _cancelTimed() {
    for (final s in _timed) {
      unawaited(s.cancel());
    }
    _timed.clear();
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _cancelTimed();
    unawaited(_listsSub?.cancel());
    return super.close();
  }
}
