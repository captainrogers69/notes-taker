import '../repositories/lists_repository.dart';

class ArchiveList {
  ArchiveList(this._repo, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final ListsRepository _repo;
  final DateTime Function() _clock;

  /// Returns the previous field values for Undo.
  Future<Map<String, Object?>> call(String id) async {
    final previous = await _repo.fieldsOf(id, const ['archivedAt']);
    await _repo.update(id, {'archivedAt': _clock().millisecondsSinceEpoch});
    return previous;
  }
}
