import '../repositories/lists_repository.dart';

class RestoreList {
  const RestoreList(this._repo);
  final ListsRepository _repo;

  /// Clears `deletedAt` and `archivedAt`. Returns the previous values for Undo.
  Future<Map<String, Object?>> call(String id) async {
    final previous = await _repo.fieldsOf(id, const [
      'deletedAt',
      'archivedAt',
    ]);
    await _repo.update(id, {'deletedAt': null, 'archivedAt': null});
    return previous;
  }
}
