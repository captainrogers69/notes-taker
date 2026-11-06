import '../entities/item.dart';

/// Local-only access to items. Every write is a synced field write.
abstract class ItemsRepository {
  /// Text lines first (by sortKey), then open tasks (overdue, due ascending,
  /// then undated newest first), then done tasks by doneAt descending.
  Stream<List<Item>> watchList(String listId);

  /// Open tasks due today or earlier from lists that are neither archived nor
  /// deleted. "Now" is fixed when the stream is created.
  Stream<List<Item>> watchUpNext(DateTime now);

  /// Done tasks due today from lists that are neither archived nor deleted,
  /// by due time (untimed last). Up next keeps them at the end of Today,
  /// struck through, and as hollow marks on the day thread.
  Stream<List<Item>> watchDoneToday(DateTime now);

  /// Open tasks due after today and within 6 days.
  Stream<List<Item>> watchLaterThisWeek(DateTime now);

  /// Case-insensitive substring match, at most 100 results.
  Stream<List<Item>> search(String q);

  Future<Item?> get(String id);

  /// Writes [fields] as one synced change. An empty map is a no-op.
  Future<void> update(String id, Map<String, Object?> fields);

  /// Current values of [fields] (synced or conflict fields) for Undo. Empty
  /// map when the item does not exist.
  Future<Map<String, Object?>> fieldsOf(String id, Iterable<String> fields);

  /// Largest sortKey in [listId], or null when the list has no items.
  Future<String?> lastSortKey(String listId);

  /// Smallest sortKey among non-deleted items of [listId] strictly greater
  /// than [key], or null.
  Future<String?> sortKeyAfter(String listId, String key);

  /// Largest sortKey among non-deleted items of [listId] strictly less than
  /// [key], or null.
  Future<String?> sortKeyBefore(String listId, String key);

  /// Runs [f] in one database transaction (nests with ChangeWriter's own).
  Future<T> transaction<T>(Future<T> Function() f);

  /// Ids of done, non-deleted tasks in [listId].
  Future<List<String>> doneTaskIds(String listId);

  /// Clears every conflict loser (local only). No-op if [id] is missing.
  Future<void> clearConflict(String id);
}
