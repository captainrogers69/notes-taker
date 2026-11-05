// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weave_database.dart';

// ignore_for_file: type=lint
class $ListsTable extends Lists with TableInfo<$ListsTable, ListRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('yellow'),
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pinnedToTopMeta = const VerificationMeta(
    'pinnedToTop',
  );
  @override
  late final GeneratedColumn<bool> pinnedToTop = GeneratedColumn<bool>(
    'pinned_to_top',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned_to_top" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hideDoneMeta = const VerificationMeta(
    'hideDone',
  );
  @override
  late final GeneratedColumn<bool> hideDone = GeneratedColumn<bool>(
    'hide_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hide_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueMinutesMeta = const VerificationMeta(
    'dueMinutes',
  );
  @override
  late final GeneratedColumn<int> dueMinutes = GeneratedColumn<int>(
    'due_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldHlcsMeta = const VerificationMeta(
    'fieldHlcs',
  );
  @override
  late final GeneratedColumn<String> fieldHlcs = GeneratedColumn<String>(
    'field_hlcs',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    sortKey,
    pinnedToTop,
    hideDone,
    dueDate,
    dueMinutes,
    archivedAt,
    deletedAt,
    fieldHlcs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    }
    if (data.containsKey('pinned_to_top')) {
      context.handle(
        _pinnedToTopMeta,
        pinnedToTop.isAcceptableOrUnknown(
          data['pinned_to_top']!,
          _pinnedToTopMeta,
        ),
      );
    }
    if (data.containsKey('hide_done')) {
      context.handle(
        _hideDoneMeta,
        hideDone.isAcceptableOrUnknown(data['hide_done']!, _hideDoneMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('due_minutes')) {
      context.handle(
        _dueMinutesMeta,
        dueMinutes.isAcceptableOrUnknown(data['due_minutes']!, _dueMinutesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('field_hlcs')) {
      context.handle(
        _fieldHlcsMeta,
        fieldHlcs.isAcceptableOrUnknown(data['field_hlcs']!, _fieldHlcsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      )!,
      pinnedToTop: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned_to_top'],
      )!,
      hideDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hide_done'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_date'],
      ),
      dueMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_minutes'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      fieldHlcs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_hlcs'],
      )!,
    );
  }

  @override
  $ListsTable createAlias(String alias) {
    return $ListsTable(attachedDatabase, alias);
  }
}

class ListRow extends DataClass implements Insertable<ListRow> {
  final String id;
  final String name;

  /// Default equals `NoteColor.values.first.apiValue` (covered by a test).
  final String color;
  final String sortKey;
  final bool pinnedToTop;
  final bool hideDone;

  /// `yyyy-MM-dd`, local.
  final String? dueDate;

  /// Minutes after local midnight.
  final int? dueMinutes;

  /// Milliseconds since epoch, UTC.
  final int? archivedAt;
  final int? deletedAt;

  /// JSON map: field -> packed HLC.
  final String fieldHlcs;
  const ListRow({
    required this.id,
    required this.name,
    required this.color,
    required this.sortKey,
    required this.pinnedToTop,
    required this.hideDone,
    this.dueDate,
    this.dueMinutes,
    this.archivedAt,
    this.deletedAt,
    required this.fieldHlcs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['sort_key'] = Variable<String>(sortKey);
    map['pinned_to_top'] = Variable<bool>(pinnedToTop);
    map['hide_done'] = Variable<bool>(hideDone);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<String>(dueDate);
    }
    if (!nullToAbsent || dueMinutes != null) {
      map['due_minutes'] = Variable<int>(dueMinutes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['field_hlcs'] = Variable<String>(fieldHlcs);
    return map;
  }

  ListsCompanion toCompanion(bool nullToAbsent) {
    return ListsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      sortKey: Value(sortKey),
      pinnedToTop: Value(pinnedToTop),
      hideDone: Value(hideDone),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueMinutes: dueMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(dueMinutes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      fieldHlcs: Value(fieldHlcs),
    );
  }

  factory ListRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      sortKey: serializer.fromJson<String>(json['sortKey']),
      pinnedToTop: serializer.fromJson<bool>(json['pinnedToTop']),
      hideDone: serializer.fromJson<bool>(json['hideDone']),
      dueDate: serializer.fromJson<String?>(json['dueDate']),
      dueMinutes: serializer.fromJson<int?>(json['dueMinutes']),
      archivedAt: serializer.fromJson<int?>(json['archivedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      fieldHlcs: serializer.fromJson<String>(json['fieldHlcs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'sortKey': serializer.toJson<String>(sortKey),
      'pinnedToTop': serializer.toJson<bool>(pinnedToTop),
      'hideDone': serializer.toJson<bool>(hideDone),
      'dueDate': serializer.toJson<String?>(dueDate),
      'dueMinutes': serializer.toJson<int?>(dueMinutes),
      'archivedAt': serializer.toJson<int?>(archivedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'fieldHlcs': serializer.toJson<String>(fieldHlcs),
    };
  }

  ListRow copyWith({
    String? id,
    String? name,
    String? color,
    String? sortKey,
    bool? pinnedToTop,
    bool? hideDone,
    Value<String?> dueDate = const Value.absent(),
    Value<int?> dueMinutes = const Value.absent(),
    Value<int?> archivedAt = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    String? fieldHlcs,
  }) => ListRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    sortKey: sortKey ?? this.sortKey,
    pinnedToTop: pinnedToTop ?? this.pinnedToTop,
    hideDone: hideDone ?? this.hideDone,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueMinutes: dueMinutes.present ? dueMinutes.value : this.dueMinutes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    fieldHlcs: fieldHlcs ?? this.fieldHlcs,
  );
  ListRow copyWithCompanion(ListsCompanion data) {
    return ListRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      pinnedToTop: data.pinnedToTop.present
          ? data.pinnedToTop.value
          : this.pinnedToTop,
      hideDone: data.hideDone.present ? data.hideDone.value : this.hideDone,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueMinutes: data.dueMinutes.present
          ? data.dueMinutes.value
          : this.dueMinutes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      fieldHlcs: data.fieldHlcs.present ? data.fieldHlcs.value : this.fieldHlcs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortKey: $sortKey, ')
          ..write('pinnedToTop: $pinnedToTop, ')
          ..write('hideDone: $hideDone, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueMinutes: $dueMinutes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('fieldHlcs: $fieldHlcs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    sortKey,
    pinnedToTop,
    hideDone,
    dueDate,
    dueMinutes,
    archivedAt,
    deletedAt,
    fieldHlcs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortKey == this.sortKey &&
          other.pinnedToTop == this.pinnedToTop &&
          other.hideDone == this.hideDone &&
          other.dueDate == this.dueDate &&
          other.dueMinutes == this.dueMinutes &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.fieldHlcs == this.fieldHlcs);
}

class ListsCompanion extends UpdateCompanion<ListRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> color;
  final Value<String> sortKey;
  final Value<bool> pinnedToTop;
  final Value<bool> hideDone;
  final Value<String?> dueDate;
  final Value<int?> dueMinutes;
  final Value<int?> archivedAt;
  final Value<int?> deletedAt;
  final Value<String> fieldHlcs;
  final Value<int> rowid;
  const ListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.pinnedToTop = const Value.absent(),
    this.hideDone = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueMinutes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.fieldHlcs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.pinnedToTop = const Value.absent(),
    this.hideDone = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueMinutes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.fieldHlcs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ListRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<String>? sortKey,
    Expression<bool>? pinnedToTop,
    Expression<bool>? hideDone,
    Expression<String>? dueDate,
    Expression<int>? dueMinutes,
    Expression<int>? archivedAt,
    Expression<int>? deletedAt,
    Expression<String>? fieldHlcs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortKey != null) 'sort_key': sortKey,
      if (pinnedToTop != null) 'pinned_to_top': pinnedToTop,
      if (hideDone != null) 'hide_done': hideDone,
      if (dueDate != null) 'due_date': dueDate,
      if (dueMinutes != null) 'due_minutes': dueMinutes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (fieldHlcs != null) 'field_hlcs': fieldHlcs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? color,
    Value<String>? sortKey,
    Value<bool>? pinnedToTop,
    Value<bool>? hideDone,
    Value<String?>? dueDate,
    Value<int?>? dueMinutes,
    Value<int?>? archivedAt,
    Value<int?>? deletedAt,
    Value<String>? fieldHlcs,
    Value<int>? rowid,
  }) {
    return ListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortKey: sortKey ?? this.sortKey,
      pinnedToTop: pinnedToTop ?? this.pinnedToTop,
      hideDone: hideDone ?? this.hideDone,
      dueDate: dueDate ?? this.dueDate,
      dueMinutes: dueMinutes ?? this.dueMinutes,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      fieldHlcs: fieldHlcs ?? this.fieldHlcs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (pinnedToTop.present) {
      map['pinned_to_top'] = Variable<bool>(pinnedToTop.value);
    }
    if (hideDone.present) {
      map['hide_done'] = Variable<bool>(hideDone.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (dueMinutes.present) {
      map['due_minutes'] = Variable<int>(dueMinutes.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (fieldHlcs.present) {
      map['field_hlcs'] = Variable<String>(fieldHlcs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortKey: $sortKey, ')
          ..write('pinnedToTop: $pinnedToTop, ')
          ..write('hideDone: $hideDone, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueMinutes: $dueMinutes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('fieldHlcs: $fieldHlcs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('task'),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<int> doneAt = GeneratedColumn<int>(
    'done_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _indentMeta = const VerificationMeta('indent');
  @override
  late final GeneratedColumn<int> indent = GeneratedColumn<int>(
    'indent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueMinutesMeta = const VerificationMeta(
    'dueMinutes',
  );
  @override
  late final GeneratedColumn<int> dueMinutes = GeneratedColumn<int>(
    'due_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindersMeta = const VerificationMeta(
    'reminders',
  );
  @override
  late final GeneratedColumn<String> reminders = GeneratedColumn<String>(
    'reminders',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<String> repeat = GeneratedColumn<String>(
    'repeat',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictTextMeta = const VerificationMeta(
    'conflictText',
  );
  @override
  late final GeneratedColumn<String> conflictText = GeneratedColumn<String>(
    'conflict_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictFromMeta = const VerificationMeta(
    'conflictFrom',
  );
  @override
  late final GeneratedColumn<String> conflictFrom = GeneratedColumn<String>(
    'conflict_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldHlcsMeta = const VerificationMeta(
    'fieldHlcs',
  );
  @override
  late final GeneratedColumn<String> fieldHlcs = GeneratedColumn<String>(
    'field_hlcs',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    kind,
    body,
    done,
    doneAt,
    indent,
    sortKey,
    dueDate,
    dueMinutes,
    reminders,
    repeat,
    conflictText,
    conflictFrom,
    deletedAt,
    fieldHlcs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('done_at')) {
      context.handle(
        _doneAtMeta,
        doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta),
      );
    }
    if (data.containsKey('indent')) {
      context.handle(
        _indentMeta,
        indent.isAcceptableOrUnknown(data['indent']!, _indentMeta),
      );
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('due_minutes')) {
      context.handle(
        _dueMinutesMeta,
        dueMinutes.isAcceptableOrUnknown(data['due_minutes']!, _dueMinutesMeta),
      );
    }
    if (data.containsKey('reminders')) {
      context.handle(
        _remindersMeta,
        reminders.isAcceptableOrUnknown(data['reminders']!, _remindersMeta),
      );
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    }
    if (data.containsKey('conflict_text')) {
      context.handle(
        _conflictTextMeta,
        conflictText.isAcceptableOrUnknown(
          data['conflict_text']!,
          _conflictTextMeta,
        ),
      );
    }
    if (data.containsKey('conflict_from')) {
      context.handle(
        _conflictFromMeta,
        conflictFrom.isAcceptableOrUnknown(
          data['conflict_from']!,
          _conflictFromMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('field_hlcs')) {
      context.handle(
        _fieldHlcsMeta,
        fieldHlcs.isAcceptableOrUnknown(data['field_hlcs']!, _fieldHlcsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      doneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_at'],
      ),
      indent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}indent'],
      )!,
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_date'],
      ),
      dueMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_minutes'],
      ),
      reminders: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminders'],
      )!,
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat'],
      ),
      conflictText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_text'],
      ),
      conflictFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_from'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      fieldHlcs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_hlcs'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String id;
  final String listId;

  /// `'task'` or `'text'`.
  final String kind;

  /// SQL column and synced field are `text`; the Dart getter is `body`
  /// because `text` clashes with `Table.text()`.
  final String body;
  final bool done;
  final int? doneAt;

  /// 0 or 1.
  final int indent;
  final String sortKey;
  final String? dueDate;
  final int? dueMinutes;

  /// JSON list of encoded reminder specs.
  final String reminders;
  final String? repeat;

  /// Local only, never synced.
  final String? conflictText;
  final String? conflictFrom;
  final int? deletedAt;
  final String fieldHlcs;
  const ItemRow({
    required this.id,
    required this.listId,
    required this.kind,
    required this.body,
    required this.done,
    this.doneAt,
    required this.indent,
    required this.sortKey,
    this.dueDate,
    this.dueMinutes,
    required this.reminders,
    this.repeat,
    this.conflictText,
    this.conflictFrom,
    this.deletedAt,
    required this.fieldHlcs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['list_id'] = Variable<String>(listId);
    map['kind'] = Variable<String>(kind);
    map['text'] = Variable<String>(body);
    map['done'] = Variable<bool>(done);
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<int>(doneAt);
    }
    map['indent'] = Variable<int>(indent);
    map['sort_key'] = Variable<String>(sortKey);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<String>(dueDate);
    }
    if (!nullToAbsent || dueMinutes != null) {
      map['due_minutes'] = Variable<int>(dueMinutes);
    }
    map['reminders'] = Variable<String>(reminders);
    if (!nullToAbsent || repeat != null) {
      map['repeat'] = Variable<String>(repeat);
    }
    if (!nullToAbsent || conflictText != null) {
      map['conflict_text'] = Variable<String>(conflictText);
    }
    if (!nullToAbsent || conflictFrom != null) {
      map['conflict_from'] = Variable<String>(conflictFrom);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['field_hlcs'] = Variable<String>(fieldHlcs);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      listId: Value(listId),
      kind: Value(kind),
      body: Value(body),
      done: Value(done),
      doneAt: doneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(doneAt),
      indent: Value(indent),
      sortKey: Value(sortKey),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueMinutes: dueMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(dueMinutes),
      reminders: Value(reminders),
      repeat: repeat == null && nullToAbsent
          ? const Value.absent()
          : Value(repeat),
      conflictText: conflictText == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictText),
      conflictFrom: conflictFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictFrom),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      fieldHlcs: Value(fieldHlcs),
    );
  }

  factory ItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<String>(json['id']),
      listId: serializer.fromJson<String>(json['listId']),
      kind: serializer.fromJson<String>(json['kind']),
      body: serializer.fromJson<String>(json['body']),
      done: serializer.fromJson<bool>(json['done']),
      doneAt: serializer.fromJson<int?>(json['doneAt']),
      indent: serializer.fromJson<int>(json['indent']),
      sortKey: serializer.fromJson<String>(json['sortKey']),
      dueDate: serializer.fromJson<String?>(json['dueDate']),
      dueMinutes: serializer.fromJson<int?>(json['dueMinutes']),
      reminders: serializer.fromJson<String>(json['reminders']),
      repeat: serializer.fromJson<String?>(json['repeat']),
      conflictText: serializer.fromJson<String?>(json['conflictText']),
      conflictFrom: serializer.fromJson<String?>(json['conflictFrom']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      fieldHlcs: serializer.fromJson<String>(json['fieldHlcs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String>(listId),
      'kind': serializer.toJson<String>(kind),
      'body': serializer.toJson<String>(body),
      'done': serializer.toJson<bool>(done),
      'doneAt': serializer.toJson<int?>(doneAt),
      'indent': serializer.toJson<int>(indent),
      'sortKey': serializer.toJson<String>(sortKey),
      'dueDate': serializer.toJson<String?>(dueDate),
      'dueMinutes': serializer.toJson<int?>(dueMinutes),
      'reminders': serializer.toJson<String>(reminders),
      'repeat': serializer.toJson<String?>(repeat),
      'conflictText': serializer.toJson<String?>(conflictText),
      'conflictFrom': serializer.toJson<String?>(conflictFrom),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'fieldHlcs': serializer.toJson<String>(fieldHlcs),
    };
  }

  ItemRow copyWith({
    String? id,
    String? listId,
    String? kind,
    String? body,
    bool? done,
    Value<int?> doneAt = const Value.absent(),
    int? indent,
    String? sortKey,
    Value<String?> dueDate = const Value.absent(),
    Value<int?> dueMinutes = const Value.absent(),
    String? reminders,
    Value<String?> repeat = const Value.absent(),
    Value<String?> conflictText = const Value.absent(),
    Value<String?> conflictFrom = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    String? fieldHlcs,
  }) => ItemRow(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    kind: kind ?? this.kind,
    body: body ?? this.body,
    done: done ?? this.done,
    doneAt: doneAt.present ? doneAt.value : this.doneAt,
    indent: indent ?? this.indent,
    sortKey: sortKey ?? this.sortKey,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueMinutes: dueMinutes.present ? dueMinutes.value : this.dueMinutes,
    reminders: reminders ?? this.reminders,
    repeat: repeat.present ? repeat.value : this.repeat,
    conflictText: conflictText.present ? conflictText.value : this.conflictText,
    conflictFrom: conflictFrom.present ? conflictFrom.value : this.conflictFrom,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    fieldHlcs: fieldHlcs ?? this.fieldHlcs,
  );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      done: data.done.present ? data.done.value : this.done,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
      indent: data.indent.present ? data.indent.value : this.indent,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueMinutes: data.dueMinutes.present
          ? data.dueMinutes.value
          : this.dueMinutes,
      reminders: data.reminders.present ? data.reminders.value : this.reminders,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      conflictText: data.conflictText.present
          ? data.conflictText.value
          : this.conflictText,
      conflictFrom: data.conflictFrom.present
          ? data.conflictFrom.value
          : this.conflictFrom,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      fieldHlcs: data.fieldHlcs.present ? data.fieldHlcs.value : this.fieldHlcs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('done: $done, ')
          ..write('doneAt: $doneAt, ')
          ..write('indent: $indent, ')
          ..write('sortKey: $sortKey, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueMinutes: $dueMinutes, ')
          ..write('reminders: $reminders, ')
          ..write('repeat: $repeat, ')
          ..write('conflictText: $conflictText, ')
          ..write('conflictFrom: $conflictFrom, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('fieldHlcs: $fieldHlcs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    listId,
    kind,
    body,
    done,
    doneAt,
    indent,
    sortKey,
    dueDate,
    dueMinutes,
    reminders,
    repeat,
    conflictText,
    conflictFrom,
    deletedAt,
    fieldHlcs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.done == this.done &&
          other.doneAt == this.doneAt &&
          other.indent == this.indent &&
          other.sortKey == this.sortKey &&
          other.dueDate == this.dueDate &&
          other.dueMinutes == this.dueMinutes &&
          other.reminders == this.reminders &&
          other.repeat == this.repeat &&
          other.conflictText == this.conflictText &&
          other.conflictFrom == this.conflictFrom &&
          other.deletedAt == this.deletedAt &&
          other.fieldHlcs == this.fieldHlcs);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> id;
  final Value<String> listId;
  final Value<String> kind;
  final Value<String> body;
  final Value<bool> done;
  final Value<int?> doneAt;
  final Value<int> indent;
  final Value<String> sortKey;
  final Value<String?> dueDate;
  final Value<int?> dueMinutes;
  final Value<String> reminders;
  final Value<String?> repeat;
  final Value<String?> conflictText;
  final Value<String?> conflictFrom;
  final Value<int?> deletedAt;
  final Value<String> fieldHlcs;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.done = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.indent = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueMinutes = const Value.absent(),
    this.reminders = const Value.absent(),
    this.repeat = const Value.absent(),
    this.conflictText = const Value.absent(),
    this.conflictFrom = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.fieldHlcs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    this.listId = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.done = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.indent = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueMinutes = const Value.absent(),
    this.reminders = const Value.absent(),
    this.repeat = const Value.absent(),
    this.conflictText = const Value.absent(),
    this.conflictFrom = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.fieldHlcs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ItemRow> custom({
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? kind,
    Expression<String>? body,
    Expression<bool>? done,
    Expression<int>? doneAt,
    Expression<int>? indent,
    Expression<String>? sortKey,
    Expression<String>? dueDate,
    Expression<int>? dueMinutes,
    Expression<String>? reminders,
    Expression<String>? repeat,
    Expression<String>? conflictText,
    Expression<String>? conflictFrom,
    Expression<int>? deletedAt,
    Expression<String>? fieldHlcs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (kind != null) 'kind': kind,
      if (body != null) 'text': body,
      if (done != null) 'done': done,
      if (doneAt != null) 'done_at': doneAt,
      if (indent != null) 'indent': indent,
      if (sortKey != null) 'sort_key': sortKey,
      if (dueDate != null) 'due_date': dueDate,
      if (dueMinutes != null) 'due_minutes': dueMinutes,
      if (reminders != null) 'reminders': reminders,
      if (repeat != null) 'repeat': repeat,
      if (conflictText != null) 'conflict_text': conflictText,
      if (conflictFrom != null) 'conflict_from': conflictFrom,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (fieldHlcs != null) 'field_hlcs': fieldHlcs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? listId,
    Value<String>? kind,
    Value<String>? body,
    Value<bool>? done,
    Value<int?>? doneAt,
    Value<int>? indent,
    Value<String>? sortKey,
    Value<String?>? dueDate,
    Value<int?>? dueMinutes,
    Value<String>? reminders,
    Value<String?>? repeat,
    Value<String?>? conflictText,
    Value<String?>? conflictFrom,
    Value<int?>? deletedAt,
    Value<String>? fieldHlcs,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      done: done ?? this.done,
      doneAt: doneAt ?? this.doneAt,
      indent: indent ?? this.indent,
      sortKey: sortKey ?? this.sortKey,
      dueDate: dueDate ?? this.dueDate,
      dueMinutes: dueMinutes ?? this.dueMinutes,
      reminders: reminders ?? this.reminders,
      repeat: repeat ?? this.repeat,
      conflictText: conflictText ?? this.conflictText,
      conflictFrom: conflictFrom ?? this.conflictFrom,
      deletedAt: deletedAt ?? this.deletedAt,
      fieldHlcs: fieldHlcs ?? this.fieldHlcs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<int>(doneAt.value);
    }
    if (indent.present) {
      map['indent'] = Variable<int>(indent.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (dueMinutes.present) {
      map['due_minutes'] = Variable<int>(dueMinutes.value);
    }
    if (reminders.present) {
      map['reminders'] = Variable<String>(reminders.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<String>(repeat.value);
    }
    if (conflictText.present) {
      map['conflict_text'] = Variable<String>(conflictText.value);
    }
    if (conflictFrom.present) {
      map['conflict_from'] = Variable<String>(conflictFrom.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (fieldHlcs.present) {
      map['field_hlcs'] = Variable<String>(fieldHlcs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('done: $done, ')
          ..write('doneAt: $doneAt, ')
          ..write('indent: $indent, ')
          ..write('sortKey: $sortKey, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueMinutes: $dueMinutes, ')
          ..write('reminders: $reminders, ')
          ..write('repeat: $repeat, ')
          ..write('conflictText: $conflictText, ')
          ..write('conflictFrom: $conflictFrom, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('fieldHlcs: $fieldHlcs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _changeIdMeta = const VerificationMeta(
    'changeId',
  );
  @override
  late final GeneratedColumn<String> changeId = GeneratedColumn<String>(
    'change_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsMeta = const VerificationMeta('fields');
  @override
  late final GeneratedColumn<String> fields = GeneratedColumn<String>(
    'fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    changeId,
    entityType,
    entityId,
    fields,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('change_id')) {
      context.handle(
        _changeIdMeta,
        changeId.isAcceptableOrUnknown(data['change_id']!, _changeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_changeIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('fields')) {
      context.handle(
        _fieldsMeta,
        fields.isAcceptableOrUnknown(data['fields']!, _fieldsMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {changeId};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      changeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      fields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final String changeId;
  final String entityType;
  final String entityId;

  /// JSON `{field: {"v": value, "h": packedHlc}}`.
  final String fields;
  final int createdAt;
  const OutboxRow({
    required this.changeId,
    required this.entityType,
    required this.entityId,
    required this.fields,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['change_id'] = Variable<String>(changeId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['fields'] = Variable<String>(fields);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      changeId: Value(changeId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      fields: Value(fields),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      changeId: serializer.fromJson<String>(json['changeId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      fields: serializer.fromJson<String>(json['fields']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'changeId': serializer.toJson<String>(changeId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'fields': serializer.toJson<String>(fields),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  OutboxRow copyWith({
    String? changeId,
    String? entityType,
    String? entityId,
    String? fields,
    int? createdAt,
  }) => OutboxRow(
    changeId: changeId ?? this.changeId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    fields: fields ?? this.fields,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      changeId: data.changeId.present ? data.changeId.value : this.changeId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      fields: data.fields.present ? data.fields.value : this.fields,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('changeId: $changeId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('fields: $fields, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(changeId, entityType, entityId, fields, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.changeId == this.changeId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.fields == this.fields &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> changeId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> fields;
  final Value<int> createdAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.changeId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.fields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String changeId,
    required String entityType,
    required String entityId,
    required String fields,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : changeId = Value(changeId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       fields = Value(fields),
       createdAt = Value(createdAt);
  static Insertable<OutboxRow> custom({
    Expression<String>? changeId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? fields,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (changeId != null) 'change_id': changeId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (fields != null) 'fields': fields,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? changeId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? fields,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      changeId: changeId ?? this.changeId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      fields: fields ?? this.fields,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (changeId.present) {
      map['change_id'] = Variable<String>(changeId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (fields.present) {
      map['fields'] = Variable<String>(fields.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('changeId: $changeId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('fields: $fields, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KvTable extends Kv with TableInfo<$KvTable, KvRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KvTable createAlias(String alias) {
    return $KvTable(attachedDatabase, alias);
  }
}

class KvRow extends DataClass implements Insertable<KvRow> {
  final String key;
  final String value;
  const KvRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KvCompanion toCompanion(bool nullToAbsent) {
    return KvCompanion(key: Value(key), value: Value(value));
  }

  factory KvRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KvRow copyWith({String? key, String? value}) =>
      KvRow(key: key ?? this.key, value: value ?? this.value);
  KvRow copyWithCompanion(KvCompanion data) {
    return KvRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvRow && other.key == this.key && other.value == this.value);
}

class KvCompanion extends UpdateCompanion<KvRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KvRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KvCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MiniBarsTable extends MiniBars
    with TableInfo<$MiniBarsTable, MiniBarRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MiniBarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wMeta = const VerificationMeta('w');
  @override
  late final GeneratedColumn<double> w = GeneratedColumn<double>(
    'w',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hMeta = const VerificationMeta('h');
  @override
  late final GeneratedColumn<double> h = GeneratedColumn<double>(
    'h',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collapsedMeta = const VerificationMeta(
    'collapsed',
  );
  @override
  late final GeneratedColumn<bool> collapsed = GeneratedColumn<bool>(
    'collapsed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collapsed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [listId, x, y, w, h, collapsed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mini_bars';
  @override
  VerificationContext validateIntegrity(
    Insertable<MiniBarRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('w')) {
      context.handle(_wMeta, w.isAcceptableOrUnknown(data['w']!, _wMeta));
    }
    if (data.containsKey('h')) {
      context.handle(_hMeta, h.isAcceptableOrUnknown(data['h']!, _hMeta));
    }
    if (data.containsKey('collapsed')) {
      context.handle(
        _collapsedMeta,
        collapsed.isAcceptableOrUnknown(data['collapsed']!, _collapsedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {listId};
  @override
  MiniBarRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MiniBarRow(
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      ),
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      ),
      w: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}w'],
      ),
      h: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}h'],
      ),
      collapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collapsed'],
      )!,
    );
  }

  @override
  $MiniBarsTable createAlias(String alias) {
    return $MiniBarsTable(attachedDatabase, alias);
  }
}

class MiniBarRow extends DataClass implements Insertable<MiniBarRow> {
  final String listId;
  final double? x;
  final double? y;
  final double? w;
  final double? h;
  final bool collapsed;
  const MiniBarRow({
    required this.listId,
    this.x,
    this.y,
    this.w,
    this.h,
    required this.collapsed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['list_id'] = Variable<String>(listId);
    if (!nullToAbsent || x != null) {
      map['x'] = Variable<double>(x);
    }
    if (!nullToAbsent || y != null) {
      map['y'] = Variable<double>(y);
    }
    if (!nullToAbsent || w != null) {
      map['w'] = Variable<double>(w);
    }
    if (!nullToAbsent || h != null) {
      map['h'] = Variable<double>(h);
    }
    map['collapsed'] = Variable<bool>(collapsed);
    return map;
  }

  MiniBarsCompanion toCompanion(bool nullToAbsent) {
    return MiniBarsCompanion(
      listId: Value(listId),
      x: x == null && nullToAbsent ? const Value.absent() : Value(x),
      y: y == null && nullToAbsent ? const Value.absent() : Value(y),
      w: w == null && nullToAbsent ? const Value.absent() : Value(w),
      h: h == null && nullToAbsent ? const Value.absent() : Value(h),
      collapsed: Value(collapsed),
    );
  }

  factory MiniBarRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MiniBarRow(
      listId: serializer.fromJson<String>(json['listId']),
      x: serializer.fromJson<double?>(json['x']),
      y: serializer.fromJson<double?>(json['y']),
      w: serializer.fromJson<double?>(json['w']),
      h: serializer.fromJson<double?>(json['h']),
      collapsed: serializer.fromJson<bool>(json['collapsed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'listId': serializer.toJson<String>(listId),
      'x': serializer.toJson<double?>(x),
      'y': serializer.toJson<double?>(y),
      'w': serializer.toJson<double?>(w),
      'h': serializer.toJson<double?>(h),
      'collapsed': serializer.toJson<bool>(collapsed),
    };
  }

  MiniBarRow copyWith({
    String? listId,
    Value<double?> x = const Value.absent(),
    Value<double?> y = const Value.absent(),
    Value<double?> w = const Value.absent(),
    Value<double?> h = const Value.absent(),
    bool? collapsed,
  }) => MiniBarRow(
    listId: listId ?? this.listId,
    x: x.present ? x.value : this.x,
    y: y.present ? y.value : this.y,
    w: w.present ? w.value : this.w,
    h: h.present ? h.value : this.h,
    collapsed: collapsed ?? this.collapsed,
  );
  MiniBarRow copyWithCompanion(MiniBarsCompanion data) {
    return MiniBarRow(
      listId: data.listId.present ? data.listId.value : this.listId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      w: data.w.present ? data.w.value : this.w,
      h: data.h.present ? data.h.value : this.h,
      collapsed: data.collapsed.present ? data.collapsed.value : this.collapsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MiniBarRow(')
          ..write('listId: $listId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('w: $w, ')
          ..write('h: $h, ')
          ..write('collapsed: $collapsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(listId, x, y, w, h, collapsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MiniBarRow &&
          other.listId == this.listId &&
          other.x == this.x &&
          other.y == this.y &&
          other.w == this.w &&
          other.h == this.h &&
          other.collapsed == this.collapsed);
}

class MiniBarsCompanion extends UpdateCompanion<MiniBarRow> {
  final Value<String> listId;
  final Value<double?> x;
  final Value<double?> y;
  final Value<double?> w;
  final Value<double?> h;
  final Value<bool> collapsed;
  final Value<int> rowid;
  const MiniBarsCompanion({
    this.listId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.w = const Value.absent(),
    this.h = const Value.absent(),
    this.collapsed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MiniBarsCompanion.insert({
    required String listId,
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.w = const Value.absent(),
    this.h = const Value.absent(),
    this.collapsed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : listId = Value(listId);
  static Insertable<MiniBarRow> custom({
    Expression<String>? listId,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? w,
    Expression<double>? h,
    Expression<bool>? collapsed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (listId != null) 'list_id': listId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (w != null) 'w': w,
      if (h != null) 'h': h,
      if (collapsed != null) 'collapsed': collapsed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MiniBarsCompanion copyWith({
    Value<String>? listId,
    Value<double?>? x,
    Value<double?>? y,
    Value<double?>? w,
    Value<double?>? h,
    Value<bool>? collapsed,
    Value<int>? rowid,
  }) {
    return MiniBarsCompanion(
      listId: listId ?? this.listId,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      collapsed: collapsed ?? this.collapsed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (w.present) {
      map['w'] = Variable<double>(w.value);
    }
    if (h.present) {
      map['h'] = Variable<double>(h.value);
    }
    if (collapsed.present) {
      map['collapsed'] = Variable<bool>(collapsed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MiniBarsCompanion(')
          ..write('listId: $listId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('w: $w, ')
          ..write('h: $h, ')
          ..write('collapsed: $collapsed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$WeaveDatabase extends GeneratedDatabase {
  _$WeaveDatabase(QueryExecutor e) : super(e);
  $WeaveDatabaseManager get managers => $WeaveDatabaseManager(this);
  late final $ListsTable lists = $ListsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $KvTable kv = $KvTable(this);
  late final $MiniBarsTable miniBars = $MiniBarsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lists,
    items,
    outbox,
    kv,
    miniBars,
  ];
}

typedef $$ListsTableCreateCompanionBuilder =
    ListsCompanion Function({
      required String id,
      Value<String> name,
      Value<String> color,
      Value<String> sortKey,
      Value<bool> pinnedToTop,
      Value<bool> hideDone,
      Value<String?> dueDate,
      Value<int?> dueMinutes,
      Value<int?> archivedAt,
      Value<int?> deletedAt,
      Value<String> fieldHlcs,
      Value<int> rowid,
    });
typedef $$ListsTableUpdateCompanionBuilder =
    ListsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> color,
      Value<String> sortKey,
      Value<bool> pinnedToTop,
      Value<bool> hideDone,
      Value<String?> dueDate,
      Value<int?> dueMinutes,
      Value<int?> archivedAt,
      Value<int?> deletedAt,
      Value<String> fieldHlcs,
      Value<int> rowid,
    });

class $$ListsTableFilterComposer
    extends Composer<_$WeaveDatabase, $ListsTable> {
  $$ListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinnedToTop => $composableBuilder(
    column: $table.pinnedToTop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hideDone => $composableBuilder(
    column: $table.hideDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueMinutes => $composableBuilder(
    column: $table.dueMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldHlcs => $composableBuilder(
    column: $table.fieldHlcs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ListsTableOrderingComposer
    extends Composer<_$WeaveDatabase, $ListsTable> {
  $$ListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinnedToTop => $composableBuilder(
    column: $table.pinnedToTop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hideDone => $composableBuilder(
    column: $table.hideDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueMinutes => $composableBuilder(
    column: $table.dueMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldHlcs => $composableBuilder(
    column: $table.fieldHlcs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListsTableAnnotationComposer
    extends Composer<_$WeaveDatabase, $ListsTable> {
  $$ListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<bool> get pinnedToTop => $composableBuilder(
    column: $table.pinnedToTop,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hideDone =>
      $composableBuilder(column: $table.hideDone, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get dueMinutes => $composableBuilder(
    column: $table.dueMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get fieldHlcs =>
      $composableBuilder(column: $table.fieldHlcs, builder: (column) => column);
}

class $$ListsTableTableManager
    extends
        RootTableManager<
          _$WeaveDatabase,
          $ListsTable,
          ListRow,
          $$ListsTableFilterComposer,
          $$ListsTableOrderingComposer,
          $$ListsTableAnnotationComposer,
          $$ListsTableCreateCompanionBuilder,
          $$ListsTableUpdateCompanionBuilder,
          (ListRow, BaseReferences<_$WeaveDatabase, $ListsTable, ListRow>),
          ListRow,
          PrefetchHooks Function()
        > {
  $$ListsTableTableManager(_$WeaveDatabase db, $ListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<bool> pinnedToTop = const Value.absent(),
                Value<bool> hideDone = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<int?> dueMinutes = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> fieldHlcs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListsCompanion(
                id: id,
                name: name,
                color: color,
                sortKey: sortKey,
                pinnedToTop: pinnedToTop,
                hideDone: hideDone,
                dueDate: dueDate,
                dueMinutes: dueMinutes,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                fieldHlcs: fieldHlcs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<bool> pinnedToTop = const Value.absent(),
                Value<bool> hideDone = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<int?> dueMinutes = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> fieldHlcs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListsCompanion.insert(
                id: id,
                name: name,
                color: color,
                sortKey: sortKey,
                pinnedToTop: pinnedToTop,
                hideDone: hideDone,
                dueDate: dueDate,
                dueMinutes: dueMinutes,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                fieldHlcs: fieldHlcs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ListsTableProcessedTableManager =
    ProcessedTableManager<
      _$WeaveDatabase,
      $ListsTable,
      ListRow,
      $$ListsTableFilterComposer,
      $$ListsTableOrderingComposer,
      $$ListsTableAnnotationComposer,
      $$ListsTableCreateCompanionBuilder,
      $$ListsTableUpdateCompanionBuilder,
      (ListRow, BaseReferences<_$WeaveDatabase, $ListsTable, ListRow>),
      ListRow,
      PrefetchHooks Function()
    >;
typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      Value<String> listId,
      Value<String> kind,
      Value<String> body,
      Value<bool> done,
      Value<int?> doneAt,
      Value<int> indent,
      Value<String> sortKey,
      Value<String?> dueDate,
      Value<int?> dueMinutes,
      Value<String> reminders,
      Value<String?> repeat,
      Value<String?> conflictText,
      Value<String?> conflictFrom,
      Value<int?> deletedAt,
      Value<String> fieldHlcs,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<String> listId,
      Value<String> kind,
      Value<String> body,
      Value<bool> done,
      Value<int?> doneAt,
      Value<int> indent,
      Value<String> sortKey,
      Value<String?> dueDate,
      Value<int?> dueMinutes,
      Value<String> reminders,
      Value<String?> repeat,
      Value<String?> conflictText,
      Value<String?> conflictFrom,
      Value<int?> deletedAt,
      Value<String> fieldHlcs,
      Value<int> rowid,
    });

class $$ItemsTableFilterComposer
    extends Composer<_$WeaveDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get indent => $composableBuilder(
    column: $table.indent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueMinutes => $composableBuilder(
    column: $table.dueMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictText => $composableBuilder(
    column: $table.conflictText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictFrom => $composableBuilder(
    column: $table.conflictFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldHlcs => $composableBuilder(
    column: $table.fieldHlcs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemsTableOrderingComposer
    extends Composer<_$WeaveDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get indent => $composableBuilder(
    column: $table.indent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueMinutes => $composableBuilder(
    column: $table.dueMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictText => $composableBuilder(
    column: $table.conflictText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictFrom => $composableBuilder(
    column: $table.conflictFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldHlcs => $composableBuilder(
    column: $table.fieldHlcs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$WeaveDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  GeneratedColumn<int> get indent =>
      $composableBuilder(column: $table.indent, builder: (column) => column);

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get dueMinutes => $composableBuilder(
    column: $table.dueMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminders =>
      $composableBuilder(column: $table.reminders, builder: (column) => column);

  GeneratedColumn<String> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);

  GeneratedColumn<String> get conflictText => $composableBuilder(
    column: $table.conflictText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictFrom => $composableBuilder(
    column: $table.conflictFrom,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get fieldHlcs =>
      $composableBuilder(column: $table.fieldHlcs, builder: (column) => column);
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$WeaveDatabase,
          $ItemsTable,
          ItemRow,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (ItemRow, BaseReferences<_$WeaveDatabase, $ItemsTable, ItemRow>),
          ItemRow,
          PrefetchHooks Function()
        > {
  $$ItemsTableTableManager(_$WeaveDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int?> doneAt = const Value.absent(),
                Value<int> indent = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<int?> dueMinutes = const Value.absent(),
                Value<String> reminders = const Value.absent(),
                Value<String?> repeat = const Value.absent(),
                Value<String?> conflictText = const Value.absent(),
                Value<String?> conflictFrom = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> fieldHlcs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                listId: listId,
                kind: kind,
                body: body,
                done: done,
                doneAt: doneAt,
                indent: indent,
                sortKey: sortKey,
                dueDate: dueDate,
                dueMinutes: dueMinutes,
                reminders: reminders,
                repeat: repeat,
                conflictText: conflictText,
                conflictFrom: conflictFrom,
                deletedAt: deletedAt,
                fieldHlcs: fieldHlcs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> listId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int?> doneAt = const Value.absent(),
                Value<int> indent = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<int?> dueMinutes = const Value.absent(),
                Value<String> reminders = const Value.absent(),
                Value<String?> repeat = const Value.absent(),
                Value<String?> conflictText = const Value.absent(),
                Value<String?> conflictFrom = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> fieldHlcs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                listId: listId,
                kind: kind,
                body: body,
                done: done,
                doneAt: doneAt,
                indent: indent,
                sortKey: sortKey,
                dueDate: dueDate,
                dueMinutes: dueMinutes,
                reminders: reminders,
                repeat: repeat,
                conflictText: conflictText,
                conflictFrom: conflictFrom,
                deletedAt: deletedAt,
                fieldHlcs: fieldHlcs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$WeaveDatabase,
      $ItemsTable,
      ItemRow,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (ItemRow, BaseReferences<_$WeaveDatabase, $ItemsTable, ItemRow>),
      ItemRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String changeId,
      required String entityType,
      required String entityId,
      required String fields,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> changeId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> fields,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$WeaveDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$WeaveDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$WeaveDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get changeId =>
      $composableBuilder(column: $table.changeId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get fields =>
      $composableBuilder(column: $table.fields, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$WeaveDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$WeaveDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$WeaveDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> changeId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> fields = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                changeId: changeId,
                entityType: entityType,
                entityId: entityId,
                fields: fields,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String changeId,
                required String entityType,
                required String entityId,
                required String fields,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                changeId: changeId,
                entityType: entityType,
                entityId: entityId,
                fields: fields,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$WeaveDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$WeaveDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$KvTableCreateCompanionBuilder =
    KvCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$KvTableUpdateCompanionBuilder =
    KvCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$KvTableFilterComposer extends Composer<_$WeaveDatabase, $KvTable> {
  $$KvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvTableOrderingComposer extends Composer<_$WeaveDatabase, $KvTable> {
  $$KvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvTableAnnotationComposer extends Composer<_$WeaveDatabase, $KvTable> {
  $$KvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KvTableTableManager
    extends
        RootTableManager<
          _$WeaveDatabase,
          $KvTable,
          KvRow,
          $$KvTableFilterComposer,
          $$KvTableOrderingComposer,
          $$KvTableAnnotationComposer,
          $$KvTableCreateCompanionBuilder,
          $$KvTableUpdateCompanionBuilder,
          (KvRow, BaseReferences<_$WeaveDatabase, $KvTable, KvRow>),
          KvRow,
          PrefetchHooks Function()
        > {
  $$KvTableTableManager(_$WeaveDatabase db, $KvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => KvCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvTableProcessedTableManager =
    ProcessedTableManager<
      _$WeaveDatabase,
      $KvTable,
      KvRow,
      $$KvTableFilterComposer,
      $$KvTableOrderingComposer,
      $$KvTableAnnotationComposer,
      $$KvTableCreateCompanionBuilder,
      $$KvTableUpdateCompanionBuilder,
      (KvRow, BaseReferences<_$WeaveDatabase, $KvTable, KvRow>),
      KvRow,
      PrefetchHooks Function()
    >;
typedef $$MiniBarsTableCreateCompanionBuilder =
    MiniBarsCompanion Function({
      required String listId,
      Value<double?> x,
      Value<double?> y,
      Value<double?> w,
      Value<double?> h,
      Value<bool> collapsed,
      Value<int> rowid,
    });
typedef $$MiniBarsTableUpdateCompanionBuilder =
    MiniBarsCompanion Function({
      Value<String> listId,
      Value<double?> x,
      Value<double?> y,
      Value<double?> w,
      Value<double?> h,
      Value<bool> collapsed,
      Value<int> rowid,
    });

class $$MiniBarsTableFilterComposer
    extends Composer<_$WeaveDatabase, $MiniBarsTable> {
  $$MiniBarsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get w => $composableBuilder(
    column: $table.w,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get h => $composableBuilder(
    column: $table.h,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MiniBarsTableOrderingComposer
    extends Composer<_$WeaveDatabase, $MiniBarsTable> {
  $$MiniBarsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get w => $composableBuilder(
    column: $table.w,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get h => $composableBuilder(
    column: $table.h,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MiniBarsTableAnnotationComposer
    extends Composer<_$WeaveDatabase, $MiniBarsTable> {
  $$MiniBarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get w =>
      $composableBuilder(column: $table.w, builder: (column) => column);

  GeneratedColumn<double> get h =>
      $composableBuilder(column: $table.h, builder: (column) => column);

  GeneratedColumn<bool> get collapsed =>
      $composableBuilder(column: $table.collapsed, builder: (column) => column);
}

class $$MiniBarsTableTableManager
    extends
        RootTableManager<
          _$WeaveDatabase,
          $MiniBarsTable,
          MiniBarRow,
          $$MiniBarsTableFilterComposer,
          $$MiniBarsTableOrderingComposer,
          $$MiniBarsTableAnnotationComposer,
          $$MiniBarsTableCreateCompanionBuilder,
          $$MiniBarsTableUpdateCompanionBuilder,
          (
            MiniBarRow,
            BaseReferences<_$WeaveDatabase, $MiniBarsTable, MiniBarRow>,
          ),
          MiniBarRow,
          PrefetchHooks Function()
        > {
  $$MiniBarsTableTableManager(_$WeaveDatabase db, $MiniBarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MiniBarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MiniBarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MiniBarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> listId = const Value.absent(),
                Value<double?> x = const Value.absent(),
                Value<double?> y = const Value.absent(),
                Value<double?> w = const Value.absent(),
                Value<double?> h = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MiniBarsCompanion(
                listId: listId,
                x: x,
                y: y,
                w: w,
                h: h,
                collapsed: collapsed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String listId,
                Value<double?> x = const Value.absent(),
                Value<double?> y = const Value.absent(),
                Value<double?> w = const Value.absent(),
                Value<double?> h = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MiniBarsCompanion.insert(
                listId: listId,
                x: x,
                y: y,
                w: w,
                h: h,
                collapsed: collapsed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MiniBarsTableProcessedTableManager =
    ProcessedTableManager<
      _$WeaveDatabase,
      $MiniBarsTable,
      MiniBarRow,
      $$MiniBarsTableFilterComposer,
      $$MiniBarsTableOrderingComposer,
      $$MiniBarsTableAnnotationComposer,
      $$MiniBarsTableCreateCompanionBuilder,
      $$MiniBarsTableUpdateCompanionBuilder,
      (MiniBarRow, BaseReferences<_$WeaveDatabase, $MiniBarsTable, MiniBarRow>),
      MiniBarRow,
      PrefetchHooks Function()
    >;

class $WeaveDatabaseManager {
  final _$WeaveDatabase _db;
  $WeaveDatabaseManager(this._db);
  $$ListsTableTableManager get lists =>
      $$ListsTableTableManager(_db, _db.lists);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$KvTableTableManager get kv => $$KvTableTableManager(_db, _db.kv);
  $$MiniBarsTableTableManager get miniBars =>
      $$MiniBarsTableTableManager(_db, _db.miniBars);
}
