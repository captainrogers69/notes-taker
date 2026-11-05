import 'package:equatable/equatable.dart';
import 'package:weave/features/items/domain/entities/due_spec.dart';
import 'package:weave/features/items/domain/entities/item_conflict.dart';
import 'package:weave/features/items/domain/entities/reminder_spec.dart';
import 'package:weave/features/items/domain/entities/repeat_rule.dart';

enum ItemKind { task, text }

class Item extends Equatable {
  const Item({
    required this.id,
    required this.listId,
    required this.kind,
    required this.text,
    required this.done,
    required this.indent,
    required this.sortKey,
    this.doneAt,
    this.due,
    this.reminders = const [],
    this.repeat,
    this.conflict,
    this.deletedAt,
  });

  final String id;
  final String listId;
  final ItemKind kind;
  final String text;
  final bool done;
  final DateTime? doneAt;
  final int indent;
  final String sortKey;
  final DueSpec? due;
  final List<ReminderSpec> reminders;
  final RepeatRule? repeat;
  final ItemConflict? conflict;
  final DateTime? deletedAt;

  @override
  List<Object?> get props => [
    id,
    listId,
    kind,
    text,
    done,
    doneAt,
    indent,
    sortKey,
    due,
    reminders,
    repeat,
    conflict,
    deletedAt,
  ];
}
