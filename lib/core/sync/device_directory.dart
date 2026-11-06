import 'dart:async';
import 'dart:developer' as developer;

import 'device_names.dart';
import 'sync_transport.dart';

/// Keeps the local device-name cache ([DeviceNames]) filled from the
/// server's devices table, cheaply:
/// - [start] (once per sign-in / app start) registers this device with
///   `touchDevice` and caches every device's name;
/// - [ensureKnown] (the engine calls it per pulled page) refreshes only when
///   a page holds a device id not seen in the table yet, at most once per
///   [minInterval]; it waits for a refresh already in flight.
///
/// Network work happens here, never inside the merge transaction.
class DeviceDirectory {
  DeviceDirectory({
    required this._transport,
    required this._names,
    required this.platform,
    this.minInterval = const Duration(seconds: 30),
    DateTime Function()? now,
    void Function(String message)? log,
  }) : _now = now ?? DateTime.now,
       _log = log ?? ((m) => developer.log(m, name: 'Sync'));

  final SyncTransport _transport;
  final DeviceNames _names;
  final String platform;
  final Duration minInterval;
  final DateTime Function() _now;
  final void Function(String) _log;

  final _known = <String>{};
  DateTime? _lastAttempt;
  Future<void>? _inFlight;
  bool _closed = false;

  /// Stops writing names: a request still in flight (e.g. [start] during
  /// sign-out) must not write the old account's names after the wipe.
  /// `unregisterSync` calls it.
  void dispose() => _closed = true;

  /// Registers this device and caches all names. Never throws.
  Future<void> start() async {
    if (_closed) return;
    try {
      await _transport.touchDevice(_names.selfId, _names.selfName, platform);
    } on Object catch (e) {
      _log('touch device failed: ${e.runtimeType}');
    }
    try {
      await refresh();
    } on Object catch (e) {
      _log('device list failed: ${e.runtimeType}');
    }
  }

  /// Refreshes the cache when [deviceIds] holds an id not seen yet and the
  /// last attempt is older than [minInterval]. Throws transport errors.
  Future<void> ensureKnown(Set<String> deviceIds) async {
    if (_closed || _known.containsAll(deviceIds)) return;
    // A refresh already running (e.g. from [start]) may bring these names.
    final running = _inFlight;
    if (running != null) return running;
    final last = _lastAttempt;
    if (last != null && _now().difference(last) < minInterval) return;
    await refresh();
  }

  /// Reads the devices table into the cache. Concurrent calls share one
  /// request.
  Future<void> refresh() => _inFlight ??= _refresh().whenComplete(() {
    _inFlight = null;
  });

  Future<void> _refresh() async {
    _lastAttempt = _now();
    final devices = await _transport.devices();
    if (_closed) return;
    await _names.upsert({for (final d in devices) d.id: d.name});
    _known.addAll(devices.map((d) => d.id));
  }
}
