/// Everything needed to undo "delete forever": the list's synced fields and
/// every item row of the list (including soft-deleted ones).
class DeletedListSnapshot {
  const DeletedListSnapshot({required this.list, required this.items});

  final Map<String, Object?> list;
  final List<({String id, Map<String, Object?> fields})> items;
}
