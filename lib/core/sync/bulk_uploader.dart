import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/weave_database.dart';
import '../helpers/json_map.dart';
import '../ids/new_id.dart';
import 'entity_type.dart';
import 'synced_fields.dart';

/// Queues the whole local state for upload when signing in.
///
/// In local mode `ChangeWriter` writes no outbox rows, so on sign-in the
/// current state is snapshotted instead: one change per list and per item,
/// lists first, each with every synced field that has an HLC, its current
/// value and that HLC (plus `b` from `text.b` for item text). A field with
/// no HLC was never written (it holds the table default) and is left out,
/// exactly as the per-edit changes would have left it out. Local-only fields
/// (`conflictText`, `conflictFrom`) are never sent.
class BulkUploader {
  BulkUploader(this._db, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final WeaveDatabase _db;
  final int Function() _now;

  /// Kv key naming the account this device's data belongs to and was
  /// snapshotted for. Written in the snapshot transaction; cleared by wipe.
  static const ownerKey = 'account.user';

  /// The account the local data belongs to, or null (local-mode data or
  /// none).
  Future<String?> owner() async {
    final row = await (_db.select(
      _db.kv,
    )..where((t) => t.key.equals(ownerKey))).getSingleOrNull();
    return row?.value;
  }

  /// In one transaction: drops any outbox rows (stale, or duplicating the
  /// snapshot), writes the snapshot and sets [ownerKey] to [userId]. Only
  /// for data without an owner (local mode); data already owned by the user
  /// has every edit in the outbox. Returns the number of changes written.
  Future<int> enqueueAll(String userId) => _db.transaction(() async {
    await _db.delete(_db.outbox).go();
    await _db
        .into(_db.kv)
        .insertOnConflictUpdate(
          KvCompanion.insert(key: ownerKey, value: userId),
        );
    final createdAt = _now();
    var count = 0;
    for (final type in EntityType.values) {
      final table = type == EntityType.list ? 'lists' : 'items';
      final specs = type == EntityType.list ? listFields : itemFields;
      final rows = await _db
          .customSelect('SELECT * FROM $table ORDER BY rowid')
          .get();
      for (final row in rows) {
        final hlcs = decodeJsonMap(row.read<String>('field_hlcs'));
        final textBase = hlcs[textBaseKey];
        final fields = <String, Object?>{};
        for (final e in specs.entries) {
          final h = hlcs[e.key];
          if (h is! String) continue;
          fields[e.key] = {
            'v': _read(row, e.value),
            'h': h,
            if (type == EntityType.item &&
                e.key == 'text' &&
                textBase is String)
              'b': textBase,
          };
        }
        if (fields.isEmpty) continue;
        await _db
            .into(_db.outbox)
            .insert(
              OutboxCompanion.insert(
                changeId: newId(),
                entityType: type.apiValue,
                entityId: row.read<String>('id'),
                fields: jsonEncode(fields),
                createdAt: createdAt,
              ),
            );
        count++;
      }
    }
    return count;
  });

  static Object? _read(QueryRow row, FieldSpec spec) => switch (spec.type) {
    FieldType.text => row.readNullable<String>(spec.column),
    FieldType.int => row.readNullable<int>(spec.column),
    FieldType.bool => row.readNullable<bool>(spec.column),
  };
}
