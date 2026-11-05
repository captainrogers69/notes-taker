import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Returns a new UUID v7 (time-ordered) id.
String newId() => _uuid.v7();
