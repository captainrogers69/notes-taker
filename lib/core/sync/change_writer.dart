import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/weave_database.dart';
import '../helpers/json_map.dart';
import '../ids/new_id.dart';
import 'entity_type.dart';
import 'hlc_clock.dart';
import 'synced_fields.dart';

/// Applies synced writes: row, per-field HLCs and outbox entry in one
/// transaction. Field maps live in `synced_fields.dart`; `id`, `fieldHlcs`,
/// `conflictText` and `conflictFrom` are never synced.
///
/// A write that includes item `text` also records the text HLC it replaced
/// (the base): as `b` on the outbox `text` entry and locally under
/// [textBaseKey]. The merger uses it to tell sequential from concurrent edits.
class ChangeWriter {
  ChangeWriter(this._db, this._clock, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final WeaveDatabase _db;
  final HlcClock _clock;
  final int Function() _now;

  Map<String, FieldSpec> _map(EntityType t) =>
      t == EntityType.list ? listFields : itemFields;

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
      final hlcs = decodeJsonMap(existing?.read<String>('field_hlcs'));
      // The text version this edit is made on top of (see `textBaseKey`).
      final previousText = hlcs['text'];
      final textBase = type == EntityType.item && fields.containsKey('text')
          ? (previousText is String ? previousText : null)
          : null;
      for (final f in fields.keys) {
        hlcs[f] = hlc;
      }
      if (type == EntityType.item && fields.containsKey('text')) {
        if (textBase == null) {
          hlcs.remove(textBaseKey);
        } else {
          hlcs[textBaseKey] = textBase;
        }
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
                for (final e in fields.entries)
                  e.key: {
                    'v': e.value,
                    'h': hlc,
                    if (e.key == 'text') 'b': ?textBase,
                  },
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
      final values = _values(itemLocalFields, fields);
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
    Map<String, FieldSpec> map,
    Map<String, Object?> fields,
  ) {
    final out = <String, Expression>{};
    for (final e in fields.entries) {
      final spec = map[e.key];
      if (spec == null) {
        throw ArgumentError.value(e.key, 'fields', 'Unknown field');
      }
      final v = e.value;
      out[spec.column] = switch ((spec.type, v)) {
        (_, null) => const Constant<Object>(null),
        (FieldType.text, final String s) => Variable<String>(s),
        (FieldType.int, final int n) => Variable<int>(n),
        (FieldType.bool, final bool b) => Variable<bool>(b),
        _ => throw ArgumentError.value(e.key, 'fields', 'Wrong value type'),
      };
    }
    return out;
  }
}
