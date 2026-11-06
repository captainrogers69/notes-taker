import '../../../../core/helpers/fractional_index.dart';
import '../../../../core/ids/new_id.dart';
import '../entities/item.dart';
import '../repositories/items_repository.dart';

class AddItemBelow {
  const AddItemBelow(this._repo);
  final ItemsRepository _repo;

  /// Adds a blank task right under [after] on screen, with its indent.
  /// Untimed open tasks show newest first (a higher key is higher up), so
  /// under one means just below its key; under anything else the new task
  /// starts the untimed tasks. Returns the new id.
  Future<String> call(Item after) async {
    final String key;
    if (after.kind == ItemKind.task && !after.done && after.due == null) {
      final hi = usableKeyOrNull(after.sortKey);
      final lo = hi == null
          ? null
          : usableKeyOrNull(await _repo.sortKeyBefore(after.listId, hi));
      key = keyBetween(lo, hi);
    } else {
      key = keyBetween(
        usableKeyOrNull(await _repo.lastSortKey(after.listId)),
        null,
      );
    }
    final id = newId();
    await _repo.update(id, {
      'listId': after.listId,
      'kind': 'task',
      'text': '',
      'done': false,
      'indent': after.indent,
      'sortKey': key,
    });
    return id;
  }
}
