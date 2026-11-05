import '../repositories/items_repository.dart';

class UncheckAll {
  const UncheckAll(this._repo);
  final ItemsRepository _repo;

  /// Unticks every done task in [listId] (one write each). Returns each
  /// item's previous `done`/`doneAt` keyed by id, for Undo.
  Future<Map<String, Map<String, Object?>>> call(String listId) async {
    final previous = <String, Map<String, Object?>>{};
    for (final id in await _repo.doneTaskIds(listId)) {
      previous[id] = await _repo.fieldsOf(id, const ['done', 'doneAt']);
      await _repo.update(id, {'done': false, 'doneAt': null});
    }
    return previous;
  }
}
