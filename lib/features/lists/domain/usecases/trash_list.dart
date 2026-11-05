import '../repositories/lists_repository.dart';

class TrashList {
  TrashList(this._repo, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final ListsRepository _repo;
  final DateTime Function() _clock;

  /// Returns the previous field values for Undo.
  Future<Map<String, Object?>> call(String id) async {
    final previous = await _repo.fieldsOf(id, const ['deletedAt']);
    await _repo.update(id, {'deletedAt': _clock().millisecondsSinceEpoch});
    return previous;
  }
}
