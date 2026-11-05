import '../../../../core/helpers/fractional_index.dart';
import '../repositories/lists_repository.dart';

class ReorderList {
  const ReorderList(this._repo);
  final ListsRepository _repo;

  /// Moves list [id] between neighbours with sort keys [before] and [after]
  /// (null at either end). Returns the previous `sortKey` for Undo.
  Future<Map<String, Object?>> call(
    String id, {
    required String? before,
    required String? after,
  }) async {
    final previous = await _repo.fieldsOf(id, const ['sortKey']);
    await _repo.update(id, {'sortKey': keyBetween(before, after)});
    return previous;
  }
}
