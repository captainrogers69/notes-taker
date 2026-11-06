import 'package:drift/drift.dart';

import '../database/weave_database.dart';

/// Local cache of device names, for conflict labels. Read inside the merge
/// transaction, so it never touches the network. Task 12 fills it from the
/// devices table via [upsert]; this device's own name is always known.
class DeviceNames {
  DeviceNames(this._db, {required this.selfId, required this.selfName});

  /// Shown for a device whose name is not cached yet.
  static const fallback = 'Another device';

  static String key(String deviceId) => 'device.name.$deviceId';

  /// How many devices the cache knows (this one included once the devices
  /// table was read). For "Synced · N devices": local, no network; the
  /// wipe at sign-out clears it.
  static Stream<int> watchCount(WeaveDatabase db) {
    final count = db.kv.key.count();
    return (db.selectOnly(db.kv)
          ..addColumns([count])
          ..where(db.kv.key.like('device.name.%')))
        .map((r) => r.read(count) ?? 0)
        .watchSingle();
  }

  final WeaveDatabase _db;
  final String selfId;
  final String selfName;

  Future<String> nameOf(String deviceId) async {
    if (deviceId == selfId && selfName.isNotEmpty) return selfName;
    final row = await (_db.select(
      _db.kv,
    )..where((t) => t.key.equals(key(deviceId)))).getSingleOrNull();
    final name = row?.value;
    return name == null || name.isEmpty ? fallback : name;
  }

  /// Stores device id → name. Empty names are skipped.
  Future<void> upsert(Map<String, String> names) => _db.transaction(() async {
    for (final e in names.entries) {
      if (e.value.isEmpty) continue;
      await _db
          .into(_db.kv)
          .insertOnConflictUpdate(
            KvCompanion.insert(key: key(e.key), value: e.value),
          );
    }
  });
}
