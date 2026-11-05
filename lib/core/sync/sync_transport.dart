import 'package:weave/core/sync/device_info.dart';
import 'package:weave/core/sync/pulled_change.dart';
import 'package:weave/core/sync/remote_change.dart';

/// Moves change rows between this device and the server.
abstract class SyncTransport {
  /// Idempotent on `changeId`.
  Future<void> push(List<RemoteChange> changes);

  /// Rows with seq > [afterSeq], ordered by seq.
  Future<List<PulledChange>> pull({required int afterSeq, int limit = 500});

  /// Emits when another device inserts.
  Stream<void> hints();

  Future<void> touchDevice(String id, String name, String platform);

  Future<List<DeviceInfo>> devices();
}
