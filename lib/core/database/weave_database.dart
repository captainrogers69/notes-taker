import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'weave_database.g.dart';

@DriftDatabase(tables: [Lists, Items, Outbox, Kv, MiniBars])
class WeaveDatabase extends _$WeaveDatabase {
  WeaveDatabase(super.e);

  /// In-memory database for tests.
  WeaveDatabase.memory() : super(NativeDatabase.memory());

  /// File database `weave_<profile>.sqlite` in the app support directory.
  static WeaveDatabase open(String profile) {
    return WeaveDatabase(
      LazyDatabase(() async {
        final dir = await getApplicationSupportDirectory();
        final file = File(p.join(dir.path, 'weave_$profile.sqlite'));
        return NativeDatabase.createInBackground(file);
      }),
    );
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // Returns a row for file DBs; harmless (returns "memory") in memory.
      await customSelect('PRAGMA journal_mode=WAL').get();
    },
  );

  /// Clears every table.
  Future<void> wipe() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });
}
