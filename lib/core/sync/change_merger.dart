import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/weave_database.dart';
import '../helpers/json_map.dart';
import 'change_writer.dart';
import 'conflict_losers.dart';
import 'entity_type.dart';
import 'field_value.dart';
import 'hlc.dart';
import 'hlc_clock.dart';
import 'purge_log.dart';
import 'remote_change.dart';
import 'synced_fields.dart';

/// Outcome of [ChangeMerger.apply], strongest first:
/// conflict > resurrected > applied > ignored.
enum MergeResult { applied, ignored, conflict, resurrected }

enum _Text { skip, apply, remoteWins, localWins }

typedef _TextMerge = ({
  _Text outcome,
  FieldValue fv,
  Hlc remote,
  String localText,
  Hlc? localHlc,
  Hlc? localBase,
});

/// Applies pulled remote changes to the local database, field by field, by
/// last-writer-wins on per-field HLCs. Never loses a concurrent text edit
/// silently: it is kept as a conflict instead.
class ChangeMerger {
  ChangeMerger(this._db, this._clock, this._writer, this._deviceName);

  final WeaveDatabase _db;
  final HlcClock _clock;
  final ChangeWriter _writer;
  final Future<String> Function(String deviceId) _deviceName;

  /// Applies one remote change in a single transaction.
  Future<MergeResult> apply(RemoteChange meta, Map<String, FieldValue> fields) {
    return _db.transaction(() async {
      final metaHlc = _tryParse(meta.hlc);
      if (metaHlc == null) return MergeResult.ignored;
      var newest = metaHlc;
      for (final f in fields.values) {
        final h = _tryParse(f.h);
        if (h != null && h.compareTo(newest) > 0) newest = h;
      }
      _clock.receive(newest);
      await _db
          .into(_db.kv)
          .insertOnConflictUpdate(
            KvCompanion.insert(key: 'hlc.last', value: _clock.last.pack()),
          );

      final type = meta.type;
      final id = meta.entityId;
      if (await isPurged(_db, id)) return MergeResult.ignored;

      final values = _validFields(type, fields);
      final table = type == EntityType.list ? 'lists' : 'items';
      final existing = await _db
          .customSelect(
            'SELECT * FROM $table WHERE id = ?',
            variables: [Variable<String>(id)],
          )
          .getSingleOrNull();

      final deleted = values['deletedAt'];
      if (deleted != null && deleted.v == 0) {
        await _purge(type, id);
        return MergeResult.applied;
      }

      if (type == EntityType.item) {
        final incomingList = values['listId']?.v;
        final listId = incomingList is String
            ? incomingList
            : existing?.read<String>('list_id');
        // Never create an orphan: a new item needs a (live) list.
        if (existing == null && (listId == null || listId.isEmpty)) {
          return MergeResult.ignored;
        }
        if (listId != null && await isPurged(_db, listId)) {
          return MergeResult.ignored;
        }
      }

      final before = decodeJsonMap(existing?.read<String>('field_hlcs'));
      final hlcs = {...before};
      final map = type == EntityType.list ? listFields : itemFields;
      final columns = <String, Expression>{};
      _TextMerge? textMerge;
      var undoTrash = false;

      for (final e in values.entries) {
        final f = e.key;
        final fv = e.value;
        final remote = _tryParse(fv.h);
        if (remote == null) continue;
        final spec = map[f]!;

        if (f == 'text' && existing != null) {
          final localText = existing.read<String>('text');
          final localHlc = _tryParse(hlcs['text']);
          final localBase = _tryParse(hlcs[textBaseKey]);
          final outcome = await _mergeText(id, fv, remote, localText, hlcs);
          if (outcome == _Text.skip) continue;
          textMerge = (
            outcome: outcome,
            fv: fv,
            remote: remote,
            localText: localText,
            localHlc: localHlc,
            localBase: localBase,
          );
          if (outcome == _Text.localWins) continue;
          columns[spec.column] = _expr(spec.type, fv.v);
          hlcs[f] = remote.pack();
          _setTextBase(hlcs, fv);
          continue;
        }

        final local = _tryParse(hlcs[f]);
        if (local != null && remote.compareTo(local) <= 0) continue;

        // A trash older than a local edit loses: undo it everywhere.
        final v = fv.v;
        if (f == 'deletedAt' &&
            existing != null &&
            v is int &&
            v > 0 &&
            _hasNewerField(map, before, remote)) {
          undoTrash = true;
          continue;
        }

        columns[spec.column] = _expr(spec.type, v);
        hlcs[f] = remote.pack();
        if (f == 'text') _setTextBase(hlcs, fv);
      }

      if (columns.isEmpty && textMerge == null && !undoTrash) {
        return MergeResult.ignored;
      }

      if (columns.isNotEmpty) {
        await _upsert(type, {
          'id': Variable<String>(id),
          ...columns,
          'field_hlcs': Variable<String>(jsonEncode(hlcs)),
        });
      }

      var result = columns.isEmpty ? MergeResult.ignored : MergeResult.applied;

      var resurrect = undoTrash;
      if (!resurrect && existing != null && _shouldResurrect(values, hlcs)) {
        final row = await _db
            .customSelect(
              'SELECT deleted_at FROM $table WHERE id = ?',
              variables: [Variable<String>(id)],
            )
            .getSingle();
        final deletedAt = row.read<int?>('deleted_at');
        resurrect = deletedAt != null && deletedAt > 0;
      }
      if (resurrect) {
        await _writer.write(type, id, {'deletedAt': null});
        result = MergeResult.resurrected;
      }

      if (textMerge != null && existing != null) {
        final (:losers, :changed, :added) = await _mergeLosers(
          _losers(existing),
          textMerge,
          meta.deviceId,
        );
        if (changed) {
          await _writer.writeLocalOnly(
            EntityType.item,
            id,
            encodeLosers(losers),
          );
          if (result == MergeResult.ignored) result = MergeResult.applied;
        }
        if (added) result = MergeResult.conflict;
      }
      return result;
    });
  }

  static List<ConflictLoser> _losers(QueryRow? row) => row == null
      ? const []
      : decodeLosers(
          row.read<String?>('conflict_text'),
          row.read<String?>('conflict_from'),
        );

  /// Updates the kept losers for an incoming text. Losers are local only:
  /// each device resolves its own. Never overwrites an unresolved loser.
  /// - A kept loser is superseded by an edit made on top of it (`b` equals
  ///   its HLC) or on top of a later edit by the loser's device.
  /// - Incoming text applied (sequential or remote wins): superseded losers
  ///   are dropped; on remote win the old local text is added as a loser.
  /// - Local wins: the incoming edit is the loser. It is ignored if a kept
  ///   loser from the same device is as new or newer (already surfaced or an
  ///   ancestor); otherwise it replaces a loser it supersedes, or is appended.
  /// - Duplicate texts are kept once, and a loser equal to the current text
  ///   is dropped.
  ///
  /// `added` is true only when a new loser entry was stored.
  Future<({List<ConflictLoser> losers, bool changed, bool added})> _mergeLosers(
    List<ConflictLoser> kept,
    _TextMerge m,
    String senderId,
  ) async {
    final losers = [...kept];
    final base = _baseOf(m.fv, m.remote);
    bool superseded(ConflictLoser k) => _supersedes(base, k);

    var added = false;
    final incoming = m.fv.v;
    if (m.outcome == _Text.localWins) {
      if (incoming is String) {
        final known = losers.any((k) {
          final kh = _tryParse(k.hlc);
          return kh != null &&
              kh.node == m.remote.node &&
              kh.compareTo(m.remote) >= 0;
        });
        final replaces = losers.any(superseded);
        final dup = losers.any((k) => k.text == incoming);
        if (!known && (replaces || !dup)) {
          final entry = (
            text: incoming,
            from: await _deviceName(senderId),
            hlc: m.remote.pack(),
          );
          final next = <ConflictLoser>[];
          var placed = false;
          for (final k in losers) {
            if (superseded(k)) {
              if (!placed) next.add(entry);
              placed = true;
            } else if (k.text != incoming) {
              next.add(k);
            }
          }
          if (!placed) next.add(entry);
          losers
            ..clear()
            ..addAll(next);
          added = true;
        }
      }
    } else {
      losers.removeWhere(superseded);
      final local = m.localHlc;
      if (m.outcome == _Text.remoteWins && local != null) {
        // The old local text joins the losers; it supersedes what it was
        // made on top of, like any incoming edit.
        losers.removeWhere((k) => _supersedes(m.localBase, k));
      }
      if (m.outcome == _Text.remoteWins &&
          local != null &&
          !losers.any((k) => k.text == m.localText)) {
        losers.add((
          text: m.localText,
          from: await _deviceName(local.node),
          hlc: local.pack(),
        ));
        added = true;
      }
      losers.removeWhere((k) => k.text == incoming);
    }
    final changed =
        losers.length != kept.length ||
        [
          for (var i = 0; i < losers.length; i++) losers[i] != kept[i],
        ].any((d) => d);
    return (losers: losers, changed: changed, added: added && changed);
  }

  /// True when an edit made on top of [base] replaces the kept loser [k]:
  /// [base] is that loser, or a later edit by the same device (whose text
  /// history includes the loser). Precondition as for the same-device text
  /// rule: node == device id, never reused with a reset clock.
  static bool _supersedes(Hlc? base, ConflictLoser k) {
    final kh = _tryParse(k.hlc);
    if (base == null || kh == null) return false;
    return kh == base || (kh.node == base.node && base.compareTo(kh) > 0);
  }

  /// The incoming edit's base HLC, or null when absent, malformed or not
  /// older than the edit itself.
  static Hlc? _baseOf(FieldValue fv, Hlc remote) {
    final b = _tryParse(fv.b);
    return b != null && b.compareTo(remote) < 0 ? b : null;
  }

  /// Decides an incoming `text` on an existing item against the local text
  /// HLC `L`, its base `Lb` (see [textBaseKey]) and the remote base `b`:
  /// - no `L` → apply;
  /// - remote is `L` or `Lb` (already seen / an ancestor) → skip;
  /// - same device as `L`: older → skip (ancestor or a loser already kept),
  ///   newer → sequential (that device had seen `L`). Preconditions: an HLC
  ///   node is the device id, and a device id is never reused with a reset
  ///   clock (Task 13 makes a new id after a wipe);
  /// - `b == L` (made on top of ours) → newer wins, no conflict;
  /// - otherwise concurrent: equal values → newer wins, no conflict; different
  ///   values → the greater HLC wins on every device and the loser is kept as
  ///   the conflict text.
  ///
  /// A payload without `b` (older format) counts as concurrent only while a
  /// local text edit is pending in the outbox; otherwise as sequential.
  Future<_Text> _mergeText(
    String id,
    FieldValue fv,
    Hlc remote,
    String localText,
    Map<String, Object?> hlcs,
  ) async {
    final local = _tryParse(hlcs['text']);
    if (local == null) return _Text.apply;
    if (remote == local) return _Text.skip;
    final localBase = _tryParse(hlcs[textBaseKey]);
    if (localBase != null && remote == localBase) return _Text.skip;
    final newer = remote.compareTo(local) > 0;
    if (remote.node == local.node) return newer ? _Text.apply : _Text.skip;
    // A base must be older than its own edit; otherwise it is ignored.
    final base = _baseOf(fv, remote);
    final sequential = base != null
        ? base == local
        : !await _hasPendingText(id);
    if (sequential || fv.v == localText) {
      return newer ? _Text.apply : _Text.skip;
    }
    return newer ? _Text.remoteWins : _Text.localWins;
  }

  static void _setTextBase(Map<String, Object?> hlcs, FieldValue fv) {
    final b = fv.b;
    if (b == null) {
      hlcs.remove(textBaseKey);
    } else {
      hlcs[textBaseKey] = b;
    }
  }

  /// True when the local row has a synced field (other than `deletedAt`)
  /// newer than [than]. Ignores local-only keys such as [textBaseKey].
  bool _hasNewerField(
    Map<String, FieldSpec> map,
    Map<String, Object?> hlcs,
    Hlc than,
  ) {
    for (final e in hlcs.entries) {
      if (e.key == 'deletedAt' || !map.containsKey(e.key)) continue;
      final h = _tryParse(e.value);
      if (h != null && h.compareTo(than) > 0) return true;
    }
    return false;
  }

  /// True when an incoming non-`deletedAt` field is newer than the delete.
  bool _shouldResurrect(
    Map<String, FieldValue> values,
    Map<String, Object?> hlcs,
  ) {
    final deletedHlc = _tryParse(hlcs['deletedAt']);
    for (final e in values.entries) {
      if (e.key == 'deletedAt') continue;
      final h = _tryParse(e.value.h);
      if (h == null) continue;
      if (deletedHlc == null || h.compareTo(deletedHlc) > 0) return true;
    }
    return false;
  }

  /// Known fields whose value type fits the column. Unknown fields are
  /// ignored (forward compatibility); wrongly typed ones are skipped.
  Map<String, FieldValue> _validFields(
    EntityType type,
    Map<String, FieldValue> fields,
  ) {
    final map = type == EntityType.list ? listFields : itemFields;
    final out = <String, FieldValue>{};
    for (final e in fields.entries) {
      final spec = map[e.key];
      if (spec == null) continue;
      final v = e.value.v;
      final ok = switch (spec.type) {
        _ when v == null => spec.nullable,
        FieldType.text => v is String,
        FieldType.int => v is int,
        FieldType.bool => v is bool,
      };
      if (ok) out[e.key] = e.value;
    }
    return out;
  }

  Expression _expr(FieldType kind, Object? v) => switch ((kind, v)) {
    (FieldType.text, final String s) => Variable<String>(s),
    (FieldType.int, final int n) => Variable<int>(n),
    (FieldType.bool, final bool b) => Variable<bool>(b),
    _ => const Constant<Object>(null),
  };

  /// Hard-deletes locally, drops pending outbox rows for the purged ids and
  /// remembers them so late changes never bring them back.
  Future<void> _purge(EntityType type, String id) async {
    if (type == EntityType.list) {
      final items = await (_db.select(
        _db.items,
      )..where((t) => t.listId.equals(id))).get();
      final itemIds = [for (final i in items) i.id];
      await dropPending(_db, [id, ...itemIds]);
      await deletePurgedRows(_db, listId: id);
      await markPurged(_db, [id, ...itemIds]);
    } else {
      await dropPending(_db, [id]);
      await deletePurgedRows(_db, itemId: id);
      await markPurged(_db, [id]);
    }
  }

  Future<bool> _hasPendingText(String id) async {
    final rows =
        await (_db.select(_db.outbox)..where(
              (t) =>
                  t.entityType.equals(EntityType.item.apiValue) &
                  t.entityId.equals(id),
            ))
            .get();
    for (final r in rows) {
      if (decodeJsonMap(r.fields).containsKey('text')) return true;
    }
    return false;
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

  /// Millis at or above this (about year 5138) cannot come from a real
  /// clock; letting one in would push the local clock toward the 15-digit
  /// limit of the packed form.
  static const _maxMillis = 100000000000000;

  /// Parses a packed HLC; null when malformed. A counter at or above
  /// [Hlc.maxCounter] (the clock never issues it) or millis at or above
  /// [_maxMillis] also count as malformed.
  static Hlc? _tryParse(Object? s) {
    if (s is! String) return null;
    try {
      final h = Hlc.parse(s);
      if (h.counter >= Hlc.maxCounter || h.millis >= _maxMillis) return null;
      return h;
    } on FormatException {
      return null;
    }
  }
}
