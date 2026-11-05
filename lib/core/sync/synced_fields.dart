/// Value type of a synced (or local-only) column.
enum FieldType { text, int, bool }

/// Where a field lives and what it holds.
typedef FieldSpec = ({String column, FieldType type, bool nullable});

/// Synced list fields: field name (the Dart column name) -> spec.
/// Nullability mirrors `tables.dart`; defaults for omitted columns live there.
const listFields = <String, FieldSpec>{
  'name': (column: 'name', type: FieldType.text, nullable: false),
  'color': (column: 'color', type: FieldType.text, nullable: false),
  'sortKey': (column: 'sort_key', type: FieldType.text, nullable: false),
  'pinnedToTop': (
    column: 'pinned_to_top',
    type: FieldType.bool,
    nullable: false,
  ),
  'hideDone': (column: 'hide_done', type: FieldType.bool, nullable: false),
  'dueDate': (column: 'due_date', type: FieldType.text, nullable: true),
  'dueMinutes': (column: 'due_minutes', type: FieldType.int, nullable: true),
  'archivedAt': (column: 'archived_at', type: FieldType.int, nullable: true),
  'deletedAt': (column: 'deleted_at', type: FieldType.int, nullable: true),
};

/// Synced item fields.
const itemFields = <String, FieldSpec>{
  'listId': (column: 'list_id', type: FieldType.text, nullable: false),
  'kind': (column: 'kind', type: FieldType.text, nullable: false),
  'text': (column: 'text', type: FieldType.text, nullable: false),
  'done': (column: 'done', type: FieldType.bool, nullable: false),
  'doneAt': (column: 'done_at', type: FieldType.int, nullable: true),
  'indent': (column: 'indent', type: FieldType.int, nullable: false),
  'sortKey': (column: 'sort_key', type: FieldType.text, nullable: false),
  'dueDate': (column: 'due_date', type: FieldType.text, nullable: true),
  'dueMinutes': (column: 'due_minutes', type: FieldType.int, nullable: true),
  'reminders': (column: 'reminders', type: FieldType.text, nullable: false),
  'repeat': (column: 'repeat', type: FieldType.text, nullable: true),
  'deletedAt': (column: 'deleted_at', type: FieldType.int, nullable: true),
};

/// Never-synced item fields (no HLC, no outbox).
const itemLocalFields = <String, FieldSpec>{
  'conflictText': (
    column: 'conflict_text',
    type: FieldType.text,
    nullable: true,
  ),
  'conflictFrom': (
    column: 'conflict_from',
    type: FieldType.text,
    nullable: true,
  ),
};

/// Key in an item's `fieldHlcs` JSON holding the HLC of the text version the
/// current local text was made on top of. Local only: never synced, never a
/// field.
const textBaseKey = 'text.b';
