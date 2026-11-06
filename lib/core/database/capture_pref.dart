import 'weave_database.dart';

/// The "New tasks go to" list (design playbook §9 Settings), a device pref
/// in `Kv`. Task 20 builds its setting; until then it is only read. The
/// wipe clears it ([WeaveDatabase.accountPrefKeys]).
const capturePrefKey = 'pref.captureListId';

/// The capture list id, or null when none is set.
Stream<String?> watchCaptureListId(WeaveDatabase db) =>
    (db.select(db.kv)..where((t) => t.key.equals(capturePrefKey)))
        .watchSingleOrNull()
        .map((r) => r?.value);
