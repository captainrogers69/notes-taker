import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/helpers/quick_parse.dart';
import '../../items/domain/usecases/add_item.dart';
import '../../lists/domain/entities/task_list.dart';
import '../../lists/domain/repositories/lists_repository.dart';

class CaptureState extends Equatable {
  const CaptureState({this.lists = const [], this.prefListId, this.picked});

  /// Active lists, in sidebar order: the chip's choices.
  final List<TaskList> lists;

  /// The "New tasks go to" pref (Task 20), if set.
  final String? prefListId;

  /// The list picked on the chip, kept while the field lives.
  final String? picked;

  bool _active(String? id) => id != null && lists.any((l) => l.id == id);

  /// Where Enter adds: the picked list, else the pref, else the first list
  /// (null when there are no lists). A list that went away falls back.
  String? get listId => _active(picked)
      ? picked
      : _active(prefListId)
      ? prefListId
      : lists.firstOrNull?.id;

  TaskList? get list => lists.where((l) => l.id == listId).firstOrNull;

  CaptureState copyWith({
    List<TaskList>? lists,
    String? Function()? prefListId,
    String? Function()? picked,
  }) => CaptureState(
    lists: lists ?? this.lists,
    prefListId: prefListId == null ? this.prefListId : prefListId(),
    picked: picked == null ? this.picked : picked(),
  );

  @override
  List<Object?> get props => [lists, prefListId, picked];
}

/// What a capture added, for the toast ("Added to Work · Due Tomorrow
/// 18:00").
class Captured {
  const Captured(this.listName, this.readBack);

  final String listName;

  /// [parseReadBack] of the line; empty when it had no date or time.
  final String readBack;

  String get message => readBack.isEmpty
      ? 'Added to $listName'
      : 'Added to $listName · $readBack';
}

/// Up next's quick capture (the Today card field on desktop, the add bar on
/// phones): which list Enter adds to, and the add itself.
class CaptureCubit extends Cubit<CaptureState> {
  CaptureCubit({
    required ListsRepository lists,
    required this._addItem,
    required Stream<String?> Function() capturePref,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const CaptureState()) {
    _subs.addAll([
      lists.watchActive().listen((l) => _set(state.copyWith(lists: l))),
      capturePref().listen((id) => _set(state.copyWith(prefListId: () => id))),
    ]);
  }

  final AddItem _addItem;
  final DateTime Function() _now;
  final _subs = <StreamSubscription<Object?>>[];

  void pick(String listId) => _set(state.copyWith(picked: () => listId));

  /// Adds [raw] to [CaptureState.listId]. Null when there is nothing to
  /// add or no list to add it to.
  Future<Captured?> add(String raw) async {
    final list = state.list;
    if (list == null || raw.trim().isEmpty) return null;
    final now = _now();
    await _addItem(list.id, raw, now);
    return Captured(list.name, parseReadBack(quickParse(raw.trim(), now), now));
  }

  void _set(CaptureState s) {
    if (!isClosed) emit(s);
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
