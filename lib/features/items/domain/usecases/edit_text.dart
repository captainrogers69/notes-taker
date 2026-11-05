import '../repositories/items_repository.dart';

class EditText {
  const EditText(this._repo);
  final ItemsRepository _repo;

  /// Returns the previous values for Undo.
  Future<Map<String, Object?>> call(String id, String text) async {
    final previous = await _repo.fieldsOf(id, const ['text']);
    await _repo.update(id, {'text': text});
    return previous;
  }
}
