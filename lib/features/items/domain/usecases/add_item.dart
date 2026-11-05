import 'dart:convert';

import '../../../../core/helpers/fractional_index.dart';
import '../../../../core/helpers/quick_parse.dart';
import '../../../../core/ids/new_id.dart';
import '../entities/reminder_spec.dart';
import '../repositories/items_repository.dart';

class AddItem {
  const AddItem(this._repo);
  final ItemsRepository _repo;

  /// Parses [raw] as a quick-add line and appends a task. Returns the new id.
  /// Throws [ArgumentError] when [raw] is empty or whitespace.
  Future<String> call(String listId, String raw, DateTime now) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(raw, 'raw', 'Empty');
    final parsed = quickParse(trimmed, now);
    final timer = parsed.timerMinutes;
    final due = parsed.due;
    final last = usableKeyOrNull(await _repo.lastSortKey(listId));
    final id = newId();
    await _repo.update(id, {
      'listId': listId,
      'kind': 'task',
      'text': parsed.text.isEmpty ? trimmed : parsed.text,
      'done': false,
      'indent': 0,
      'sortKey': keyBetween(last, null),
      if (due != null) 'dueDate': due.encodeDate(),
      if (due != null) 'dueMinutes': due.minutes,
      if (timer != null)
        'reminders': jsonEncode([
          AtTime(now.add(Duration(minutes: timer))).encode(),
        ]),
    });
    return id;
  }
}
