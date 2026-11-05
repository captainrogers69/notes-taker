import '../../../../core/domain/note_color_id.dart';
import '../repositories/lists_repository.dart';

class CreateList {
  const CreateList(this._repo);
  final ListsRepository _repo;

  /// Returns the new list id.
  Future<String> call(String name, NoteColor color) =>
      _repo.create(name, color);
}
