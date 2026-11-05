import '../entities/deleted_list_snapshot.dart';
import '../repositories/lists_repository.dart';

class DeleteListForever {
  const DeleteListForever(this._repo);
  final ListsRepository _repo;

  /// Returns the snapshot that `RestoreDeletedList` needs for Undo.
  Future<DeletedListSnapshot> call(String id) => _repo.deleteForever(id);
}
