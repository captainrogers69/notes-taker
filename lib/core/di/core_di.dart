import 'package:get_it/get_it.dart';

import '../../app/app_config.dart';
import '../database/weave_database.dart';
import '../ids/new_id.dart';
import '../sync/change_writer.dart';
import '../sync/hlc.dart';
import '../sync/hlc_clock.dart';
import 'items_di.dart';
import 'lists_di.dart';

final GetIt sl = GetIt.instance;

/// This install's id; also the HLC node. Persisted in `Kv('device.id')`.
class DeviceId {
  const DeviceId(this.value);
  final String value;
}

Future<void> registerCore(GetIt sl, AppConfig config) async {
  final db = WeaveDatabase.open(config.profile);
  final kv = await _readKv(db);
  var deviceId = kv['device.id'];
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = newId();
    await db.customStatement(
      'INSERT OR REPLACE INTO kv (key, value) VALUES (?, ?)',
      ['device.id', deviceId],
    );
  }
  Hlc? seed;
  final last = kv['hlc.last'];
  if (last != null) {
    try {
      seed = Hlc.parse(last);
    } on FormatException {
      seed = null;
    }
  }
  final clock = HlcClock(deviceId, seed: seed);
  sl.registerSingleton<AppConfig>(config);
  sl.registerSingleton<DeviceId>(DeviceId(deviceId));
  sl.registerSingleton<WeaveDatabase>(db);
  sl.registerSingleton<HlcClock>(clock);
  sl.registerSingleton<ChangeWriter>(ChangeWriter(db, clock));
  registerLists(sl);
  registerItems(sl);
}

Future<Map<String, String>> _readKv(WeaveDatabase db) async {
  final rows = await db.select(db.kv).get();
  return {for (final r in rows) r.key: r.value};
}
