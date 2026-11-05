import 'dart:convert';

import '../entities/reminder_spec.dart';
import '../repositories/items_repository.dart';

class SetReminders {
  const SetReminders(this._repo);
  final ItemsRepository _repo;

  Future<Map<String, Object?>> call(
    String id,
    List<ReminderSpec> reminders,
  ) async {
    final previous = await _repo.fieldsOf(id, const ['reminders']);
    await _repo.update(id, {
      'reminders': jsonEncode([for (final r in reminders) r.encode()]),
    });
    return previous;
  }
}
