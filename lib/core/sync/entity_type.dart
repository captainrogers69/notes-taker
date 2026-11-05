/// Kinds of synced entity.
enum EntityType {
  list('list'),
  item('item');

  const EntityType(this.apiValue);

  final String apiValue;

  static EntityType? fromApi(String? v) {
    for (final t in values) {
      if (t.apiValue == v) return t;
    }
    return null;
  }
}
