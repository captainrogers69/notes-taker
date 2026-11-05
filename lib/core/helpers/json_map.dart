import 'dart:convert';

/// Decodes a JSON object; null, corrupt JSON or a non-object → empty map.
Map<String, Object?> decodeJsonMap(String? json) {
  if (json == null) return {};
  try {
    final decoded = jsonDecode(json);
    return decoded is Map ? Map<String, Object?>.from(decoded) : {};
  } on FormatException {
    return {};
  }
}
