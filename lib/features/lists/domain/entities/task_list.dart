import 'package:equatable/equatable.dart';
import 'package:weave/core/domain/note_color_id.dart';
import 'package:weave/features/items/domain/entities/due_spec.dart';

class TaskList extends Equatable {
  const TaskList({
    required this.id,
    required this.name,
    required this.color,
    required this.sortKey,
    required this.pinnedToTop,
    required this.hideDone,
    this.due,
    this.archivedAt,
    this.deletedAt,
    this.openCount = 0,
    this.overdueCount = 0,
    this.nextDue,
  });

  final String id;
  final String name;
  final NoteColor color;
  final String sortKey;
  final bool pinnedToTop;
  final bool hideDone;
  final DueSpec? due;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  /// Filled in by queries.
  final int openCount;
  final int overdueCount;

  /// The earliest timed open task that is not overdue.
  final DueSpec? nextDue;

  @override
  List<Object?> get props => [
    id,
    name,
    color,
    sortKey,
    pinnedToTop,
    hideDone,
    due,
    archivedAt,
    deletedAt,
    openCount,
    overdueCount,
    nextDue,
  ];
}
