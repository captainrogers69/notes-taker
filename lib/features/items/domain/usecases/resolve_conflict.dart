import '../../../../core/helpers/fractional_index.dart';
import '../../../../core/ids/new_id.dart';
import '../repositories/items_repository.dart';

enum ConflictChoice { keepBoth, keepMine, keepTheirs }

class ResolveConflict {
  const ResolveConflict(this._repo);
  final ItemsRepository _repo;

  /// Resolves the item's conflict. Returns the previous `text`,
  /// `conflictText` and `conflictFrom` for Undo (plus `createdId` for
  /// keepBoth). Empty when the item is missing or has no conflict.
  ///
  /// The map contains the local-only fields `conflictText`/`conflictFrom`:
  /// Undo must restore those through `ChangeWriter.writeLocalOnly`, not
  /// `update`. The whole resolution runs in one transaction.
  Future<Map<String, Object?>> call(String id, ConflictChoice choice) async {
    final item = await _repo.get(id);
    final conflict = item?.conflict;
    if (item == null || conflict == null) return {};
    return _repo.transaction(() async {
      final previous = await _repo.fieldsOf(id, const [
        'text',
        'conflictText',
        'conflictFrom',
      ]);
      switch (choice) {
        case ConflictChoice.keepMine:
          break;
        case ConflictChoice.keepTheirs:
          await _repo.update(id, {'text': conflict.otherText});
        case ConflictChoice.keepBoth:
          final next = await _repo.sortKeyAfter(item.listId, item.sortKey);
          final newItemId = newId();
          await _repo.update(newItemId, {
            'listId': item.listId,
            'kind': item.kind.name,
            'text': conflict.otherText,
            'done': false,
            'indent': item.indent,
            'sortKey': keyBetween(
              usableKeyOrNull(item.sortKey),
              usableKeyOrNull(next),
            ),
          });
          previous['createdId'] = newItemId;
      }
      await _repo.clearConflict(id);
      return previous;
    });
  }
}
