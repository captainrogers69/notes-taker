import 'dart:convert';

import '../entities/due_spec.dart';
import '../entities/item.dart';
import '../entities/reminder_spec.dart';
import '../repositories/items_repository.dart';

class ToggleDone {
  const ToggleDone(this._repo);
  final ItemsRepository _repo;

  /// Ticks or unticks a task. Ticking a repeating task moves its due to the
  /// next occurrence and keeps it open; past `AtTime` reminders are dropped.
  /// Returns the previous values of the fields written, for Undo (empty when
  /// the item is missing or is a text line).
  Future<Map<String, Object?>> call(String id, DateTime now) async {
    final item = await _repo.get(id);
    if (item == null || item.kind != ItemKind.task) return {};
    final Map<String, Object?> fields;
    final repeat = item.repeat;
    if (item.done) {
      fields = {'done': false, 'doneAt': null};
    } else if (repeat != null) {
      final from =
          item.due ?? DueSpec(date: DateTime(now.year, now.month, now.day));
      final next = repeat.next(from);
      final kept = item.reminders
          .where((r) => r is! AtTime || !r.local.isBefore(now))
          .map((r) => r.encode())
          .toList();
      fields = {
        'dueDate': next.encodeDate(),
        'dueMinutes': next.minutes,
        'reminders': jsonEncode(kept),
      };
    } else {
      fields = {'done': true, 'doneAt': now.toUtc().millisecondsSinceEpoch};
    }
    final previous = await _repo.fieldsOf(id, fields.keys);
    await _repo.update(id, fields);
    return previous;
  }
}
