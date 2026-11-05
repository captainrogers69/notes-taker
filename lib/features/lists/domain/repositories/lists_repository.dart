import '../../../../core/domain/note_color_id.dart';
import '../entities/deleted_list_snapshot.dart';
import '../entities/task_list.dart';

/// Lists, local DB only. Every ordering is
/// `pinnedToTop DESC, sortKey ASC, id ASC`.
abstract class ListsRepository {
  /// Not archived and not deleted, with open and overdue counts.
  // now is fixed at stream creation; callers recreate the stream on a tick/resume.
  Stream<List<TaskList>> watchActive();
  Stream<List<TaskList>> watchArchived();
  Stream<List<TaskList>> watchTrashed();
  Stream<TaskList?> watch(String id);

  /// Creates a list ordered after the last one; returns its id.
  Future<String> create(String name, NoteColor color);

  /// Synced write of [fields] (see `ChangeWriter`).
  Future<void> update(String id, Map<String, Object?> fields);

  /// Current values of the synced [fields] of list [id] (empty if missing).
  Future<Map<String, Object?>> fieldsOf(String id, Iterable<String> fields);

  /// Snapshots the list and all its items, writes the purge marker
  /// (`deletedAt = 0`), then removes them locally, in one transaction.
  Future<DeletedListSnapshot> deleteForever(String id);

  /// Re-creates a deleted list and its items with fresh HLCs (they beat the
  /// purge marker).
  Future<void> restoreSnapshot(String id, DeletedListSnapshot s);

  /// Hard-deletes lists (and their items) trashed more than 30 days before
  /// [now]. Writes nothing to the outbox. Purge markers are left alone.
  Future<void> purgeTrash(DateTime now);
}
