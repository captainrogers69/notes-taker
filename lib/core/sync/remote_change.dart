import 'package:equatable/equatable.dart';
import 'package:weave/core/sync/entity_type.dart';

/// One change row as sent to / received from the server.
class RemoteChange extends Equatable {
  const RemoteChange({
    required this.changeId,
    required this.type,
    required this.entityId,
    required this.deviceId,
    required this.hlc,
    required this.payload,
  });

  final String changeId;
  final EntityType type;
  final String entityId;
  final String deviceId;
  final String hlc;
  final String payload;

  @override
  List<Object?> get props => [changeId, type, entityId, deviceId, hlc, payload];
}
