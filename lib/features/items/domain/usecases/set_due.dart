import '../entities/due_spec.dart';
import '../repositories/items_repository.dart';

class SetDue {
  const SetDue(this._repo);
  final ItemsRepository _repo;

  /// Sets or clears the due. Reminders are untouched: `Before` offsets follow
  /// the new due. Returns the previous values for Undo.
  Future<Map<String, Object?>> call(String id, DueSpec? due) async {
    const keys = ['dueDate', 'dueMinutes'];
    final previous = await _repo.fieldsOf(id, keys);
    await _repo.update(id, {
      'dueDate': due?.encodeDate(),
      'dueMinutes': due?.minutes,
    });
    return previous;
  }
}
