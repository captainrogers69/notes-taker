import 'dart:convert';

import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/field_value.dart';
import 'package:weave/core/sync/payload_cipher.dart';

/// Not encrypted: JSON, then base64. Stand-in until the E2EE phase.
class PassthroughPayloadCipher implements PayloadCipher {
  const PassthroughPayloadCipher();

  static bool _isSupported(Object? v) =>
      v == null ||
      v is bool ||
      v is int ||
      v is String ||
      (v is double && v.isFinite);

  @override
  Future<String> seal(
    EntityType t,
    String entityId,
    Map<String, FieldValue> fields,
  ) async {
    for (final e in fields.entries) {
      if (!_isSupported(e.value.v)) {
        throw ArgumentError('unsupported value for field "${e.key}"');
      }
    }
    final json = {
      for (final e in fields.entries)
        e.key: {'v': e.value.v, 'h': e.value.h, 'b': ?e.value.b},
    };
    return base64.encode(utf8.encode(jsonEncode(json)));
  }

  @override
  Future<Map<String, FieldValue>> open(
    EntityType t,
    String entityId,
    String payload,
  ) async {
    final Object? decoded = jsonDecode(utf8.decode(base64.decode(payload)));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('payload is not an object');
    }
    final out = <String, FieldValue>{};
    for (final e in decoded.entries) {
      final entry = e.value;
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('field entry is not an object');
      }
      final h = entry['h'];
      final v = entry['v'];
      if (h is! String) {
        throw const FormatException('field entry missing hlc');
      }
      if (v != null &&
          v is! bool &&
          v is! int &&
          v is! double &&
          v is! String) {
        throw const FormatException('unsupported field value');
      }
      // `b` (text base HLC) is optional; a wrong-typed one counts as absent.
      final b = entry['b'];
      out[e.key] = FieldValue(v, h, b: b is String ? b : null);
    }
    return out;
  }
}
