import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/helpers/minute_ticker.dart';
import '../../features/items/domain/repositories/items_repository.dart';
import '../../features/lists/domain/entities/task_list.dart';
import '../../features/lists/domain/repositories/lists_repository.dart';

class ShellState extends Equatable {
  const ShellState({
    this.lists = const [],
    this.upNextCount = 0,
    this.archiveTrashCount = 0,
    this.shownInMiniBar = const {},
    this.deviceCount = 1,
  });

  /// Active lists in sidebar order (pinned first), with open counts.
  final List<TaskList> lists;

  /// Open tasks due today or earlier: the Up next row and tab badge.
  final int upNextCount;

  /// Archived plus trashed lists.
  final int archiveTrashCount;

  /// Lists with a mini bar on this device (screen icon, note paper).
  final Set<String> shownInMiniBar;

  /// Devices on the account, for "Synced · N devices" (at least 1).
  final int deviceCount;

  ShellState copyWith({
    List<TaskList>? lists,
    int? upNextCount,
    int? archiveTrashCount,
    Set<String>? shownInMiniBar,
    int? deviceCount,
  }) => ShellState(
    lists: lists ?? this.lists,
    upNextCount: upNextCount ?? this.upNextCount,
    archiveTrashCount: archiveTrashCount ?? this.archiveTrashCount,
    shownInMiniBar: shownInMiniBar ?? this.shownInMiniBar,
    deviceCount: deviceCount ?? this.deviceCount,
  );

  @override
  List<Object?> get props => [
    lists,
    upNextCount,
    archiveTrashCount,
    shownInMiniBar,
    deviceCount,
  ];
}

/// What the sidebar and the tab bar count. The Up next count reads "now"
/// when its stream starts, so it is re-created on every wall-clock minute;
/// [refresh] (the shell calls it on app resume) re-creates every source.
class ShellCubit extends Cubit<ShellState> {
  ShellCubit({
    required this._lists,
    required this._items,
    this._deviceCount,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const ShellState()) {
    refresh();
    _ticker = MinuteTicker(_watchUpNext, now: _now);
  }

  final ListsRepository _lists;
  final ItemsRepository _items;
  final Stream<int> Function()? _deviceCount;
  final DateTime Function() _now;
  MinuteTicker? _ticker;
  final _subs = <StreamSubscription<Object?>>[];
  StreamSubscription<Object?>? _upNext;
  var _archived = 0;
  var _trashed = 0;

  /// Re-subscribes every source, so time-based values use the current
  /// time.
  void refresh() {
    if (isClosed) return;
    _cancel();
    final devices = _deviceCount?.call();
    _watchUpNext();
    _subs.addAll([
      _lists.watchActive().listen((l) => _set(state.copyWith(lists: l))),
      _lists.watchArchived().listen((l) {
        _archived = l.length;
        _set(state.copyWith(archiveTrashCount: _archived + _trashed));
      }),
      _lists.watchTrashed().listen((l) {
        _trashed = l.length;
        _set(state.copyWith(archiveTrashCount: _archived + _trashed));
      }),
      _lists.watchShownInMiniBar().listen(
        (ids) => _set(state.copyWith(shownInMiniBar: ids)),
      ),
      if (devices != null)
        devices.listen((n) => _set(state.copyWith(deviceCount: n < 1 ? 1 : n))),
    ]);
  }

  /// Open tasks due today or earlier, as of now.
  void _watchUpNext() {
    if (isClosed) return;
    unawaited(_upNext?.cancel());
    _upNext = _items
        .watchUpNext(_now())
        .listen((i) => _set(state.copyWith(upNextCount: i.length)));
  }

  void _set(ShellState s) {
    if (!isClosed) emit(s);
  }

  void _cancel() {
    unawaited(_upNext?.cancel());
    _upNext = null;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _cancel();
    return super.close();
  }
}
