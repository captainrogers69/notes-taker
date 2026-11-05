import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/field_value.dart';

/// Seals field maps into opaque payload strings and back.
abstract class PayloadCipher {
  Future<String> seal(
    EntityType t,
    String entityId,
    Map<String, FieldValue> fields,
  );

  /// Throws [FormatException] on malformed input.
  Future<Map<String, FieldValue>> open(
    EntityType t,
    String entityId,
    String payload,
  );
}
