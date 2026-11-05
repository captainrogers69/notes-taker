/// Everything needed to undo "delete forever": the list's synced fields and
/// every item row of the list (including soft-deleted ones). `local` holds
/// the item's never-synced fields (`conflictText`, `conflictFrom`) so an
/// unresolved conflict survives the undo.
class DeletedListSnapshot {
  const DeletedListSnapshot({required this.list, required this.items});

  final Map<String, Object?> list;
  final List<
    ({String id, Map<String, Object?> fields, Map<String, Object?> local})
  >
  items;
}
