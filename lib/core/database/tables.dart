import 'package:drift/drift.dart';

// Defaults here are the single source of truth for rows created from a
// partial write. See the field map in change_writer.dart for field -> column.

@DataClassName('ListRow')
class Lists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Default equals `NoteColor.values.first.apiValue` (covered by a test).
  TextColumn get color => text().withDefault(const Constant('yellow'))();
  TextColumn get sortKey => text().withDefault(const Constant(''))();
  BoolColumn get pinnedToTop => boolean().withDefault(const Constant(false))();
  BoolColumn get hideDone => boolean().withDefault(const Constant(false))();

  /// `yyyy-MM-dd`, local.
  TextColumn get dueDate => text().nullable()();

  /// Minutes after local midnight.
  IntColumn get dueMinutes => integer().nullable()();

  /// Milliseconds since epoch, UTC.
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get deletedAt => integer().nullable()();

  /// JSON map: field -> packed HLC.
  TextColumn get fieldHlcs => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ItemRow')
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().withDefault(const Constant(''))();

  /// `'task'` or `'text'`.
  TextColumn get kind => text().withDefault(const Constant('task'))();

  /// SQL column and synced field are `text`; the Dart getter is `body`
  /// because `text` clashes with `Table.text()`.
  TextColumn get body => text().named('text').withDefault(const Constant(''))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get doneAt => integer().nullable()();

  /// 0 or 1.
  IntColumn get indent => integer().withDefault(const Constant(0))();
  TextColumn get sortKey => text().withDefault(const Constant(''))();
  TextColumn get dueDate => text().nullable()();
  IntColumn get dueMinutes => integer().nullable()();

  /// JSON list of encoded reminder specs.
  TextColumn get reminders => text().withDefault(const Constant('[]'))();
  TextColumn get repeat => text().nullable()();

  /// Local only, never synced.
  TextColumn get conflictText => text().nullable()();
  TextColumn get conflictFrom => text().nullable()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get fieldHlcs => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get changeId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// JSON `{field: {"v": value, "h": packedHlc}}`.
  TextColumn get fields => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {changeId};
}

@DataClassName('KvRow')
class Kv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Device-only mini-bar geometry (D7).
@DataClassName('MiniBarRow')
class MiniBars extends Table {
  TextColumn get listId => text()();
  RealColumn get x => real().nullable()();
  RealColumn get y => real().nullable()();
  RealColumn get w => real().nullable()();
  RealColumn get h => real().nullable()();
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {listId};
}
