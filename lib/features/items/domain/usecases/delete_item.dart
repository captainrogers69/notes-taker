import '../repositories/items_repository.dart';

class DeleteItem {
  const DeleteItem(this._repo);
  final ItemsRepository _repo;

  /// Soft-deletes [id]. Returns the previous `deletedAt` for Undo.
  Future<Map<String, Object?>> call(String id, DateTime now) async {
    final previous = await _repo.fieldsOf(id, const ['deletedAt']);
    await _repo.update(id, {'deletedAt': now.toUtc().millisecondsSinceEpoch});
    return previous;
  }
}
