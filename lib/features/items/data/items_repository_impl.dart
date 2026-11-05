import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/weave_database.dart';
import '../../../core/sync/change_writer.dart';
import '../../../core/sync/entity_type.dart';
import '../domain/entities/due_spec.dart';
import '../domain/entities/item.dart';
import '../domain/entities/item_conflict.dart';
import '../../../core/sync/conflict_losers.dart';
import '../domain/entities/reminder_spec.dart';
import '../domain/entities/repeat_rule.dart';
import '../domain/repositories/items_repository.dart';

// ?1 = today 'yyyy-MM-dd', ?2 = minutes since local midnight.
const _overdue =
    '(i.due_date < ?1 OR (i.due_date = ?1 AND i.due_minutes IS NOT NULL '
    'AND i.due_minutes < ?2))';

const _listOrder =
    '''
ORDER BY
  CASE WHEN i.kind = 'text' THEN 0 WHEN i.done = 0 THEN 1 ELSE 2 END,
  CASE WHEN i.kind = 'task' AND i.done = 0
       THEN (CASE WHEN $_overdue THEN 0
                  WHEN i.due_date IS NOT NULL THEN 1 ELSE 2 END)
       ELSE 0 END,
  CASE WHEN i.kind = 'task' AND i.done = 0 THEN i.due_date END ASC,
  CASE WHEN i.kind = 'task' AND i.done = 0 AND i.due_date IS NOT NULL
       THEN (i.due_minutes IS NULL) END ASC,
  CASE WHEN i.kind = 'task' AND i.done = 0 THEN i.due_minutes END ASC,
  CASE WHEN i.kind = 'text' THEN i.sort_key END ASC,
  CASE WHEN i.kind = 'task' AND i.done = 0 AND i.due_date IS NULL
       THEN i.sort_key END DESC,
  CASE WHEN i.kind = 'task' AND i.done = 0 AND i.due_date IS NULL
       THEN i.id END DESC,
  CASE WHEN i.kind = 'task' AND i.done = 1 THEN i.done_at END DESC,
  i.id ASC
''';

const _dueOrder =
    '''
ORDER BY CASE WHEN $_overdue THEN 0 ELSE 1 END, i.due_date ASC,
         (i.due_minutes IS NULL) ASC, i.due_minutes ASC, i.id ASC
''';

const _liveList = 'l.archived_at IS NULL AND l.deleted_at IS NULL';

class ItemsRepositoryImpl implements ItemsRepository {
  ItemsRepositoryImpl(this._db, this._writer, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WeaveDatabase _db;
  final ChangeWriter _writer;
  final DateTime Function() _clock;

  static String _date(DateTime d) =>
      DueSpec(date: DateTime(d.year, d.month, d.day)).encodeDate();

  Stream<List<Item>> _watch(
    String sql,
    List<Variable> variables, {
    bool withLists = false,
  }) {
    return _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.items, if (withLists) _db.lists},
        )
        .watch()
        .map((rows) => rows.map(_toItem).toList());
  }

  Item _toItem(QueryRow r) {
    final row = _db.items.map(r.data);
    return _fromRow(row);
  }

  Item _fromRow(ItemRow row) {
    final decoded = _decodeList(row.reminders);
    final reminders = <ReminderSpec>[];
    for (final s in decoded) {
      final spec = ReminderSpec.decode(s);
      if (spec != null) reminders.add(spec);
    }
    final rep = row.repeat;
    return Item(
      id: row.id,
      listId: row.listId,
      kind: row.kind == 'text' ? ItemKind.text : ItemKind.task,
      text: row.body,
      done: row.done,
      doneAt: _ms(row.doneAt),
      indent: row.indent,
      sortKey: row.sortKey,
      due: DueSpec.decode(row.dueDate, row.dueMinutes),
      reminders: reminders,
      repeat: rep == null ? null : RepeatRule.decode(rep),
      conflicts: [
        for (final l in decodeLosers(row.conflictText, row.conflictFrom))
          ItemConflict(otherText: l.text, fromDevice: l.from),
      ],
      deletedAt: _ms(row.deletedAt),
    );
  }

  static DateTime? _ms(int? v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);

  static List<String> _decodeList(String json) {
    try {
      final d = jsonDecode(json);
      return d is List ? d.whereType<String>().toList() : const [];
    } on FormatException {
      return const [];
    }
  }

  @override
  Stream<List<Item>> watchList(String listId) {
    // now is fixed at stream creation; callers recreate the stream on a tick.
    return _watch(
      'SELECT i.* FROM items i WHERE i.list_id = ?3 '
      'AND i.deleted_at IS NULL $_listOrder',
      [..._nowVars(_clock()), Variable<String>(listId)],
    );
  }

  List<Variable> _nowVars(DateTime now) => [
    Variable<String>(_date(now)),
    Variable<int>(now.hour * 60 + now.minute),
  ];

  @override
  Stream<List<Item>> watchUpNext(DateTime now) {
    return _watch(
      'SELECT i.* FROM items i JOIN lists l ON l.id = i.list_id '
      "WHERE i.kind = 'task' AND i.done = 0 AND i.deleted_at IS NULL "
      'AND i.due_date IS NOT NULL AND i.due_date <= ?1 AND $_liveList '
      '$_dueOrder',
      _nowVars(now),
      withLists: true,
    );
  }

  @override
  Stream<List<Item>> watchLaterThisWeek(DateTime now) {
    final end = DateTime(now.year, now.month, now.day + 6);
    return _watch(
      'SELECT i.* FROM items i JOIN lists l ON l.id = i.list_id '
      "WHERE i.kind = 'task' AND i.done = 0 AND i.deleted_at IS NULL "
      'AND i.due_date > ?1 AND i.due_date <= ?3 AND $_liveList '
      '$_dueOrder',
      [..._nowVars(now), Variable<String>(_date(end))],
      withLists: true,
    );
  }

  @override
  Stream<List<Item>> search(String q) {
    final t = q.trim();
    if (t.isEmpty) return Stream.value(const []);
    final escaped = t
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return _watch(
      'SELECT i.* FROM items i JOIN lists l ON l.id = i.list_id '
      'WHERE i.deleted_at IS NULL AND l.deleted_at IS NULL '
      "AND i.text LIKE ?1 ESCAPE '\\' "
      'ORDER BY i.list_id ASC, i.sort_key ASC, i.id ASC LIMIT 100',
      [Variable<String>('%$escaped%')],
      withLists: true,
    );
  }

  @override
  Future<Item?> get(String id) async {
    final row = await (_db.select(
      _db.items,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> update(String id, Map<String, Object?> fields) async {
    if (fields.isEmpty) return;
    await _writer.write(EntityType.item, id, fields);
  }

  @override
  Future<Map<String, Object?>> fieldsOf(
    String id,
    Iterable<String> fields,
  ) async {
    final row = await (_db.select(
      _db.items,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return {};
    final all = <String, Object?>{
      'listId': row.listId,
      'kind': row.kind,
      'text': row.body,
      'done': row.done,
      'doneAt': row.doneAt,
      'indent': row.indent,
      'sortKey': row.sortKey,
      'dueDate': row.dueDate,
      'dueMinutes': row.dueMinutes,
      'reminders': row.reminders,
      'repeat': row.repeat,
      'deletedAt': row.deletedAt,
      'conflictText': row.conflictText,
      'conflictFrom': row.conflictFrom,
    };
    return {for (final f in fields) f: all[f]};
  }

  @override
  Future<String?> lastSortKey(String listId) async {
    final row =
        await (_db.select(_db.items)
              ..where((t) => t.listId.equals(listId))
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    return row?.sortKey;
  }

  @override
  Future<String?> sortKeyAfter(String listId, String key) async {
    final row =
        await (_db.select(_db.items)
              ..where(
                (t) =>
                    t.listId.equals(listId) &
                    t.deletedAt.isNull() &
                    t.sortKey.isBiggerThanValue(key),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    return row?.sortKey;
  }

  @override
  Future<String?> sortKeyBefore(String listId, String key) async {
    final row =
        await (_db.select(_db.items)
              ..where(
                (t) =>
                    t.listId.equals(listId) &
                    t.deletedAt.isNull() &
                    t.sortKey.isSmallerThanValue(key),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    return row?.sortKey;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() f) => _db.transaction(f);

  @override
  Future<List<String>> doneTaskIds(String listId) async {
    final rows =
        await (_db.select(_db.items)
              ..where(
                (t) =>
                    t.listId.equals(listId) &
                    t.kind.equals('task') &
                    t.done.equals(true) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    return [for (final r in rows) r.id];
  }

  @override
  Future<void> clearConflict(String id) async {
    final existing = await (_db.select(
      _db.items,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return;
    await _writer.writeLocalOnly(EntityType.item, id, encodeLosers(const []));
  }
}
