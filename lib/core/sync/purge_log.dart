import '../database/weave_database.dart';

/// Kv key remembering that [id] (a list or an item) was deleted forever, so
/// late or replayed changes never bring it back.
String purgedKey(String id) => 'purged.$id';

/// Records [ids] as purged.
Future<void> markPurged(WeaveDatabase db, Iterable<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.kv)
        .insertOnConflictUpdate(
          KvCompanion.insert(key: purgedKey(id), value: '1'),
        );
  }
}

/// Forgets that [ids] were purged (undo of delete forever).
Future<void> unmarkPurged(WeaveDatabase db, Iterable<String> ids) async {
  final keys = [for (final id in ids) purgedKey(id)];
  await (db.delete(db.kv)..where((t) => t.key.isIn(keys))).go();
}

Future<bool> isPurged(WeaveDatabase db, String id) async {
  final row = await (db.select(
    db.kv,
  )..where((t) => t.key.equals(purgedKey(id)))).getSingleOrNull();
  return row != null;
}

/// Drops not-yet-pushed outbox rows for [ids]: edits to a purged entity are
/// pointless and must not be sent.
Future<void> dropPending(WeaveDatabase db, Iterable<String> ids) async {
  final list = ids.toList();
  if (list.isEmpty) return;
  await (db.delete(db.outbox)..where((t) => t.entityId.isIn(list))).go();
}

/// Hard-deletes a list with its items and mini bar, or (with [itemId]) one
/// item. Does not record the purge; see [markPurged].
Future<void> deletePurgedRows(
  WeaveDatabase db, {
  String? listId,
  String? itemId,
}) async {
  if (listId != null) {
    await (db.delete(db.miniBars)..where((t) => t.listId.equals(listId))).go();
    await (db.delete(db.items)..where((t) => t.listId.equals(listId))).go();
    await (db.delete(db.lists)..where((t) => t.id.equals(listId))).go();
  }
  if (itemId != null) {
    await (db.delete(db.items)..where((t) => t.id.equals(itemId))).go();
  }
}
