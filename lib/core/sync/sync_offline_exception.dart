/// Thrown by a transport when the network is unreachable.
class SyncOfflineException implements Exception {
  const SyncOfflineException();

  @override
  String toString() => 'SyncOfflineException';
}
