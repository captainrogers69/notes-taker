import '../../../../core/helpers/fractional_index.dart';
import '../repositories/items_repository.dart';

class MoveItem {
  const MoveItem(this._repo);
  final ItemsRepository _repo;

  /// Moves [id] right after [afterId]; when only [beforeId] is given, right
  /// before it; with neither, to an arbitrary open position. The new key is
  /// computed from the neighbours' actual sort keys in the list, so equal
  /// keys (from concurrent devices) never make it throw. Returns the previous
  /// `sortKey` for Undo; empty when [id] or a named neighbour is missing.
  Future<Map<String, Object?>> call(
    String id, {
    String? afterId,
    String? beforeId,
  }) async {
    final own = await _repo.fieldsOf(id, const ['listId', 'sortKey']);
    final listId = own['listId'];
    if (listId is! String) return {};
    final String? lo;
    final String? hi;
    if (afterId != null) {
      final f = await _repo.fieldsOf(afterId, const ['sortKey']);
      if (f.isEmpty) return {};
      final k = f['sortKey'];
      lo = usableKeyOrNull(k is String ? k : null);
      hi = usableKeyOrNull(
        lo == null ? null : await _repo.sortKeyAfter(listId, lo),
      );
    } else if (beforeId != null) {
      final f = await _repo.fieldsOf(beforeId, const ['sortKey']);
      if (f.isEmpty) return {};
      final k = f['sortKey'];
      hi = usableKeyOrNull(k is String ? k : null);
      lo = usableKeyOrNull(
        hi == null ? null : await _repo.sortKeyBefore(listId, hi),
      );
    } else {
      lo = null;
      hi = null;
    }
    await _repo.update(id, {'sortKey': keyBetween(lo, hi)});
    return {'sortKey': own['sortKey']};
  }
}
