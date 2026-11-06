import 'package:get_it/get_it.dart';

import '../../app/app_config.dart';
import '../database/weave_database.dart';
import '../ids/new_id.dart';
import '../sync/bulk_uploader.dart';
import '../sync/change_writer.dart';
import '../sync/hlc.dart';
import '../sync/hlc_clock.dart';
import '../sync/outbox_gate.dart';
import 'items_di.dart';
import 'lists_di.dart';

final GetIt sl = GetIt.instance;

/// This install's id; also the HLC node. Persisted in `Kv('device.id')`.
///
/// One instance for the app's lifetime; [renewDeviceIdentity] changes its
/// [value] together with the clock's node. Sync objects read it when
/// `registerSync` creates them.
class DeviceId {
  DeviceId(this._value);

  String _value;

  String get value => _value;
}

Future<void> registerCore(GetIt sl, AppConfig config) async {
  sl.registerSingleton<AppConfig>(config);
  await registerCoreWith(sl, WeaveDatabase.open(config.profile));
}

/// Registers the database, device identity, clock, writer, outbox gate and
/// the lists / items features. Tests pass an in-memory [db].
///
/// The [OutboxGate] starts on exactly when the data has an owner
/// (`Kv('account.user')`); `SessionCubit` keeps it in step afterwards.
Future<void> registerCoreWith(GetIt sl, WeaveDatabase db) async {
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
  sl.registerSingleton<WeaveDatabase>(db);
  // The gate follows the owner key (see SessionCubit): set before the app
  // takes input, so an edit made before the session is restored is queued.
  sl.registerSingleton<OutboxGate>(
    OutboxGate(enabled: kv[BulkUploader.ownerKey] != null),
  );
  _registerIdentity(sl, deviceId, seed);
  registerLists(sl);
  registerItems(sl);
}

void _registerIdentity(GetIt sl, String deviceId, Hlc? seed) {
  final clock = HlcClock(deviceId, seed: seed);
  final gate = sl<OutboxGate>();
  sl.registerSingleton<DeviceId>(DeviceId(deviceId));
  sl.registerSingleton<HlcClock>(clock);
  sl.registerSingleton<ChangeWriter>(
    ChangeWriter(sl<WeaveDatabase>(), clock, outboxEnabled: () => gate.enabled),
  );
}

/// Gives this install a new device id after sign-out (call after
/// `unregisterSync` and `db.wipe()`, before `registerSync`).
///
/// The id lives in `Kv('device.id')`; the wipe cleared it (and `hlc.last`).
/// This writes a fresh `newId()` there and switches the one [DeviceId] and
/// the one [HlcClock] (`HlcClock.renew`) to it. The clock keeps its millis
/// and counter, so new stamps sort after every stamp of the old id; the
/// renewed `last` is persisted as `hlc.last` so a restart keeps that.
/// [ChangeWriter] and the repositories hold the same clock, so they write
/// with the new node without being re-created.
Future<void> renewDeviceIdentity(GetIt sl) async {
  final db = sl<WeaveDatabase>();
  final clock = sl<HlcClock>();
  final id = newId();
  clock.renew(id);
  sl<DeviceId>()._value = id;
  await db.transaction(() async {
    for (final e in {'device.id': id, 'hlc.last': clock.last.pack()}.entries) {
      await db.customStatement(
        'INSERT OR REPLACE INTO kv (key, value) VALUES (?, ?)',
        [e.key, e.value],
      );
    }
  });
}

Future<Map<String, String>> _readKv(WeaveDatabase db) async {
  final rows = await db.select(db.kv).get();
  return {for (final r in rows) r.key: r.value};
}
