import '../entities/repeat_rule.dart';
import '../repositories/items_repository.dart';

class SetRepeat {
  const SetRepeat(this._repo);
  final ItemsRepository _repo;

  Future<Map<String, Object?>> call(String id, RepeatRule? rule) async {
    final previous = await _repo.fieldsOf(id, const ['repeat']);
    await _repo.update(id, {'repeat': rule?.encode()});
    return previous;
  }
}
