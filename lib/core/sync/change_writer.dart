import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/weave_database.dart';
import '../ids/new_id.dart';
import 'entity_type.dart';
import 'hlc_clock.dart';

enum _T { text, int, bool }

/// Field -> (column, type) maps. The field name is the Dart column name;
/// `id`, `fieldHlcs`, `conflictText` and `conflictFrom` are never synced.
/// Defaults for columns omitted on create live in `tables.dart`.
const _listFields = <String, (String, _T)>{
  'name': ('name', _T.text),
  'color': ('color', _T.text),
  'sortKey': ('sort_key', _T.text),
  'pinnedToTop': ('pinned_to_top', _T.bool),
  'hideDone': ('hide_done', _T.bool),
  'dueDate': ('due_date', _T.text),
  'dueMinutes': ('due_minutes', _T.int),
  'archivedAt': ('archived_at', _T.int),
  'deletedAt': ('deleted_at', _T.int),
};

const _itemFields = <String, (String, _T)>{
  'listId': ('list_id', _T.text),
  'kind': ('kind', _T.text),
  'text': ('text', _T.text),
  'done': ('done', _T.bool),
  'doneAt': ('done_at', _T.int),
  'indent': ('indent', _T.int),
  'sortKey': ('sort_key', _T.text),
  'dueDate': ('due_date', _T.text),
  'dueMinutes': ('due_minutes', _T.int),
  'reminders': ('reminders', _T.text),
  'repeat': ('repeat', _T.text),
  'deletedAt': ('deleted_at', _T.int),
};

const _itemLocalFields = <String, (String, _T)>{
  'conflictText': ('conflict_text', _T.text),
  'conflictFrom': ('conflict_from', _T.text),
};

/// Applies synced writes: row, per-field HLCs and outbox entry in one
/// transaction.
class ChangeWriter {
  ChangeWriter(this._db, this._clock, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final WeaveDatabase _db;
  final HlcClock _clock;
  final int Function() _now;

  Map<String, (String, _T)> _map(EntityType t) =>
      t == EntityType.list ? _listFields : _itemFields;

  String _table(EntityType t) => t == EntityType.list ? 'lists' : 'items';

  /// Upserts [id] with [fields]. Every field shares one HLC. Throws
  /// [ArgumentError] (and changes nothing) on an unknown field or a value of
  /// the wrong type.
  Future<void> write(EntityType type, String id, Map<String, Object?> fields) {
    return _db.transaction(() async {
      final map = _map(type);
      final hlc = _clock.tick().pack();
      final values = _values(map, fields);
      final existing = await _db
          .customSelect(
            'SELECT field_hlcs FROM ${_table(type)} WHERE id = ?',
            variables: [Variable<String>(id)],
          )
          .getSingleOrNull();
      final hlcs = _decodeMap(existing?.read<String>('field_hlcs'));
      for (final f in fields.keys) {
        hlcs[f] = hlc;
      }
      await _upsert(type, {
        'id': Variable<String>(id),
        ...values,
        'field_hlcs': Variable<String>(jsonEncode(hlcs)),
      });
      await _db
          .into(_db.outbox)
          .insert(
            OutboxCompanion.insert(
              changeId: newId(),
              entityType: type.apiValue,
              entityId: id,
              fields: jsonEncode({
                for (final e in fields.entries) e.key: {'v': e.value, 'h': hlc},
              }),
              createdAt: _now(),
            ),
          );
      await _db
          .into(_db.kv)
          .insertOnConflictUpdate(
            KvCompanion.insert(key: 'hlc.last', value: hlc),
          );
    });
  }

  /// Writes never-synced fields (`conflictText`, `conflictFrom`): no HLC and
  /// no outbox entry.
  Future<void> writeLocalOnly(
    EntityType type,
    String id,
    Map<String, Object?> fields,
  ) {
    if (type != EntityType.item) {
      throw ArgumentError('No local-only fields on ${type.apiValue}');
    }
    return _db.transaction(() async {
      final values = _values(_itemLocalFields, fields);
      await _upsert(type, {'id': Variable<String>(id), ...values});
    });
  }

  Future<void> _upsert(EntityType type, Map<String, Expression> row) async {
    if (type == EntityType.list) {
      await _db
          .into(_db.lists)
          .insertOnConflictUpdate(RawValuesInsertable<ListRow>(row));
    } else {
      await _db
          .into(_db.items)
          .insertOnConflictUpdate(RawValuesInsertable<ItemRow>(row));
    }
  }

  Map<String, Expression> _values(
    Map<String, (String, _T)> map,
    Map<String, Object?> fields,
  ) {
    final out = <String, Expression>{};
    for (final e in fields.entries) {
      final spec = map[e.key];
      if (spec == null) {
        throw ArgumentError.value(e.key, 'fields', 'Unknown field');
      }
      final (column, kind) = spec;
      final v = e.value;
      out[column] = switch ((kind, v)) {
        (_, null) => const Constant<Object>(null),
        (_T.text, final String s) => Variable<String>(s),
        (_T.int, final int n) => Variable<int>(n),
        (_T.bool, final bool b) => Variable<bool>(b),
        _ => throw ArgumentError.value(e.key, 'fields', 'Wrong value type'),
      };
    }
    return out;
  }

  Map<String, Object?> _decodeMap(String? json) {
    if (json == null) return {};
    final decoded = jsonDecode(json);
    return decoded is Map ? Map<String, Object?>.from(decoded) : {};
  }
}
