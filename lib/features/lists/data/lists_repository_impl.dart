import 'package:drift/drift.dart';

import '../../../core/database/weave_database.dart';
import '../../../core/domain/note_color_id.dart';
import '../../../core/ids/new_id.dart';
import '../../../core/sync/change_writer.dart';
import '../../../core/sync/entity_type.dart';
import '../../../core/helpers/fractional_index.dart';
import '../../items/domain/entities/due_spec.dart';
import '../domain/entities/deleted_list_snapshot.dart';
import '../domain/entities/task_list.dart';
import '../domain/repositories/lists_repository.dart';

const _syncedFields = [
  'name',
  'color',
  'sortKey',
  'pinnedToTop',
  'hideDone',
  'dueDate',
  'dueMinutes',
  'archivedAt',
  'deletedAt',
];

const _order = 'ORDER BY l.pinned_to_top DESC, l.sort_key ASC, l.id ASC';

class ListsRepositoryImpl implements ListsRepository {
  ListsRepositoryImpl(this._db, this._writer, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WeaveDatabase _db;
  final ChangeWriter _writer;
  final DateTime Function() _clock;

  // now is fixed at stream creation; callers recreate the stream on a tick/resume.
  /// One query: lists LEFT JOIN a grouped items subquery. "Now" is read each
  /// time the stream is listened to.
  Stream<List<TaskList>> _watch(String where, {String? id}) {
    final now = _clock();
    final today = DueSpec(
      date: DateTime(now.year, now.month, now.day),
    ).encodeDate();
    final minutes = now.hour * 60 + now.minute;
    return _db
        .customSelect(
          '''
SELECT l.*, COALESCE(c.open_count, 0) AS open_count,
       COALESCE(c.overdue_count, 0) AS overdue_count
FROM lists l
LEFT JOIN (
  SELECT list_id, COUNT(*) AS open_count,
         SUM(CASE WHEN due_date < ?1
                    OR (due_date = ?1 AND due_minutes IS NOT NULL
                        AND due_minutes < ?2)
                  THEN 1 ELSE 0 END) AS overdue_count
  FROM items
  WHERE kind = 'task' AND done = 0 AND deleted_at IS NULL
  GROUP BY list_id
) c ON c.list_id = l.id
WHERE $where
$_order
''',
          variables: [
            Variable<String>(today),
            Variable<int>(minutes),
            if (id != null) Variable<String>(id),
          ],
          readsFrom: {_db.lists, _db.items},
        )
        .watch()
        .map((rows) => rows.map(_toList).toList());
  }

  TaskList _toList(QueryRow r) {
    int? ms(String k) => r.read<int?>(k);
    DateTime? at(String k) {
      final v = ms(k);
      return v == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    }

    return TaskList(
      id: r.read<String>('id'),
      name: r.read<String>('name'),
      color: NoteColor.fromApi(r.read<String>('color')),
      sortKey: r.read<String>('sort_key'),
      pinnedToTop: r.read<bool>('pinned_to_top'),
      hideDone: r.read<bool>('hide_done'),
      due: DueSpec.decode(r.read<String?>('due_date'), ms('due_minutes')),
      archivedAt: at('archived_at'),
      deletedAt: at('deleted_at'),
      openCount: r.read<int>('open_count'),
      overdueCount: r.read<int>('overdue_count'),
    );
  }

  @override
  Stream<List<TaskList>> watchActive() =>
      _watch('l.archived_at IS NULL AND l.deleted_at IS NULL');

  @override
  Stream<List<TaskList>> watchArchived() =>
      _watch('l.archived_at IS NOT NULL AND l.deleted_at IS NULL');

  @override
  Stream<List<TaskList>> watchTrashed() =>
      _watch('l.deleted_at IS NOT NULL AND l.deleted_at > 0');

  @override
  Stream<TaskList?> watch(String id) => _watch(
    'l.id = ?3 AND (l.deleted_at IS NULL OR l.deleted_at > 0)',
    id: id,
  ).map((l) => l.isEmpty ? null : l.first);

  @override
  Future<String> create(String name, NoteColor color) async {
    final last =
        await (_db.select(_db.lists)
              ..orderBy([
                (t) => OrderingTerm.desc(t.sortKey),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    final id = newId();
    await _writer.write(EntityType.list, id, {
      'name': name,
      'color': color.apiValue,
      'sortKey': keyBetween(last?.sortKey, null),
    });
    return id;
  }

  @override
  Future<void> update(String id, Map<String, Object?> fields) async {
    if (fields.isEmpty) return;
    await _writer.write(EntityType.list, id, fields);
  }

  @override
  Future<Map<String, Object?>> fieldsOf(
    String id,
    Iterable<String> fields,
  ) async {
    final row = await (_db.select(
      _db.lists,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return {};
    final all = <String, Object?>{
      'name': row.name,
      'color': row.color,
      'sortKey': row.sortKey,
      'pinnedToTop': row.pinnedToTop,
      'hideDone': row.hideDone,
      'dueDate': row.dueDate,
      'dueMinutes': row.dueMinutes,
      'archivedAt': row.archivedAt,
      'deletedAt': row.deletedAt,
    };
    return {for (final f in fields) f: all[f]};
  }

  @override
  Future<DeletedListSnapshot> deleteForever(String id) {
    return _db.transaction(() async {
      final list = await fieldsOf(id, _syncedFields);
      final rows = await (_db.select(
        _db.items,
      )..where((t) => t.listId.equals(id))).get();
      final items = [
        for (final r in rows)
          (
            id: r.id,
            fields: <String, Object?>{
              'listId': r.listId,
              'kind': r.kind,
              'text': r.body,
              'done': r.done,
              'doneAt': r.doneAt,
              'indent': r.indent,
              'sortKey': r.sortKey,
              'dueDate': r.dueDate,
              'dueMinutes': r.dueMinutes,
              'reminders': r.reminders,
              'repeat': r.repeat,
              'deletedAt': r.deletedAt,
            },
          ),
      ];
      await _writer.write(EntityType.list, id, {'deletedAt': 0});
      await (_db.delete(_db.items)..where((t) => t.listId.equals(id))).go();
      await (_db.delete(_db.lists)..where((t) => t.id.equals(id))).go();
      return DeletedListSnapshot(list: list, items: items);
    });
  }

  @override
  Future<void> restoreSnapshot(String id, DeletedListSnapshot s) {
    return _db.transaction(() async {
      await _writer.write(EntityType.list, id, s.list);
      for (final item in s.items) {
        await _writer.write(EntityType.item, item.id, item.fields);
      }
    });
  }

  @override
  Future<void> purgeTrash(DateTime now) async {
    final cutoff =
        now.millisecondsSinceEpoch - const Duration(days: 30).inMilliseconds;
    await _db.transaction(() async {
      final old = _db.selectOnly(_db.lists)
        ..addColumns([_db.lists.id])
        ..where(
          _db.lists.deletedAt.isBiggerThanValue(0) &
              _db.lists.deletedAt.isSmallerThanValue(cutoff),
        );
      await (_db.delete(_db.items)..where((t) => t.listId.isInQuery(old))).go();
      await (_db.delete(_db.lists)..where(
            (t) =>
                t.deletedAt.isBiggerThanValue(0) &
                t.deletedAt.isSmallerThanValue(cutoff),
          ))
          .go();
    });
  }
}
