import '../repositories/items_repository.dart';

class IndentItem {
  const IndentItem(this._repo);
  final ItemsRepository _repo;

  /// [indent] is 0 or 1. Returns the previous value for Undo.
  Future<Map<String, Object?>> call(String id, int indent) async {
    if (indent != 0 && indent != 1) {
      throw ArgumentError.value(indent, 'indent', 'Must be 0 or 1');
    }
    final previous = await _repo.fieldsOf(id, const ['indent']);
    await _repo.update(id, {'indent': indent});
    return previous;
  }
}
