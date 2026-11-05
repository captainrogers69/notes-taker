import '../repositories/lists_repository.dart';

class UpdateList {
  const UpdateList(this._repo);
  final ListsRepository _repo;

  /// Returns the previous values of [fields] for Undo.
  Future<Map<String, Object?>> call(
    String id,
    Map<String, Object?> fields,
  ) async {
    final previous = await _repo.fieldsOf(id, fields.keys);
    await _repo.update(id, fields);
    return previous;
  }
}
