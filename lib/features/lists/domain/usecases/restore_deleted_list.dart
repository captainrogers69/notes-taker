import '../entities/deleted_list_snapshot.dart';
import '../repositories/lists_repository.dart';

class RestoreDeletedList {
  const RestoreDeletedList(this._repo);
  final ListsRepository _repo;

  /// Undo of `DeleteListForever`.
  Future<void> call(String id, DeletedListSnapshot snapshot) =>
      _repo.restoreSnapshot(id, snapshot);
}
